#!/usr/bin/env node
/**
 * CLI bridge: Go API shells out here so browser never talks to MSSQL/bank SDKs.
 * Usage: node cli.js <start|status|cancel> [jsonPayload]
 * Payload may also be piped on stdin.
 */
const fs = require("fs");
const path = require("path");

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  try {
    require("dotenv").config({ path: filePath, override: false });
  } catch {
    // dotenv optional until npm install
  }
}

const edcDir = __dirname;
loadEnvFile(path.join(edcDir, ".env"));
loadEnvFile(path.join(edcDir, "..", ".env"));
if (process.env.EDC_ENV_FILE) {
  loadEnvFile(path.resolve(process.env.EDC_ENV_FILE));
}

const orchestrate = require("./orchestrate");

function readPayload() {
  const fromArg = process.argv[3];
  if (fromArg && fromArg.trim()) {
    return JSON.parse(fromArg);
  }
  const raw = fs.readFileSync(0, "utf8").trim();
  if (!raw) return {};
  return JSON.parse(raw);
}

function writeResult(obj, exitCode = 0) {
  process.stdout.write(JSON.stringify(obj));
  process.exit(exitCode);
}

async function main() {
  const cmd = String(process.argv[2] || "").trim().toLowerCase();
  if (!["start", "status", "cancel"].includes(cmd)) {
    writeResult(
      { ok: false, error: "usage: node cli.js <start|status|cancel> '{...}'" },
      2
    );
  }

  let body;
  try {
    body = readPayload();
  } catch (err) {
    writeResult({ ok: false, error: `invalid JSON payload: ${err.message}` }, 2);
  }

  try {
    if (cmd === "start") {
      const bankKey = String(body.bankKey || "").trim();
      const amount = Number(body.amount);
      if (!bankKey || !amount) {
        writeResult({ ok: false, error: "bankKey dan amount wajib", status: "failed" }, 1);
      }
      const result = await orchestrate.startPayment({
        bankKey,
        tipeBayar: String(body.tipeBayar || "").trim(),
        amount,
        storeId: body.storeId ? String(body.storeId) : undefined,
      });
      writeResult(result);
    }

    if (cmd === "status") {
      const result = await orchestrate.checkPaymentStatus({
        bankKey: body.bankKey,
        tipeBayar: body.tipeBayar,
        amount: body.amount,
        ecrTransId: body.ecrTransId,
        partnerReferenceNo: body.partnerReferenceNo,
        storeId: body.storeId,
      });
      writeResult(result);
    }

    if (cmd === "cancel") {
      const result = await orchestrate.cancelPayment({
        bankKey: body.bankKey,
        tipeBayar: body.tipeBayar,
        amount: body.amount,
        ecrTransId: body.ecrTransId,
        storeId: body.storeId,
      });
      writeResult({
        ok: Boolean(result.ok),
        message: result.ok
          ? "STATUS_TRANS di-set CANCEL"
          : "Tidak ada row NEW yang di-cancel (mungkin sudah final)",
        ...result,
      });
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    writeResult({ ok: false, error: message, status: "failed" }, 1);
  }
}

main();
