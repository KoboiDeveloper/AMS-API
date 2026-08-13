/**
 * POS-driven EDC orchestration (kasir trigger start / status / cancel).
 * Uses vendored bank clients — no Electron, no NEW EDC project at runtime.
 */
const db = require("./db-pos");
const bca = require("./vendored/bca");
const mandiri = require("./vendored/mandiri");
const bni = require("./vendored/bni");
const bri = require("./vendored/bri");

function isQrisType(tipeBayar) {
  return /QRIS/i.test(String(tipeBayar || ""));
}

function normalizeBank(bankKey) {
  return db.normalizeBankKey(bankKey);
}

async function loadBankMid(bankKey) {
  const master = await db.loadMidMaster({ force: true });
  const key = normalizeBank(bankKey);
  const banks = master.banks || master;
  // loadMidMaster returns { storeId, banks: { BCA: {mid,tid,saleCode,qrisCode}, ... } }
  const info = master.banks?.[key] || banks?.[key];
  if (!info) {
    throw new Error(`BANK ${key} tidak ada di MID_MASTER untuk STORE ini`);
  }
  return { storeId: master.storeId, midInfo: info, bankKey: key };
}

/**
 * Start payment: insert LOG NEW + push to EDC (no long wait).
 */
async function startPayment({ bankKey, tipeBayar, amount, storeId }) {
  const key = normalizeBank(bankKey);
  const qris = isQrisType(tipeBayar);
  const nominal = Number(amount);
  if (!nominal || nominal <= 0) throw new Error(`Nominal tidak valid: ${amount}`);

  const { storeId: midStore, midInfo } = await loadBankMid(key);
  const store = String(storeId || midStore || process.env.EDC_STORE_ID || "").trim();

  const row = await db.insertNewLog({
    storeId: store,
    bank: key,
    tipeBayar: String(tipeBayar || (qris ? "QRIS" : "DEBIT")),
    amount: nominal,
  });

  const payCode = qris ? midInfo.qrisCode : midInfo.saleCode;

  if (key === "BCA") {
    const sig = await bca.testSignature();
    if (!sig.ok) {
      throw new Error(sig.message || "BCA signature gagal");
    }
    const payFn = qris ? bca.requestQris : bca.requestPurchase;
    const payment = await payFn({
      amount: nominal,
      merchantId: midInfo.mid,
      terminalId: midInfo.tid,
      transType: payCode,
    });
    const ref = String(payment.partnerReferenceNo || "").trim();
    if (!ref) throw new Error("Payment OK tapi partnerReferenceNo kosong");
    return {
      ok: true,
      pending: true,
      status: "pending",
      bankKey: key,
      tipeBayar: row.tipeBayar,
      amount: nominal,
      storeId: row.store,
      partnerReferenceNo: ref,
      ecrTransId: ref,
      message: "Permintaan terkirim ke EDC BCA. Selesaikan di mesin, lalu Cek Transaksi.",
    };
  }

  if (key === "MDR" || key === "BNI") {
    const client = key === "BNI" ? bni : mandiri;
    if (!client.hasJwt()) {
      const jwt = await client.getJwt();
      if (!jwt.ok) throw new Error(jwt.message || "Get JWT gagal");
    }
    const push = await client.ecrPush({
      amount: nominal,
      merchantID: midInfo.mid,
      terminalID: midInfo.tid,
      transCategory: payCode,
    });
    const savedId = String(push.data?.merchantEcrTransID || "").trim();
    if (!savedId) throw new Error("ECR Push OK tapi merchantEcrTransID kosong");
    if (client.rememberPush) client.rememberPush(push.data);
    await db.saveEcrTransId(row, savedId);
    return {
      ok: true,
      pending: true,
      status: "pending",
      bankKey: key,
      tipeBayar: row.tipeBayar,
      amount: nominal,
      storeId: row.store,
      ecrTransId: savedId,
      message: `Push ${key} OK. Selesaikan di EDC, lalu Cek Transaksi.`,
    };
  }

  if (key === "BRI") {
    const existing = await db.readEcrTransId(row);
    let trxId = String(existing.ecrId || "").trim();
    if (!trxId) {
      const payFn = qris ? bri.requestQris : bri.requestSale;
      const pushed = await payFn({
        amount: nominal,
        merchantId: midInfo.mid,
        terminalId: midInfo.tid,
      });
      trxId = String(pushed.trx_id || pushed.trxId || pushed.data?.trx_id || "").trim();
      if (!trxId) throw new Error("BRI Sale OK tapi trx_id kosong");
      await db.saveEcrTransId(row, trxId);
    }
    return {
      ok: true,
      pending: true,
      status: "pending",
      bankKey: key,
      tipeBayar: row.tipeBayar,
      amount: nominal,
      storeId: row.store,
      ecrTransId: trxId,
      message: "Permintaan BRI terkirim. Selesaikan di EDC, lalu Cek Transaksi.",
    };
  }

  throw new Error(`Bank tidak didukung: ${key}`);
}

/**
 * Single inquiry check (kasir presses Cek Transaksi).
 * Kasir-driven: HANYA write SUCCESS ke DB. Jangan auto-FAILED —
 * early inquiry sering hollow/RC non-final; biarkan Cek ulang atau Cancel.
 */
async function checkPaymentStatus({
  bankKey,
  tipeBayar,
  amount,
  ecrTransId,
  partnerReferenceNo,
  storeId,
}) {
  const key = normalizeBank(bankKey);
  const qris = isQrisType(tipeBayar);
  const nominal = Number(amount);
  const { midInfo, storeId: midStore } = await loadBankMid(key);
  const store = String(storeId || midStore || "").trim();
  const payCode = qris ? midInfo.qrisCode : midInfo.saleCode;
  const ref = String(partnerReferenceNo || ecrTransId || "").trim();

  const row = {
    store,
    bank: key === "MDR" ? "MDR" : key,
    tipeBayar: String(tipeBayar || ""),
    nominal,
    merchantEcrTransId: ref,
  };

  if (ref) {
    const pos = await db.readStatusByEcrTransId(ref).catch(() => null);
    if (pos?.cancelled) {
      return { ok: false, status: "cancelled", message: "TRANS sudah CANCEL di DB", ecrTransId: ref };
    }
    if (pos?.statusTrans === "SUCCESS") {
      return { ok: true, status: "success", message: "SUCCESS (DB)", ecrTransId: ref };
    }
    // FAILED di DB dari sesi lama: tetap boleh inquiry ulang (jangan kunci UI)
  }

  if (key === "BCA") {
    if (!ref) throw new Error("partnerReferenceNo / ecrTransId wajib untuk inquiry BCA");
    const inquiry = await bca.inquiryStatus({
      originalPartnerReferenceNo: ref,
      merchantId: midInfo.mid,
      terminalId: midInfo.tid,
      transType: "42",
    });
    const payload = inquiry && typeof inquiry === "object" ? { ...inquiry } : inquiry;
    if (payload && payload._exchange) delete payload._exchange;
    const bizOk =
      typeof bca.isInquiryBusinessSuccess === "function"
        ? bca.isInquiryBusinessSuccess(payload)
        : Boolean(inquiry?.ok || inquiry?.success);
    if (bizOk) {
      await db.updateLogStatus(row, "SUCCESS");
      return { ok: true, status: "success", message: "BCA inquiry SUCCESS", ecrTransId: ref, raw: inquiry };
    }
    return {
      ok: false,
      status: "pending",
      message:
        inquiry?.responseMessage ||
        inquiry?.message ||
        "BCA belum settle — selesaikan di EDC lalu Cek Transaksi lagi",
      ecrTransId: ref,
      raw: inquiry,
    };
  }

  if (key === "MDR" || key === "BNI") {
    const client = key === "BNI" ? bni : mandiri;
    if (!ref) throw new Error("ecrTransId wajib untuk inquiry Yokke");
    if (!client.hasJwt()) {
      const jwt = await client.getJwt();
      if (!jwt.ok) throw new Error(jwt.message || "Get JWT gagal");
    }
    const inquiry = await client.inquiryResultEcr({
      merchantID: midInfo.mid,
      terminalID: midInfo.tid,
      transactionAmount: client.formatAmount12(nominal),
      merchantEcrTransID: ref,
      transCategory: payCode,
      amount: nominal,
    });

    if (client.isSettledPayment(inquiry.data)) {
      await db.updateLogStatus({ ...row, merchantEcrTransID: ref }, "SUCCESS");
      return { ok: true, status: "success", message: `${key} settled SUCCESS`, ecrTransId: ref, raw: inquiry };
    }

    const rc = String(inquiry.data?.responseCode || inquiry.data?.RC || "").trim().toUpperCase();
    let hint = `${key} belum settle`;
    if (client.isAgResponse?.(inquiry.data) || rc === "AG") {
      hint = `${key} AG — masih proses di EDC`;
    } else if (client.isHollow00?.(inquiry.data, rc)) {
      hint = `${key} hollow 00 — belum settle, Cek lagi nanti atau Cancel`;
    } else if (rc) {
      hint = `${key} RC ${rc} — belum final, Cek lagi atau Cancel`;
    }

    return {
      ok: false,
      status: "pending",
      message: hint,
      ecrTransId: ref,
      raw: inquiry,
    };
  }

  if (key === "BRI") {
    if (!ref) throw new Error("trx_id wajib untuk status BRI");
    const st = await bri.checkTrx({ trxId: ref });
    const classified =
      typeof bri.classifyStatus === "function" ? bri.classifyStatus(st) : st?.status;
    if (classified === "success" || classified === "paid") {
      await db.updateLogStatus({ ...row, merchantEcrTransID: ref }, "SUCCESS");
      return { ok: true, status: "success", message: "BRI SUCCESS", ecrTransId: ref, raw: st };
    }
    // Jangan auto-FAILED: kasir yang putuskan lewat Cancel / Cek ulang
    return {
      ok: false,
      status: "pending",
      message:
        classified === "failed" || classified === "fail"
          ? "BRI belum / tidak settle — Cek lagi setelah di EDC, atau Cancel"
          : "BRI masih pending — selesaikan di EDC lalu Cek Transaksi",
      ecrTransId: ref,
      raw: st,
    };
  }

  throw new Error(`Bank tidak didukung: ${key}`);
}

async function cancelPayment(opts) {
  return db.cancelLog(opts);
}

module.exports = {
  startPayment,
  checkPaymentStatus,
  cancelPayment,
  isQrisType,
  normalizeBank,
};
