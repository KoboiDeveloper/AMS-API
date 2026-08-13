/**
 * POS-driven EDC helpers on top of vendored db.js
 * INSERT NEW log + CANCEL status (POS cancel pattern)
 */
const sql = require("mssql");
const db = require("./vendored/db");

async function insertNewLog({ storeId, bank, tipeBayar, amount }) {
  const master = await db.loadMidMaster();
  const store = String(storeId || master.storeId || "").trim();
  if (!store) throw new Error("STORE kosong — set EDC_STORE_ID atau isi MID_MASTER");

  const bankKey = db.normalizeBankKey(bank);
  const aliases = bank === "MDR" || bankKey === "MDR"
    ? ["MDR", "MANDIRI"]
    : [String(bank).toUpperCase()];
  const bankLabel = aliases[0];

  const p = await db.getPool();
  const tipe = String(tipeBayar || "DEBIT").trim();
  const nominal = Number(amount);

  // Reuse existing NEW row with same key if present
  const existing = await p
    .request()
    .input("store", sql.NVarChar, store)
    .input("bank", sql.NVarChar, bankLabel)
    .input("tipe", sql.NVarChar, tipe)
    .input("nominal", sql.Float, nominal)
    .query(`
      SELECT TOP 1 STORE, BANK, TIPE_BAYAR, NOMINAL, STATUS_TRANS
      FROM ${db.tableLog()}
      WHERE STORE = @store
        AND UPPER(LTRIM(RTRIM(BANK))) = UPPER(@bank)
        AND UPPER(LTRIM(RTRIM(TIPE_BAYAR))) = UPPER(@tipe)
        AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
    `);

  if (existing.recordset?.[0]) {
    const r = existing.recordset[0];
    return {
      store: r.STORE,
      bank: r.BANK,
      tipeBayar: r.TIPE_BAYAR,
      nominal: Number(r.NOMINAL),
      reused: true,
    };
  }

  await p
    .request()
    .input("store", sql.NVarChar, store)
    .input("bank", sql.NVarChar, bankLabel)
    .input("tipe", sql.NVarChar, tipe)
    .input("nominal", sql.Float, nominal)
    .input("status", sql.NVarChar, "NEW")
    .query(`
      INSERT INTO ${db.tableLog()} (STORE, BANK, TIPE_BAYAR, NOMINAL, STATUS_TRANS)
      VALUES (@store, @bank, @tipe, @nominal, @status)
    `);

  return {
    store,
    bank: bankLabel,
    tipeBayar: tipe,
    nominal,
    reused: false,
  };
}

async function cancelLog({ storeId, bank, tipeBayar, amount, ecrTransId }) {
  const master = await db.loadMidMaster();
  const store = String(storeId || master.storeId || "").trim();
  const p = await db.getPool();
  const bankKey = db.normalizeBankKey(bank);
  const aliases =
    bankKey === "MDR"
      ? ["MDR", "MANDIRI", "YOKKE", "BANK MANDIRI"]
      : bankKey === "BNI"
        ? ["BNI", "BANK BNI"]
        : bankKey === "BCA"
          ? ["BCA", "BANK BCA"]
          : bankKey === "BRI"
            ? ["BRI", "BANK BRI"]
            : [String(bank).toUpperCase()];

  let rows = 0;

  if (ecrTransId) {
    try {
      const r = await p
        .request()
        .input("store", sql.NVarChar, store)
        .input("ecrId", sql.NVarChar, String(ecrTransId).trim())
        .input("status", sql.NVarChar, "CANCEL")
        .query(`
          UPDATE TOP (1) ${db.tableLog()}
          SET STATUS_TRANS = @status
          WHERE STORE = @store
            AND LTRIM(RTRIM(ECR_TRANS_ID)) = @ecrId
            AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) IN ('NEW')
        `);
      rows = r.rowsAffected?.[0] || 0;
    } catch {
      /* column may not exist — fall through */
    }
  }

  if (!rows) {
    const req = p
      .request()
      .input("store", sql.NVarChar, store)
      .input("tipe", sql.NVarChar, String(tipeBayar || "").trim())
      .input("nominal", sql.Float, Number(amount))
      .input("status", sql.NVarChar, "CANCEL");
    const inList = aliases
      .map((alias, i) => {
        req.input(`b${i}`, sql.NVarChar, alias);
        return `@b${i}`;
      })
      .join(", ");
    const r2 = await req.query(`
      UPDATE TOP (1) ${db.tableLog()}
      SET STATUS_TRANS = @status
      WHERE STORE = @store
        AND UPPER(LTRIM(RTRIM(BANK))) IN (${inList})
        AND UPPER(LTRIM(RTRIM(TIPE_BAYAR))) = UPPER(@tipe)
        AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
    `);
    rows = r2.rowsAffected?.[0] || 0;
  }

  return { ok: rows > 0, rowsAffected: rows, status: "CANCEL" };
}

module.exports = {
  ...db,
  insertNewLog,
  cancelLog,
};
