#!/usr/bin/env node
/**
 * Local EDC HTTP bridge — same behavior as ITILPOS /api/payment/edc/*
 * Run on store PC (needs SQLEXPRESS + MID_MASTER). No Electron.
 *
 *   cd edc && npm start
 *
 * Routes:
 *   POST /api/payment/edc/start
 *   POST /api/payment/edc/status
 *   POST /api/payment/edc/cancel
 *   GET  /health
 */
const http = require("http");
const fs = require("fs");
const path = require("path");

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  try {
    require("dotenv").config({ path: filePath, override: false });
  } catch {
    // ignore
  }
}

const edcDir = __dirname;
loadEnvFile(path.join(edcDir, ".env"));
loadEnvFile(path.join(edcDir, "..", ".env"));
if (process.env.EDC_ENV_FILE) {
  loadEnvFile(path.resolve(process.env.EDC_ENV_FILE));
}

const orchestrate = require("./orchestrate");

const HOST = String(process.env.EDC_HTTP_HOST || "127.0.0.1").trim();
const PORT = Number(process.env.EDC_HTTP_PORT || 8787);

function sendJson(res, status, body) {
  const raw = status === 204 ? "" : JSON.stringify(body ?? {});
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(raw),
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  });
  res.end(raw);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8").trim();
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

async function handleStart(body) {
  const bankKey = String(body.bankKey || "").trim();
  const tipeBayar = String(body.tipeBayar || "").trim();
  const amount = Number(body.amount);
  const storeId = body.storeId ? String(body.storeId) : undefined;

  if (!bankKey || !amount) {
    return { status: 400, body: { error: "bankKey dan amount wajib" } };
  }

  const result = await orchestrate.startPayment({
    bankKey,
    tipeBayar,
    amount,
    storeId,
  });
  return { status: 200, body: result };
}

async function handleStatus(body) {
  const result = await orchestrate.checkPaymentStatus({
    bankKey: body.bankKey,
    tipeBayar: body.tipeBayar,
    amount: body.amount,
    ecrTransId: body.ecrTransId,
    partnerReferenceNo: body.partnerReferenceNo,
    storeId: body.storeId,
  });
  return { status: 200, body: result };
}

async function handleCancel(body) {
  const result = await orchestrate.cancelPayment({
    bankKey: body.bankKey,
    tipeBayar: body.tipeBayar,
    amount: body.amount,
    ecrTransId: body.ecrTransId,
    storeId: body.storeId,
  });
  return {
    status: 200,
    body: {
      ok: Boolean(result.ok),
      message: result.ok
        ? "STATUS_TRANS di-set CANCEL"
        : "Tidak ada row NEW yang di-cancel (mungkin sudah final)",
      ...result,
    },
  };
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${HOST}:${PORT}`);
  const pathname = url.pathname.replace(/\/+$/, "") || "/";

  if (req.method === "OPTIONS") {
    sendJson(res, 204, {});
    return;
  }

  if (req.method === "GET" && (pathname === "/health" || pathname === "/api/payment/edc/health")) {
    sendJson(res, 200, {
      ok: true,
      service: "ams-edc-bridge",
      profile: process.env.SQL_PROFILE || "toko",
    });
    return;
  }

  if (req.method !== "POST") {
    sendJson(res, 405, { ok: false, error: "method not allowed" });
    return;
  }

  let body;
  try {
    body = await readJson(req);
  } catch {
    sendJson(res, 400, { ok: false, error: "invalid JSON body" });
    return;
  }

  try {
    let out;
    if (pathname === "/api/payment/edc/start") {
      out = await handleStart(body);
    } else if (pathname === "/api/payment/edc/status") {
      out = await handleStatus(body);
    } else if (pathname === "/api/payment/edc/cancel") {
      out = await handleCancel(body);
    } else {
      sendJson(res, 404, { ok: false, error: "not found" });
      return;
    }
    sendJson(res, out.status, out.body);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    sendJson(res, 500, { ok: false, error: message, status: "failed" });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[ams-edc-bridge] listening http://${HOST}:${PORT}`);
  console.log(`[ams-edc-bridge] SQL_PROFILE=${process.env.SQL_PROFILE || "toko"}`);
  console.log("[ams-edc-bridge] routes: /api/payment/edc/start|status|cancel");
});
