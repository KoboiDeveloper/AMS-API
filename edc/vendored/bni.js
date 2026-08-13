const crypto = require('crypto')
const fs = require('fs')
const path = require('path')
const https = require('https')
const http = require('http')
const { URL } = require('url')

let cachedJwt = null
let jwtFetchedAt = 0
let lastPush = null
const LAST_PUSH_FILE = path.join(__dirname, '..', '.bni-last-push.json')

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
    baseUrl: (process.env.BNI_BASE_URL || 'https://tst.yokke.co.id:7778').replace(/\/$/, '').trim(),
    mtiKey: (process.env.BNI_MTI_KEY || '').trim(),
    mtiPass: (process.env.BNI_MTI_PASS || '').trim(),
    tokenRequestorID: (process.env.BNI_TOKEN_REQUESTOR_ID || 'MTI-STORE').trim(),
    merchantID: (process.env.BNI_MERCHANT_ID || '').trim(),
    terminalID: (process.env.BNI_TERMINAL_ID || '').trim(),
    transCategory: (process.env.BNI_TRANS_CATEGORY || '3C30').trim(),
    ecrTransPrefix: (process.env.BNI_ECR_TRANS_PREFIX || 'BNI').trim(),
    qrTipAmount: (process.env.BNI_QR_TIP_AMOUNT || '000000000000').trim(),
    inquiryIntervalMs: Number(process.env.BNI_INQUIRY_INTERVAL_MS || 5000),
    timeoutMs: Number(process.env.BNI_TIMEOUT_MS || 60000),
  }
}

function isConfigured() {
  const c = cfg()
  return Boolean(c.baseUrl && c.mtiKey && c.mtiPass && c.tokenRequestorID && c.merchantID && c.terminalID)
}

function pad(n, len = 2) {
  return String(n).padStart(len, '0')
}

function timestampJwt() {
  const d = new Date()
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

function hmacSha512Hex(payload, secret) {
  return crypto.createHmac('sha512', secret).update(payload, 'utf8').digest('hex')
}

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

async function getJwt() {
  const c = cfg()
  if (!c.mtiKey || !c.mtiPass) {
    throw Object.assign(new Error('BNI_MTI_KEY / BNI_MTI_PASS belum diisi di .env'), { step: 'config' })
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
    throw Object.assign(new Error('Konfigurasi BNI belum lengkap. Isi BNI_* di .env'), { step: 'config' })
  }

  const mid = (merchantID || c.merchantID || '').trim()
  const tid = (terminalID || c.terminalID || '').trim()
  if (!mid || !tid) {
    throw Object.assign(new Error('merchantID / terminalID BNI belum ada'), { step: 'config' })
  }

  if (!cachedJwt) {
    throw Object.assign(new Error('JWT belum ada. Klik Get JWT dulu sebelum ECR Push.'), { step: 'jwt' })
  }

  const parts = nowParts()
  const category = transCategory || c.transCategory || '3C30'
  const body = {
    pushDate: pushDate || parts.pushDate,
    pushTime: pushTime || parts.pushTime,
    merchantID: mid,
    terminalID: tid,
    transactionAmount: formatAmount12(amount),
    transCategory: category,
    merchantEcrTransID: merchantEcrTransID || generateEcrTransId(),
  }
  if (String(category).toUpperCase().startsWith('3C') && c.qrTipAmount) {
    body.qrTipAmount = c.qrTipAmount
  }

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
    },
    exchange,
  }
}

async function inquiryResultEcr({
  merchantID,
  terminalID,
  transactionAmount,
  transCategory,
  merchantEcrTransID,
  amount,
}) {
  const c = cfg()
  if (!c.mtiKey || !c.mtiPass || !c.tokenRequestorID) {
    throw Object.assign(new Error('Konfigurasi BNI belum lengkap. Isi BNI_* di .env'), { step: 'config' })
  }

  const src = lastPush || {}
  const mid = (merchantID || src.merchantID || c.merchantID || '').trim()
  const tid = (terminalID || src.terminalID || c.terminalID || '').trim()
  const ecrId = String(merchantEcrTransID || src.merchantEcrTransID || '').trim()
  if (!mid || !tid) {
    throw Object.assign(new Error('merchantID / terminalID BNI belum ada'), { step: 'config' })
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

function hasText(v) {
  return String(v || '').trim() !== ''
}

function isRc00(data) {
  const rc = String(data?.responseCode || '').trim()
  const trc = String(data?.transResultCode || '').trim()
  return rc === '00' || rc === '0' || trc === '00'
}

function isHollow00(data, rc) {
  const code = rc != null ? String(rc).trim() : ''
  if (!isRc00(data) && code !== '00' && code !== '0') return false
  return !hasSettlementEvidence(data)
}

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

function isFailedInquiry(data) {
  if (!data || typeof data !== 'object') return false
  if (isSettledPayment(data)) return false
  if (isAgResponse(data)) return false
  const rc = String(data.responseCode || '').trim().toUpperCase()
  return isHollow00(data, rc)
}

module.exports = {
  isConfigured,
  getJwt,
  ecrPush,
  inquiryResultEcr,
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
