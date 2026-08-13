const crypto = require('crypto')
const https = require('https')
const http = require('http')
const { URL } = require('url')

function normalizePath(path, fallback) {
  const p = String(path || fallback || '').trim()
  if (!p) return fallback || ''
  return p.startsWith('/') ? p : `/${p}`
}

/**
 * BRI_BASE_URL boleh full endpoint transaksi, contoh:
 * https://poselink.pcsindonesia.com/cms/transactions
 * Status tetap relative ke origin host.
 */
function resolveUrls() {
  const raw = String(process.env.BRI_BASE_URL || 'https://poselink.pcsindonesia.com/cms/transactions')
    .trim()
    .replace(/^ttps:/i, 'https:')
    .replace(/\/$/, '')

  let origin = 'https://poselink.pcsindonesia.com'
  let transactionUrl = `${origin}/cms/transactions`

  try {
    const u = new URL(raw.includes('://') ? raw : `https://${raw}`)
    origin = `${u.protocol}//${u.host}`
    if (u.pathname && u.pathname !== '/') {
      transactionUrl = `${origin}${u.pathname}`.replace(/\/$/, '')
    } else {
      const txPath = normalizePath(process.env.BRI_TRANSACTION_PATH, '/cms/transactions')
      transactionUrl = `${origin}${txPath}`
    }
  } catch {
    /* keep defaults */
  }

  return { origin, transactionUrl, baseUrl: origin }
}

function cfg() {
  const urls = resolveUrls()
  return {
    baseUrl: urls.baseUrl,
    transactionUrl: urls.transactionUrl,
    aesSecret: (process.env.BRI_AES_SECRET || 'ECR2022secretKey').trim(),
    merchantId: (process.env.BRI_MERCHANT_ID || '').trim(),
    terminalId: (process.env.BRI_TERMINAL_ID || '').trim(),
    posAddress: (process.env.BRI_POS_ADDRESS || '127.0.0.1').trim(),
    refPrefix: (process.env.BRI_REF_PREFIX || 'BRI').trim(),
    statusPathTemplate: (process.env.BRI_STATUS_PATH || '/api/v1/transaction/status/{trx_id}').trim(),
    timeoutMs: Number(process.env.BRI_TIMEOUT_MS || 180000),
    inquiryIntervalMs: Number(process.env.BRI_INQUIRY_INTERVAL_MS || 5000),
    inquiryMaxMs: Number(process.env.BRI_INQUIRY_MAX_MS || 180000),
  }
}

function isConfigured() {
  const c = cfg()
  return Boolean(c.baseUrl && c.aesSecret && c.merchantId && c.terminalId)
}

function pad(n, len = 2) {
  return String(n).padStart(len, '0')
}

/** yyyy-mm-dd HH:MM:SS (local) */
function timestampNow() {
  const d = new Date()
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    ` ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
  )
}

/** Amount → integer rupiah string, e.g. 10000 → "10000" */
function formatAmount(amount) {
  const n = Number(String(amount).replace(/,/g, ''))
  if (Number.isNaN(n) || n < 0) throw new Error('Amount tidak valid')
  return String(Math.round(n))
}

function generateTrxId() {
  const c = cfg()
  const d = new Date()
  const stamp =
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  const rand = String(Math.floor(Math.random() * 9000) + 1000)
  // alphanumeric + . = - _ per doc 4.12.0
  return `${c.refPrefix}_${stamp}_${rand}`.replace(/[^A-Za-z0-9._=-]/g, '_').slice(0, 64)
}

/**
 * AES/ECB/PKCS5Padding — mirror Java EncryptAes di dokumen POSe Link.
 * Key = SHA-1(secret).slice(0, 16)
 */
function encryptAes(strToEncrypt, secret) {
  const c = cfg()
  const myKey = secret || c.aesSecret
  if (!myKey) throw new Error('BRI_AES_SECRET belum diisi')

  const key = crypto.createHash('sha1').update(myKey, 'utf8').digest().subarray(0, 16)
  const cipher = crypto.createCipheriv('aes-128-ecb', key, null)
  cipher.setAutoPadding(true)
  const enc = Buffer.concat([cipher.update(String(strToEncrypt), 'utf8'), cipher.final()])
  return enc.toString('base64')
}

function httpRequest({ method, url, headers, body, timeoutMs }) {
  return new Promise((resolve, reject) => {
    const u = new URL(url)
    const lib = u.protocol === 'https:' ? https : http
    const payload = body == null ? null : typeof body === 'string' ? body : JSON.stringify(body)

    const req = lib.request(
      {
        protocol: u.protocol,
        hostname: u.hostname,
        port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname + u.search,
        method,
        headers: {
          ...headers,
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
        },
        timeout: timeoutMs,
        rejectUnauthorized: false,
      },
      (res) => {
        let data = ''
        res.on('data', (chunk) => (data += chunk))
        res.on('end', () => {
          let json = null
          try {
            json = data ? JSON.parse(data) : null
          } catch {
            json = { raw: data }
          }
          resolve({ status: res.statusCode, headers: res.headers, data: json, raw: data })
        })
      }
    )

    req.on('error', reject)
    req.on('timeout', () => {
      req.destroy()
      reject(new Error('Request timeout'))
    })
    if (payload) req.write(payload)
    req.end()
  })
}

function pickStatusField(data) {
  if (!data || typeof data !== 'object') return ''
  const inner = data.data && typeof data.data === 'object' ? data.data : null
  return String(
    data.status ||
      data.Status ||
      data.STATUS ||
      data.trx_status ||
      data.transaction_status ||
      data.payment_status ||
      inner?.status ||
      inner?.Status ||
      ''
  )
    .trim()
    .toLowerCase()
}

function normalizeStatus(data) {
  return pickStatusField(data)
}

/** GET /api/v1/transaction/status → SUCCESS / PENDING / FAILED (atau paid/unpaid lama). */
function classifyStatus(data) {
  const st = pickStatusField(data)
  if (st === 'success' || st === 'paid' || st === '00') return 'success'
  if (st === 'failed' || st === 'fail' || st === 'not found' || st === 'not_found' || st === 'error') {
    return 'failed'
  }
  if (st === 'pending' || st === 'unpaid' || !st) return 'pending'
  return 'pending'
}

function isPurchaseSuccess(data) {
  return classifyStatus(data) === 'success'
}

function isQrisPaid(data) {
  return classifyStatus(data) === 'success'
}

function isTerminalFail(data) {
  return classifyStatus(data) === 'failed'
}

/**
 * POST transaksi BRI ke BRI_BASE_URL (default /cms/transactions)
 * Envelope: { trx_id, mid, tid, data: AES(base64 of plaintext JSON) }
 */
async function postTransaction({ plaintext, mid, tid }) {
  const c = cfg()
  const merchantId = (mid || c.merchantId || '').trim()
  const terminalId = (tid || c.terminalId || '').trim()
  if (!merchantId || !terminalId) {
    throw Object.assign(new Error('MID / TID BRI belum ada'), { step: 'config' })
  }
  if (!c.aesSecret) {
    throw Object.assign(new Error('BRI_AES_SECRET belum diisi'), { step: 'config' })
  }

  const trxId = String(plaintext.trx_id || '').trim()
  if (!trxId) {
    throw Object.assign(new Error('trx_id wajib'), { step: 'config' })
  }

  const plaintextStr = JSON.stringify(plaintext)
  const encrypted = encryptAes(plaintextStr)
  // Hanya `token` = AES payload. Jangan kirim `data` bersamaan:
  // middleware/Ably bisa push 2x → QRIS kebuka lalu langsung nutup.
  const envelope = {
    trx_id: trxId,
    mid: merchantId,
    tid: terminalId,
    token: encrypted,
  }

  const url = c.transactionUrl
  const headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  }

  const request = {
    method: 'POST',
    url,
    headers,
    body: {
      ...envelope,
      // Inspector: tampilkan plaintext + preview encrypted
      _plaintext: plaintext,
      dataPreview: `${encrypted.slice(0, 48)}…`,
    },
    stringToSign: plaintextStr,
    formula: 'AES/ECB/PKCS5Padding · key=SHA1(secret)[0:16] · Base64',
  }

  const payloadStr = JSON.stringify(envelope)
  const res = await httpRequest({
    method: 'POST',
    url,
    headers,
    body: payloadStr,
    timeoutMs: c.timeoutMs,
  })

  const exchange = { request, httpStatus: res.status, response: res.data }

  if (res.status < 200 || res.status >= 300) {
    let message =
      res.data?.error ||
      res.data?.msg ||
      res.data?.message ||
      `BRI API gagal (HTTP ${res.status})`

    // PCS middleware: MID/TID belum mapping ke EDC di Ably
    if (/unknown mid\/tid/i.test(String(message))) {
      message =
        `unknown mid/tid combination · MID=${merchantId} TID=${terminalId}. ` +
        `Pasangan ini belum terdaftar di POSe Link Middleware (${c.baseUrl}). ` +
        `Minta PCS mendaftarkan MID/TID EDC Anda untuk koneksi API (bukan sample dokumen).`
    }

    const err = new Error(message)
    err.detail = res.data
    err.request = request
    err.httpStatus = res.status
    err.exchange = exchange
    err.step = 'pay'
    throw err
  }

  return {
    ok: true,
    data: res.data,
    plaintext,
    trxId,
    mid: merchantId,
    tid: terminalId,
    exchange,
  }
}

function normalizeBriMethod(method) {
  const m = String(method || 'purchase').trim()
  if (/^qris$/i.test(m)) return 'qris'
  return m || 'purchase'
}

function buildSalePlaintext({ amount, method, trxId, posAddress, timeStamp }) {
  const c = cfg()
  return {
    action: 'Sale',
    trx_id: trxId || generateTrxId(),
    amount: formatAmount(amount),
    pos_address: posAddress || c.posAddress || '127.0.0.1',
    time_stamp: timeStamp || timestampNow(),
    method: normalizeBriMethod(method),
  }
}

async function requestSale({ amount, merchantId, terminalId, trxId, posAddress }) {
  const plaintext = buildSalePlaintext({
    amount,
    method: 'purchase',
    trxId,
    posAddress,
  })
  const result = await postTransaction({
    plaintext,
    mid: merchantId,
    tid: terminalId,
  })

  const data = result.data || {}
  const kind = classifyStatus(data)
  if (kind === 'failed') {
    const err = new Error(
      data.msg || data.message || `Sale gagal · status=${data.status || '-'} rc=${data.rc || '-'}`
    )
    err.detail = data
    err.exchange = result.exchange
    err.step = 'pay'
    err.paymentFailed = true
    throw err
  }

  return {
    ok: true,
    pending: kind !== 'success',
    data: {
      ...data,
      trx_id: data.trx_id || plaintext.trx_id,
      method: data.method || 'purchase',
    },
    exchange: result.exchange,
  }
}

async function requestQris({ amount, merchantId, terminalId, trxId, posAddress }) {
  const plaintext = buildSalePlaintext({
    amount,
    method: 'qris',
    trxId,
    posAddress,
  })
  const result = await postTransaction({
    plaintext,
    mid: merchantId,
    tid: terminalId,
  })

  const data = result.data || {}
  const st = normalizeStatus(data)

  // paid = sukses; unpaid/pending = QR masih di EDC (jangan push Sale lagi)
  if (isTerminalFail(data)) {
    const err = new Error(data.msg || data.message || `QRIS gagal · status=${data.status || '-'}`)
    err.detail = data
    err.exchange = result.exchange
    err.step = 'pay'
    err.paymentFailed = true
    throw err
  }

  return {
    ok: true,
    pending: st === 'unpaid' || st === 'pending' || (!st && !isQrisPaid(data)),
    data: {
      ...data,
      trx_id: data.trx_id || plaintext.trx_id,
      method: data.method || 'qris',
      reference_number: data.reference_number || '',
      reff_id: data.reff_id || '',
    },
    exchange: result.exchange,
  }
}

/**
 * Inquiry status transaksi via API middleware.
 * CMS label: "POS Status Check" → GET /api/v1/transaction/status/{trx_id}
 * Fallback (EDC menu Check Trx): POST /api/v1/transaction dengan action "Check Trx"
 */
async function checkTrx({
  trxId,
  merchantId,
  terminalId,
  posAddress,
  referenceNumber,
  method,
  viaEdc,
}) {
  const c = cfg()
  const id = String(trxId || '').trim()
  if (!id) {
    throw Object.assign(new Error('trx_id wajib untuk Check Trx'), { step: 'inquiry' })
  }

  // Default: status dari middleware (sama seperti tombol di POSe Link CMS)
  if (!viaEdc) {
    const tmpl = normalizePath(c.statusPathTemplate, '/api/v1/transaction/status/{trx_id}')
    const statusPath = tmpl.replace('{trx_id}', encodeURIComponent(id))
    const url = `${c.baseUrl}${statusPath}`
    const headers = { Accept: 'application/json' }
    const request = {
      method: 'GET',
      url,
      headers,
      body: null,
      stringToSign: null,
      formula: 'GET /api/v1/transaction/status/{trx_id}',
    }

    const res = await httpRequest({
      method: 'GET',
      url,
      headers,
      body: null,
      timeoutMs: c.timeoutMs,
    })

    const exchange = { request, httpStatus: res.status, response: res.data }

    if (res.status < 200 || res.status >= 300) {
      const err = new Error(
        res.data?.error ||
          res.data?.msg ||
          res.data?.message ||
          `Status gagal (HTTP ${res.status})`
      )
      err.detail = res.data
      err.request = request
      err.httpStatus = res.status
      err.exchange = exchange
      err.step = 'inquiry'
      throw err
    }

    return {
      ok: true,
      data: res.data,
      exchange,
    }
  }

  // Fallback: push "Check Trx" ke EDC lewat POST /api/v1/transaction
  const plaintext = {
    action: 'Check Trx',
    trx_id: id,
    pos_address: posAddress || c.posAddress,
    time_stamp: timestampNow(),
  }
  if (referenceNumber) plaintext.reference_number = String(referenceNumber)
  if (method) plaintext.method = method

  const result = await postTransaction({
    plaintext,
    mid: merchantId,
    tid: terminalId,
  })

  return {
    ok: true,
    data: result.data,
    exchange: result.exchange,
  }
}

/**
 * Poll Check Trx sampai paid (QRIS) / success (purchase) / fail / timeout.
 */
async function waitPaidOrSuccess(
  { trxId, merchantId, terminalId, posAddress, referenceNumber, method, expectQris },
  { intervalMs, maxMs, onAttempt, shouldStop } = {}
) {
  const c = cfg()
  const every = Number(intervalMs || c.inquiryIntervalMs || 5000)
  const limit = Number(maxMs || c.inquiryMaxMs || 180000)
  const started = Date.now()
  let attempt = 0
  let lastExchange = null
  let lastData = null

  await new Promise((r) => setTimeout(r, every))

  while (Date.now() - started < limit) {
    attempt += 1
    if (typeof shouldStop === 'function') {
      const stop = await shouldStop()
      if (stop) {
        const reason = stop === true ? 'stop' : String(stop)
        const err = new Error(
          reason === 'cancel'
            ? `POS CANCEL · hentikan trx_id ${trxId}`
            : reason === 'final'
              ? `STATUS sudah final di POS · trx_id ${trxId}`
              : 'Inquiry dibatalkan (worker stop)'
        )
        err.exchange = lastExchange
        err.step = 'inquiry'
        err.cancelled = reason === 'cancel' || reason === 'final'
        err.pending = true
        throw err
      }
    }

    try {
      const res = await checkTrx({
        trxId,
        merchantId,
        terminalId,
        posAddress,
        referenceNumber,
        method: method || (expectQris ? 'qris' : undefined),
      })
      lastExchange = res.exchange
      lastData = res.data

      const kind = classifyStatus(res.data)
      if (kind === 'success') {
        if (typeof onAttempt === 'function') {
          onAttempt({ attempt, ok: true, exchange: res.exchange, data: res.data })
        }
        return { ...res, attempts: attempt }
      }

      if (kind === 'failed') {
        const err = new Error(
          res.data?.msg || `Check Trx FAILED · status=${res.data?.status || '-'}`
        )
        err.detail = res.data
        err.exchange = res.exchange
        err.step = 'inquiry'
        err.paymentFailed = true
        throw err
      }

      if (typeof onAttempt === 'function') {
        onAttempt({
          attempt,
          ok: false,
          message: res.data?.msg || `status=${res.data?.status || 'pending'}`,
          exchange: res.exchange,
          detail: res.data,
        })
      }
    } catch (err) {
      lastExchange = err.exchange || lastExchange
      if (err.step === 'config') throw err
      if (err.cancelled || err.paymentFailed) throw err
      if (isTerminalFail(err.detail) && err.step === 'inquiry') throw err
      if (typeof onAttempt === 'function') {
        onAttempt({
          attempt,
          ok: false,
          message: err.message,
          exchange: err.exchange || null,
          detail: err.detail || null,
        })
      }
    }

    const remain = limit - (Date.now() - started)
    if (remain <= 0) break
    await new Promise((r) => setTimeout(r, Math.min(every, remain)))
  }

  const err = new Error(
    `Inquiry timeout setelah ${Math.round((Date.now() - started) / 1000)}s · trx_id ${trxId || '-'} · last=${lastData?.status || '-'}`
  )
  err.exchange = lastExchange
  err.step = 'inquiry'
  err.pending = true
  throw err
}

module.exports = {
  cfg,
  isConfigured,
  encryptAes,
  requestSale,
  requestQris,
  checkTrx,
  waitPaidOrSuccess,
  classifyStatus,
  formatAmount,
  generateTrxId,
  isPurchaseSuccess,
  isQrisPaid,
}
