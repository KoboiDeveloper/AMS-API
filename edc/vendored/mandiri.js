const crypto = require('crypto')
const fs = require('fs')
const path = require('path')
const https = require('https')
const http = require('http')
const { URL } = require('url')

let cachedJwt = null
let jwtFetchedAt = 0
/**
 * Snapshot ECR Push terakhir.
 * Identity (MID/TID/amount/ecrId/category) harus sama dengan push.
 * inquiryDate/Time HARUS jam sekarang — UAT lunas: push 134121 / inquiry 134137.
 * Membekukan jam push = host selalu AG.
 */
let lastPush = null
const LAST_PUSH_FILE = path.join(__dirname, '..', '.mdr-last-push.json')

function loadLastPush() {
  try {
    const snap = JSON.parse(fs.readFileSync(LAST_PUSH_FILE, 'utf8'))
    if (snap?.merchantEcrTransID) lastPush = snap
  } catch {
    /* belum ada */
  }
}

function persistLastPush(snap) {
  if (!snap?.merchantEcrTransID) return
  lastPush = snap
  try {
    fs.writeFileSync(LAST_PUSH_FILE, JSON.stringify(snap, null, 2), 'utf8')
  } catch {
    /* ignore */
  }
}

loadLastPush()

function cfg() {
  return {
    baseUrl: (process.env.MDR_BASE_URL || process.env.BANK3_BASE_URL || 'https://tst.yokke.co.id:7778')
      .replace(/\/$/, '')
      .trim(),
    mtiKey: (process.env.MDR_MTI_KEY || process.env.X_MTI_KEY || '').trim(),
    mtiPass: (process.env.MDR_MTI_PASS || process.env.X_MTI_PASS || '').trim(),
    tokenRequestorID: (process.env.MDR_TOKEN_REQUESTOR_ID || 'AMSECR').trim(),
    merchantID: (process.env.MDR_MERCHANT_ID || '').trim(),
    terminalID: (process.env.MDR_TERMINAL_ID || '').trim(),
    transCategory: (process.env.MDR_TRANS_CATEGORY || '3C30').trim(),
    ecrTransPrefix: (process.env.MDR_ECR_TRANS_PREFIX || 'MDR').trim(),
    inquiryCategory: (process.env.MDR_INQUIRY_CATEGORY || '3730').trim(),
    inquiryIntervalMs: Number(process.env.MDR_INQUIRY_INTERVAL_MS || 5000),
    inquiryMaxMs: Number(process.env.MDR_INQUIRY_MAX_MS || 180000),
    timeoutMs: Number(process.env.MDR_TIMEOUT_MS || process.env.BCA_TIMEOUT_MS || 60000),
  }
}

function isConfigured() {
  const c = cfg()
  return Boolean(c.baseUrl && c.mtiKey && c.mtiPass && c.tokenRequestorID && c.merchantID && c.terminalID)
}

function pad(n, len = 2) {
  return String(n).padStart(len, '0')
}

/** Postman: YYYY-MM-DD HH:mm:ss */
function timestampJwt() {
  const d = new Date()
  // lokal machine time (sama seperti moment() di Postman)
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    ` ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
  )
}

function nowParts() {
  const d = new Date()
  return {
    pushDate: `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}`,
    pushTime: `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`,
    requestID: `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`,
  }
}

/**
 * CryptoJS.HmacSHA512(payload, pass).toString() → hex (default)
 */
function hmacSha512Hex(payload, secret) {
  return crypto.createHmac('sha512', secret).update(payload, 'utf8').digest('hex')
}

/** Amount → 12 digit minor units, e.g. 123321 → 000012332100 (asumsi 2 desimal) */
function formatAmount12(amount) {
  const n = Number(String(amount).replace(/,/g, ''))
  if (Number.isNaN(n) || n < 0) throw new Error('Amount tidak valid')
  const minor = Math.round(n * 100)
  return String(minor).padStart(12, '0')
}

function generateEcrTransId() {
  const c = cfg()
  const { requestID } = nowParts()
  const rand = String(Math.floor(Math.random() * 900) + 100)
  return `${c.ecrTransPrefix}${requestID.slice(-6)}${rand}`.slice(0, 20)
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
        rejectUnauthorized: false, // TST sering pakai cert self-signed
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

/**
 * GET /ecr/getjwt  (POST → HTTP 405)
 * X-SIGNATURE = HMAC-SHA512(X-MTI-Key|X-TIMESTAMP, X-MTI-Pass).hex
 */
async function getJwt() {
  const c = cfg()
  if (!c.mtiKey || !c.mtiPass) {
    throw Object.assign(new Error('MDR_MTI_KEY / MDR_MTI_PASS belum diisi di .env'), { step: 'config' })
  }

  const ts = timestampJwt()
  const stringToSign = `${c.mtiKey}|${ts}`
  const signature = hmacSha512Hex(stringToSign, c.mtiPass)
  const url = `${c.baseUrl}/ecr/getjwt`

  const request = {
    method: 'GET',
    url,
    headers: {
      'X-MTI-Key': c.mtiKey,
      'X-TIMESTAMP': ts,
      'X-SIGNATURE': signature,
    },
    body: null,
    stringToSign,
    formula: 'HMAC-SHA512(X-MTI-Key|X-TIMESTAMP, X-MTI-Pass).hex',
  }

  const res = await httpRequest({
    method: 'GET',
    url,
    headers: request.headers,
    body: null,
    timeoutMs: c.timeoutMs,
  })

  const exchange = { request, httpStatus: res.status, response: res.data }

  if (res.status < 200 || res.status >= 300 || !res.data?.jwt) {
    const err = new Error(res.data?.message || res.data?.responseMessage || `Get JWT gagal (HTTP ${res.status})`)
    err.detail = res.data
    err.request = request
    err.httpStatus = res.status
    err.exchange = exchange
    throw err
  }

  cachedJwt = res.data.jwt
  jwtFetchedAt = Date.now()

  return {
    ok: true,
    message: 'JWT OK',
    jwtPreview: `${cachedJwt.slice(0, 24)}…`,
    jwt: cachedJwt,
    exchange,
  }
}

/**
 * POST /ecr/ecrPush
 * signature = HMAC-SHA512(JSON.stringify(body), X-MTI-Pass).hex
 * Authorization = Bearer {jwt} — JWT wajib dari Get JWT sebelumnya (tidak auto-refresh)
 */
async function ecrPush({
  amount,
  merchantEcrTransID,
  transCategory,
  pushDate,
  pushTime,
  merchantID,
  terminalID,
}) {
  const c = cfg()
  if (!c.mtiKey || !c.mtiPass || !c.tokenRequestorID) {
    throw Object.assign(
      new Error('Konfigurasi Mandiri belum lengkap. Isi MDR_* di .env'),
      { step: 'config' }
    )
  }

  const mid = (merchantID || c.merchantID || '').trim()
  const tid = (terminalID || c.terminalID || '').trim()
  if (!mid || !tid) {
    throw Object.assign(new Error('merchantID / terminalID Mandiri belum ada'), { step: 'config' })
  }

  if (!cachedJwt) {
    throw Object.assign(
      new Error('JWT belum ada. Klik Get JWT dulu sebelum ECR Push.'),
      { step: 'jwt' }
    )
  }

  const parts = nowParts()
  const body = {
    pushDate: pushDate || parts.pushDate,
    pushTime: pushTime || parts.pushTime,
    merchantID: mid,
    terminalID: tid,
    transactionAmount: formatAmount12(amount),
    transCategory: transCategory || c.transCategory || '3C30',
    merchantEcrTransID: merchantEcrTransID || generateEcrTransId(),
  }

  // Harus stringify sama dengan yang di-sign (tanpa whitespace ekstra)
  const payloadStr = JSON.stringify(body)
  const signature = hmacSha512Hex(payloadStr, c.mtiPass)
  const requestID = parts.requestID
  const url = `${c.baseUrl}/ecr/ecrPush`

  const headers = {
    requestID,
    tokenRequestorID: c.tokenRequestorID,
    signature,
    Authorization: `Bearer ${cachedJwt}`,
    'Content-Type': 'application/json',
  }

  const request = {
    method: 'POST',
    url,
    headers,
    body,
    stringToSign: payloadStr,
    formula: 'HMAC-SHA512(JSON.stringify(body), X-MTI-Pass).hex',
  }

  const res = await httpRequest({
    method: 'POST',
    url,
    headers,
    body: payloadStr,
    timeoutMs: c.timeoutMs,
  })

  const exchange = { request, httpStatus: res.status, response: res.data }

  const rc = String(res.data?.responseCode || '')
  if (res.status < 200 || res.status >= 300 || (rc && rc !== '00')) {
    const err = new Error(
      res.data?.message ||
        res.data?.responseMessage ||
        (rc ? `ECR Push gagal (responseCode ${rc})` : `ECR Push gagal (HTTP ${res.status})`)
    )
    err.detail = res.data
    err.request = request
    err.httpStatus = res.status
    err.exchange = exchange
    // Push ditolak host/EDC = payment gagal definitif
    err.paymentFailed = true
    err.step = 'pay'
    throw err
  }

  persistLastPush({
    pushDate: body.pushDate,
    pushTime: body.pushTime,
    merchantID: body.merchantID,
    terminalID: body.terminalID,
    transactionAmount: body.transactionAmount,
    transCategory: body.transCategory,
    merchantEcrTransID: body.merchantEcrTransID,
  })

  return {
    ok: true,
    data: {
      ...res.data,
      merchantEcrTransID: body.merchantEcrTransID,
      requestID,
      pushDate: body.pushDate,
      pushTime: body.pushTime,
      merchantID: body.merchantID,
      terminalID: body.terminalID,
      transactionAmount: body.transactionAmount,
      transCategory: body.transCategory,
      approvalCode: String(
        res.data?.approvalCode ||
          res.data?.approveCode ||
          res.data?.ApprovalCode ||
          body.merchantEcrTransID ||
          ''
      ).trim(),
    },
    exchange,
  }
}

/**
 * POST /ecr/inquiryResultEcr
 * Body mengikuti sample UAT / Bruno inquiryResultEcr.
 */
async function inquiryResultEcr({
  inquiryDate,
  inquiryTime,
  merchantID,
  terminalID,
  transactionAmount,
  transCategory,
  merchantEcrTransID,
  amount,
}) {
  const c = cfg()
  if (!c.mtiKey || !c.mtiPass || !c.tokenRequestorID) {
    throw Object.assign(
      new Error('Konfigurasi Mandiri belum lengkap. Isi MDR_* di .env'),
      { step: 'config' }
    )
  }

  const src = lastPush || {}
  const mid = (merchantID || src.merchantID || c.merchantID || '').trim()
  const tid = (terminalID || src.terminalID || c.terminalID || '').trim()
  const ecrId = String(merchantEcrTransID || src.merchantEcrTransID || '').trim()
  if (!mid || !tid) {
    throw Object.assign(new Error('merchantID / terminalID Mandiri belum ada'), { step: 'config' })
  }
  if (!cachedJwt) {
    throw Object.assign(new Error('JWT belum ada. Klik Get JWT dulu sebelum Inquiry Result.'), {
      step: 'jwt',
    })
  }
  if (!ecrId) {
    throw Object.assign(new Error('merchantEcrTransID kosong — tidak bisa inquiry result'), {
      step: 'inquiry',
    })
  }

  const amt12 =
    transactionAmount ||
    src.transactionAmount ||
    (amount != null && amount !== '' ? formatAmount12(amount) : '')
  if (!amt12) {
    throw Object.assign(new Error('transactionAmount kosong — push dulu sebelum Cek'), {
      step: 'inquiry',
    })
  }

  // Urutan key = UAT yang RC 00. Jam inquiry = sekarang (bukan jam push).
  const parts = nowParts()
  const body = {
    merchantID: mid,
    terminalID: tid,
    transactionAmount: amt12,
    merchantEcrTransID: ecrId,
    transCategory: transCategory || src.transCategory || c.transCategory || '3C30',
    inquiryDate: parts.pushDate,
    inquiryTime: parts.pushTime,
  }

  const payloadStr = JSON.stringify(body)
  const signature = hmacSha512Hex(payloadStr, c.mtiPass)
  const requestID = parts.requestID
  const url = `${c.baseUrl}/ecr/inquiryResultEcr`
  const headers = {
    requestID,
    tokenRequestorID: c.tokenRequestorID,
    signature,
    Authorization: `Bearer ${cachedJwt}`,
    'Content-Type': 'application/json',
  }
  const request = {
    method: 'POST',
    url,
    headers,
    body,
    stringToSign: payloadStr,
    formula: 'HMAC-SHA512(JSON.stringify(body), X-MTI-Pass).hex',
  }
  const res = await httpRequest({
    method: 'POST',
    url,
    headers,
    body: payloadStr,
    timeoutMs: c.timeoutMs,
  })
  const exchange = { request, httpStatus: res.status, response: res.data }

  // HTTP 401/5xx = error. AG = HTTP 200, trx belum settle — jangan throw.
  if (res.status < 200 || res.status >= 300) {
    const err = new Error(
      res.data?.message ||
        res.data?.responseMessage ||
        res.data?.error_description ||
        `Inquiry Result gagal (HTTP ${res.status})`
    )
    err.detail = res.data
    err.request = request
    err.httpStatus = res.status
    err.exchange = exchange
    err.step = res.status === 401 ? 'jwt' : 'inquiry'
    err.pending = res.status === 401
    throw err
  }

  const paid = isSettledPayment(res.data)
  const rc = String(res.data?.responseCode || res.data?.transResultCode || '').trim()
  const failed = !paid && isFailedInquiry(res.data)
  return {
    ok: paid,
    pending: false,
    failed,
    data: { ...res.data, requestID, merchantEcrTransID: ecrId },
    exchange,
    hollow00: isHollow00(res.data, rc),
  }
}

/**
 * POST /ecr/inquiryStatTrans
 * signature = HMAC-SHA512(JSON.stringify(body), X-MTI-Pass).hex
 * Headers sama seperti ecrPush (requestID, tokenRequestorID, signature, Bearer JWT)
 */
async function inquiryStatTrans({
  inquiryDate,
  inquiryTime,
  merchantID,
  terminalID,
  transactionAmount,
  transCategory,
  approvalCode,
  amount,
}) {
  const c = cfg()
  if (!c.mtiKey || !c.mtiPass || !c.tokenRequestorID) {
    throw Object.assign(
      new Error('Konfigurasi Mandiri belum lengkap. Isi MDR_* di .env'),
      { step: 'config' }
    )
  }

  const mid = (merchantID || c.merchantID || '').trim()
  const tid = (terminalID || c.terminalID || '').trim()
  if (!mid || !tid) {
    throw Object.assign(new Error('merchantID / terminalID Mandiri belum ada'), { step: 'config' })
  }

  if (!cachedJwt) {
    throw Object.assign(
      new Error('JWT belum ada. Klik Get JWT dulu sebelum Inquiry.'),
      { step: 'jwt' }
    )
  }

  const code = String(approvalCode || '').trim()
  if (!code) {
    throw Object.assign(new Error('approvalCode kosong — tidak bisa inquiry status'), {
      step: 'inquiry',
    })
  }

  const parts = nowParts()
  // Urutan key mengikuti sample Postman (penting untuk signature)
  const body = {
    inquiryDate: inquiryDate || parts.pushDate,
    inquiryTime: inquiryTime || parts.pushTime,
    merchantID: mid,
    terminalID: tid,
    transactionAmount: transactionAmount || formatAmount12(amount),
    transCategory: transCategory || c.inquiryCategory || '3730',
    approvalCode: code,
  }

  const payloadStr = JSON.stringify(body)
  const signature = hmacSha512Hex(payloadStr, c.mtiPass)
  const requestID = parts.requestID
  const url = `${c.baseUrl}/ecr/inquiryStatTrans`

  const headers = {
    requestID,
    tokenRequestorID: c.tokenRequestorID,
    signature,
    Authorization: `Bearer ${cachedJwt}`,
    'Content-Type': 'application/json',
  }

  const request = {
    method: 'POST',
    url,
    headers,
    body,
    stringToSign: payloadStr,
    formula: 'HMAC-SHA512(JSON.stringify(body), X-MTI-Pass).hex',
  }

  const res = await httpRequest({
    method: 'POST',
    url,
    headers,
    body: payloadStr,
    timeoutMs: c.timeoutMs,
  })

  const exchange = { request, httpStatus: res.status, response: res.data }
  const rc = String(res.data?.responseCode || '').trim()
  const msg = String(res.data?.message || res.data?.responseMessage || '').toLowerCase()
  const success = res.status >= 200 && res.status < 300 && (!rc || rc === '00')

  if (!success) {
    // Kode/declined definitif → paymentFailed. Sisanya (belum ada di host / in progress) = pending.
    const declined =
      /declin|reject|fail|cancel|void|insufficient|invalid pin|expired|do not honour|pickup/i.test(
        msg
      ) || ['05', '12', '14', '51', '54', '55', '57', '61', '62', '65', '75', '91', '96'].includes(rc)

    const err = new Error(
      res.data?.message ||
        res.data?.responseMessage ||
        (rc ? `Inquiry belum sukses (responseCode ${rc})` : `Inquiry gagal (HTTP ${res.status})`)
    )
    err.detail = res.data
    err.request = request
    err.httpStatus = res.status
    err.exchange = exchange
    err.pending = !declined
    err.paymentFailed = Boolean(declined)
    err.step = 'inquiry'
    throw err
  }

  return {
    ok: true,
    data: { ...res.data, requestID, approvalCode: code },
    exchange,
  }
}

function hasText(v) {
  return String(v || '').trim() !== ''
}

function isRc00(data) {
  const rc = String(data?.responseCode || '').trim()
  const trc = String(data?.transResultCode || '').trim()
  return rc === '00' || rc === '0' || trc === '00'
}

/** Host kadang balas 00 + MID/TID saja saat timeout — transactionType kosong, bukan lunas. */
function isHollow00(data, rc) {
  const code = rc != null ? String(rc).trim() : ''
  if (!isRc00(data) && code !== '00' && code !== '0') return false
  return !hasSettlementEvidence(data)
}

/**
 * Lunas hanya jika RC 00 DAN ada bukti settle (bukan timeout hollow 00).
 * Debit UAT: transactionType SALE + RRN + approvalCode + totalAmount.
 * QRIS lunas: transactionType "QRIS PAY" + RRN/PAN + totalAmount.
 */
function hasSettlementEvidence(data) {
  if (!data || typeof data !== 'object') return false
  const type = String(data.transactionType || '').trim()
  if (type) return true
  if (hasText(data.retrievalReferenceNumber) || hasText(data.qrReferenceNumber)) return true
  if (hasText(data.approvalCode)) return true
  if (hasText(data.maskedCardNumber) || hasText(data.cardBrand)) return true
  if (hasText(data.customerPAN) || hasText(data.customerName)) return true
  const total = String(data.totalAmount || '').replace(/0/g, '').trim()
  return Boolean(total)
}

function isSettledPayment(data) {
  return isRc00(data) && hasSettlementEvidence(data)
}

function isAgResponse(data) {
  const rc = String(data?.responseCode || '').trim().toUpperCase()
  return rc === 'AG'
}

/** Hollow 00 = gagal definitif. AG = belum settle, tetap NEW. */
function isFailedInquiry(data) {
  if (!data || typeof data !== 'object') return false
  if (isSettledPayment(data)) return false
  if (isAgResponse(data)) return false
  const rc = String(data.responseCode || '').trim().toUpperCase()
  return isHollow00(data, rc)
}

function isPaidRc(data) {
  return isSettledPayment(data)
}

/**
 * Poll HANYA /ecr/inquiryResultEcr.
 * /ecr/inquiryStatTrans di host ini hampir selalu {"responseCode":"03"}
 * meski kartu sudah approved — jangan dipakai penentu SUCCESS.
 */
async function waitInquirySuccess(params, { intervalMs, maxMs, onAttempt, shouldStop } = {}) {
  const c = cfg()
  const every = Number(intervalMs || c.inquiryIntervalMs || 5000)
  const limit = Number(maxMs || c.inquiryMaxMs || 180000)
  const started = Date.now()
  let attempt = 0
  let lastExchange = null
  const ecrId = String(params.merchantEcrTransID || params.approvalCode || '').trim()

  if (!ecrId) {
    const err = new Error('merchantEcrTransID kosong — tidak bisa inquiry result')
    err.step = 'inquiry'
    err.pending = true
    throw err
  }

  // Jangan inquiry terlalu cepat — EDC baru buka QR/sale, hit host bisa bikin connection timeout di mesin
  const firstWait = Number(process.env.MDR_INQUIRY_FIRST_WAIT_MS || 8000)
  await new Promise((r) => setTimeout(r, Math.max(firstWait, every)))

  while (Date.now() - started < limit) {
    if (typeof shouldStop === 'function' && shouldStop()) {
      const err = new Error('Inquiry dibatalkan (worker stop) — status tetap NEW')
      err.exchange = lastExchange
      err.step = 'inquiry'
      err.pending = true
      throw err
    }

    attempt += 1

    if (!cachedJwt) {
      try {
        await getJwt()
      } catch (err) {
        err.pending = true
        err.step = err.step || 'jwt'
        throw err
      }
    }

    try {
      const result = await inquiryResultEcr({
        inquiryDate: params.inquiryDate,
        inquiryTime: params.inquiryTime,
        merchantID: params.merchantID,
        terminalID: params.terminalID,
        transactionAmount: params.transactionAmount,
        amount: params.amount,
        merchantEcrTransID: ecrId,
        transCategory: params.resultTransCategory || params.transCategory || c.transCategory,
      })
      lastExchange = result.exchange
      if (isSettledPayment(result.data)) {
        if (typeof onAttempt === 'function') {
          onAttempt({ attempt, ok: true, exchange: result.exchange, data: result.data })
        }
        return { ...result, attempts: attempt }
      }
      if (typeof onAttempt === 'function') {
        const hollow = result.hollow00 || isHollow00(result.data)
        onAttempt({
          attempt,
          ok: false,
          message: hollow
            ? `inquiryResultEcr rc=00 hollow (timeout) · transactionType kosong — belum SUCCESS`
            : `inquiryResultEcr rc=${result.data?.responseCode || '-'}`,
          exchange: result.exchange,
          detail: result.data,
        })
      }
    } catch (err) {
      lastExchange = err.exchange || lastExchange
      if (err.step === 'config') throw err
      if (err.step === 'jwt') {
        cachedJwt = null
      } else if (err.paymentFailed) {
        throw err
      }
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
    `inquiryResultEcr belum settle setelah ${Math.round((Date.now() - started) / 1000)}s · tetap inquiry ${ecrId} (jangan push baru sebelum Selesai)`
  )
  err.exchange = lastExchange
  err.step = 'inquiry'
  err.pending = true
  throw err
}

module.exports = {
  isConfigured,
  getJwt,
  ecrPush,
  inquiryResultEcr,
  inquiryStatTrans,
  waitInquirySuccess,
  isSettledPayment,
  isFailedInquiry,
  isAgResponse,
  isHollow00,
  cfg,
  formatAmount12,
  hmacSha512Hex,
  hasJwt: () => Boolean(cachedJwt),
  getLastPush: () => lastPush,
  rememberPush(snapshot) {
    persistLastPush(snapshot)
  },
}
