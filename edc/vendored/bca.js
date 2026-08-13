const crypto = require('crypto')
const https = require('https')
const http = require('http')
const fs = require('fs')
const path = require('path')
const { URL } = require('url')

let cachedToken = null
let tokenExpiresAt = 0
let cachedPrivateKey = null
let cachedPublicKey = null

function resolveKeyPath(envPath, fallbackRelative) {
  const raw = (envPath || fallbackRelative || '').trim()
  if (!raw) return ''
  return path.isAbsolute(raw) ? raw : path.join(__dirname, '..', raw)
}

function cfg() {
  return {
    baseUrl: (process.env.BCA_BASE_URL || 'https://api.klikbca.com').replace(/\/$/, '').trim(),
    clientId: (process.env.BCA_CLIENT_ID || '').trim(),
    clientSecret: (process.env.BCA_CLIENT_SECRET || '').trim(),
    partnerId: (process.env.BCA_PARTNER_ID || '').trim(),
    channelId: (process.env.BCA_CHANNEL_ID || '95251').trim(),
    merchantId: (process.env.BCA_MERCHANT_ID || '').trim(),
    terminalId: (process.env.BCA_TERMINAL_ID || '').trim(),
    origin: (process.env.BCA_ORIGIN || 'www.hostname.com').trim(),
    privateKey: loadPrivateKey(),
    publicKey: loadPublicKey(),
    refPrefix: (process.env.BCA_REF_PREFIX || 'EDC').trim(),
    timeoutMs: Number(process.env.BCA_TIMEOUT_MS || 60000),
    inquiryIntervalMs: Number(process.env.BCA_INQUIRY_INTERVAL_MS || 5000),
    inquiryMaxMs: Number(process.env.BCA_INQUIRY_MAX_MS || 180000),
  }
}

function isConfigured() {
  const c = cfg()
  return Boolean(c.clientId && c.clientSecret && c.privateKey && c.partnerId && c.merchantId && c.terminalId)
}

function loadPrivateKey() {
  if (cachedPrivateKey) return cachedPrivateKey

  // Default: keys/bca_private.pem
  const absolute = resolveKeyPath(process.env.BCA_PRIVATE_KEY_PATH, 'keys/bca_private.pem')
  if (fs.existsSync(absolute)) {
    cachedPrivateKey = normalizePem(fs.readFileSync(absolute, 'utf8'), 'PRIVATE KEY')
    return cachedPrivateKey
  }

  // Fallback inline .env (tidak disarankan)
  const inline = (process.env.BCA_PRIVATE_KEY || '').trim()
  if (inline) {
    cachedPrivateKey = normalizePem(inline, 'PRIVATE KEY')
    return cachedPrivateKey
  }

  throw new Error(`Private key tidak ditemukan. Letakkan di keys/bca_private.pem atau set BCA_PRIVATE_KEY_PATH`)
}

function loadPublicKey() {
  if (cachedPublicKey) return cachedPublicKey

  const absolute = resolveKeyPath(process.env.BCA_PUBLIC_KEY_PATH, 'keys/bca_public.pem')
  if (fs.existsSync(absolute)) {
    cachedPublicKey = normalizePem(fs.readFileSync(absolute, 'utf8'), 'PUBLIC KEY')
    return cachedPublicKey
  }

  const inline = (process.env.BCA_PUBLIC_KEY || '').trim()
  if (inline) {
    cachedPublicKey = normalizePem(inline, 'PUBLIC KEY')
    return cachedPublicKey
  }

  // Fallback: derive dari private key
  try {
    cachedPublicKey = derivePublicKeyPem(loadPrivateKey())
    return cachedPublicKey
  } catch {
    return ''
  }
}

function normalizePem(raw, typeHint = 'PRIVATE KEY') {
  if (!raw) return ''
  let key = raw.trim().replace(/^\uFEFF/, '')
  key = key.replace(/\\n/g, '\n')
  if (
    (key.startsWith('"') && key.endsWith('"')) ||
    (key.startsWith("'") && key.endsWith("'"))
  ) {
    key = key.slice(1, -1).replace(/\\n/g, '\n')
  }

  if (!key.includes('BEGIN')) {
    const body = key.replace(/\s+/g, '')
    const lines = body.match(/.{1,64}/g) || []
    key = `-----BEGIN ${typeHint}-----\n${lines.join('\n')}\n-----END ${typeHint}-----`
  }

  return key
}

function clearKeyCache() {
  cachedPrivateKey = null
  cachedPublicKey = null
}

function timestampNow() {
  // BCA sample & SNAP: selalu WIB +07:00, panjang tetap 25
  // Format: yyyy-MM-ddTHH:mm:ss+07:00
  const pad = (n) => String(n).padStart(2, '0')
  const wib = new Date(Date.now() + 7 * 60 * 60 * 1000)
  return (
    `${wib.getUTCFullYear()}-${pad(wib.getUTCMonth() + 1)}-${pad(wib.getUTCDate())}` +
    `T${pad(wib.getUTCHours())}:${pad(wib.getUTCMinutes())}:${pad(wib.getUTCSeconds())}+07:00`
  )
}

function minifyJson(obj) {
  if (obj === null || obj === undefined) return ''
  if (typeof obj === 'string') {
    if (!obj.trim()) return ''
    return JSON.stringify(JSON.parse(obj))
  }
  return JSON.stringify(obj)
}

function sha256HexLower(text) {
  return crypto.createHash('sha256').update(text, 'utf8').digest('hex').toLowerCase()
}

/**
 * Asymmetric signature for Access Token
 * Guide:
 *   Formula  = SHA256WithRSA(PrivateKey, StringToSign)
 *   StringToSign = X-CLIENT-KEY|Timestamp
 *   Hash Format = Base64Encode
 */
function signAsymmetric(clientId, timestamp, privateKeyPem) {
  try {
    const stringToSign = `${clientId}|${timestamp}`
    const keyObject = crypto.createPrivateKey(privateKeyPem)
    // SHA256withRSA = RSA-SHA256 + PKCS1 v1.5 (sama seperti Java)
    const signature = crypto.sign('sha256', Buffer.from(stringToSign, 'utf8'), {
      key: keyObject,
      padding: crypto.constants.RSA_PKCS1_PADDING,
    })
    return signature.toString('base64')
  } catch (err) {
    throw new Error(`Gagal sign private key (cek PEM/format): ${err.message}`)
  }
}

function derivePublicKeyPem(privateKeyPem) {
  const keyObject = crypto.createPrivateKey(privateKeyPem)
  return crypto.createPublicKey(keyObject).export({ type: 'spki', format: 'pem' })
}

function verifyAsymmetricLocal(clientId, timestamp, signatureB64, privateKeyPem) {
  const stringToSign = `${clientId}|${timestamp}`
  const pub = crypto.createPublicKey(crypto.createPrivateKey(privateKeyPem))
  return crypto.verify(
    'sha256',
    Buffer.from(stringToSign, 'utf8'),
    { key: pub, padding: crypto.constants.RSA_PKCS1_PADDING },
    Buffer.from(signatureB64, 'base64')
  )
}

/**
 * Symmetric signature for transaction APIs
 * StringToSign = HTTPMethod:RelativeUrl:AccessToken:Lowercase(Hex(SHA256(MinifyJson(Body)))):Timestamp
 * X-SIGNATURE = Base64(HMAC-SHA512(ClientSecret, StringToSign))
 */
function signSymmetric({ method, relativeUrl, accessToken, body, timestamp, clientSecret }) {
  const bodyMin = minifyJson(body)
  const bodyHash = bodyMin ? sha256HexLower(bodyMin) : sha256HexLower('')
  const stringToSign = `${method.toUpperCase()}:${relativeUrl}:${accessToken}:${bodyHash}:${timestamp}`
  const hmac = crypto.createHmac('sha512', clientSecret)
  hmac.update(stringToSign)
  return {
    signature: hmac.digest('base64'),
    stringToSign,
    bodyHash,
  }
}

let lastExternalId = 0

function uniqueExternalId() {
  // Numeric epoch ms seperti contoh BCA (max 36)
  let id = Date.now()
  if (id <= lastExternalId) id = lastExternalId + 1
  lastExternalId = id
  return String(id).slice(0, 36)
}

function generatePartnerRef() {
  const c = cfg()
  const d = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  const date = `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}`
  const seq = String(Math.floor(Math.random() * 9999) + 1).padStart(4, '0')
  // Format with "-" as recommended by docs
  return `${c.refPrefix}-${date}-${seq}`
}

function formatAmount(amount) {
  const n = Number(String(amount).replace(/,/g, ''))
  if (Number.isNaN(n) || n < 0) throw new Error('Amount tidak valid')
  return n.toFixed(2)
}

function httpRequest({ method, url, headers, body, timeoutMs }) {
  return new Promise((resolve, reject) => {
    const u = new URL(url)
    const lib = u.protocol === 'https:' ? https : http
    const payload = body ? (typeof body === 'string' ? body : minifyJson(body)) : null

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
          resolve({
            status: res.statusCode,
            headers: res.headers,
            data: json,
            raw: data,
          })
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

async function getAccessToken(force = false) {
  const c = cfg()
  if (!c.clientId || !c.privateKey) {
    throw new Error('BCA_CLIENT_ID / BCA_PRIVATE_KEY belum diisi di .env')
  }

  const now = Date.now()
  if (!force && cachedToken && now < tokenExpiresAt - 30000) {
    return cachedToken
  }

  const ts = timestampNow()
  const signature = signAsymmetric(c.clientId, ts, c.privateKey)
  const relativeUrl = '/openapi/v1.0/access-token/b2b'
  const body = { grantType: 'client_credentials' }

  const res = await httpRequest({
    method: 'POST',
    url: `${c.baseUrl}${relativeUrl}`,
    headers: {
      'X-TIMESTAMP': ts,
      'X-CLIENT-KEY': c.clientId,
      'X-SIGNATURE': signature,
      'Content-Type': 'application/json',
    },
    body,
    timeoutMs: c.timeoutMs,
  })

  if (res.status !== 200 || !res.data?.accessToken) {
    const msg = res.data?.responseMessage || `Gagal get access token (HTTP ${res.status})`
    let hint = ''
    if (/Unknown client/i.test(msg)) {
      hint =
        ' | Client ID tidak dikenal di environment ini. Pastikan Client ID/Secret sesuai environment URL di .env.'
    } else if (/\[Signature\]/i.test(msg)) {
      hint =
        ' | Public key X.509 di BCA harus pasangan private key (keys/bca_public.pem).'
    }
    const err = new Error(msg + hint)
    err.detail = res.data
    throw err
  }

  const expiresIn = Number(res.data.expiresIn || 900) * 1000
  cachedToken = res.data.accessToken
  tokenExpiresAt = Date.now() + expiresIn
  return cachedToken
}

/**
 * Test asymmetric signature + get access token (untuk tombol UI terpisah).
 * Return detail debug tanpa throw (caller cek ok).
 */
async function testSignature() {
  // reset cache supaya selalu hit API + reload key dari file
  cachedToken = null
  tokenExpiresAt = 0
  clearKeyCache()

  const c = cfg()
  const relativeUrl = '/openapi/v1.0/access-token/b2b'
  const url = `${c.baseUrl}${relativeUrl}`
  const ts = timestampNow()
  const stringToSign = `${c.clientId}|${ts}`

  if (!c.clientId) {
    return { ok: false, step: 'config', message: 'BCA_CLIENT_ID kosong', url }
  }
  if (!c.privateKey) {
    return { ok: false, step: 'config', message: 'Private key kosong (keys/bca_private.pem)', url }
  }

  let signature
  let publicKeyPem = c.publicKey || ''
  let localVerify = false
  let keyPairMatch = null
  try {
    signature = signAsymmetric(c.clientId, ts, c.privateKey)
    const derived = derivePublicKeyPem(c.privateKey)
    if (!publicKeyPem) publicKeyPem = derived
    else {
      const a = crypto.createPublicKey(publicKeyPem).export({ type: 'spki', format: 'pem' })
      const b = crypto.createPublicKey(derived).export({ type: 'spki', format: 'pem' })
      keyPairMatch = a === b
    }
    localVerify = verifyAsymmetricLocal(c.clientId, ts, signature, c.privateKey)
  } catch (err) {
    return {
      ok: false,
      step: 'sign',
      message: err.message,
      httpStatus: null,
      request: {
        method: 'POST',
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TIMESTAMP': ts,
          'X-CLIENT-KEY': c.clientId,
          'X-SIGNATURE': '(sign failed)',
        },
        body: { grantType: 'client_credentials' },
        stringToSign,
        keySource: {
          private: resolveKeyPath(process.env.BCA_PRIVATE_KEY_PATH, 'keys/bca_private.pem'),
          public: resolveKeyPath(process.env.BCA_PUBLIC_KEY_PATH, 'keys/bca_public.pem'),
        },
      },
      response: { error: err.message },
    }
  }

  const body = { grantType: 'client_credentials' }
  const requestHeaders = {
    'Content-Type': 'application/json',
    'X-TIMESTAMP': ts,
    'X-CLIENT-KEY': c.clientId,
    'X-SIGNATURE': signature,
  }

  const res = await httpRequest({
    method: 'POST',
    url,
    headers: requestHeaders,
    body,
    timeoutMs: c.timeoutMs,
  })

  const request = {
    method: 'POST',
    url,
    headers: {
      ...requestHeaders,
      'X-SIGNATURE': signature,
    },
    body,
    stringToSign,
    formula: 'Base64(SHA256WithRSA(PrivateKey, X-CLIENT-KEY|Timestamp))',
    localVerifyOk: localVerify,
    keyPairMatch,
    keySource: {
      private: resolveKeyPath(process.env.BCA_PRIVATE_KEY_PATH, 'keys/bca_private.pem'),
      public: resolveKeyPath(process.env.BCA_PUBLIC_KEY_PATH, 'keys/bca_public.pem'),
    },
    publicKeyX509: publicKeyPem,
  }

  const debug = {
    step: 'access-token',
    request,
    httpStatus: res.status,
    response: res.data,
    responseRaw: res.raw,
  }

  if (res.status === 200 && res.data?.accessToken) {
    const expiresIn = Number(res.data.expiresIn || 900) * 1000
    cachedToken = res.data.accessToken
    tokenExpiresAt = Date.now() + expiresIn
    return {
      ok: true,
      message: 'Signature OK · access token didapat',
      accessTokenPreview: `${res.data.accessToken.slice(0, 24)}…`,
      expiresIn: res.data.expiresIn,
      ...debug,
    }
  }

  let hint = res.data?.responseMessage || `HTTP ${res.status}`
  if (/Unknown client/i.test(hint)) {
    hint +=
      ' → Client ID belum terdaftar di environment URL ini. Cocokkan Client ID dengan env (simulator.api.bca.co.id).'
  } else if (/Signature/i.test(hint)) {
    hint +=
      ' → Algoritma lokal OK (localVerify). Public key yang didaftarkan ke BCA kemungkinan BUKAN pasangan private key ini. Kirim publicKeyX509 di request panel ke PIC BCA.'
  }

  return {
    ok: false,
    message: hint,
    ...debug,
  }
}

async function callTransaction({ method, relativeUrl, body }) {
  const c = cfg()
  if (!isConfigured()) {
    throw new Error('Konfigurasi BCA belum lengkap. Isi .env (CLIENT_ID, SECRET, PARTNER_ID, MERCHANT_ID, TERMINAL_ID, PRIVATE_KEY).')
  }

  const accessToken = await getAccessToken()
  const ts = timestampNow()
  const bodyMin = minifyJson(body)
  const { signature, stringToSign } = signSymmetric({
    method,
    relativeUrl,
    accessToken,
    body: bodyMin,
    timestamp: ts,
    clientSecret: c.clientSecret,
  })

  const headers = {
    Authorization: `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
    'X-TIMESTAMP': ts,
    'X-SIGNATURE': signature,
    ORIGIN: c.origin || 'www.hostname.com',
    'CHANNEL-ID': c.channelId,
    'X-PARTNER-ID': c.partnerId,
    'X-EXTERNAL-ID': uniqueExternalId(),
  }

  const url = `${c.baseUrl}${relativeUrl}`
  const request = {
    method: method.toUpperCase(),
    url,
    headers,
    body: typeof body === 'string' ? JSON.parse(bodyMin || '{}') : body,
    stringToSign,
  }

  const res = await httpRequest({
    method,
    url,
    headers,
    body: bodyMin,
    timeoutMs: c.timeoutMs,
  })

  // Token invalid → refresh once
  if (res.status === 401 && String(res.data?.responseMessage || '').toLowerCase().includes('token')) {
    await getAccessToken(true)
    return callTransaction({ method, relativeUrl, body })
  }

  if (res.status < 200 || res.status >= 300) {
    const err = new Error(res.data?.responseMessage || `HTTP ${res.status}`)
    err.detail = res.data
    err.request = request
    err.httpStatus = res.status
    throw err
  }

  // BCA kadang HTTP 200 tapi business code 4xx/5xx
  const rc = String(res.data?.responseCode || '')
  if (/^[45]/.test(rc)) {
    let msg = res.data?.responseMessage || rc
    if (/Unknown client/i.test(msg)) {
      msg +=
        ' → Cek header CHANNEL-ID & X-PARTNER-ID (harus sesuai yang didaftarkan BCA; untuk merchant single-branch biasanya = MID).'
    } else if (/Signature/i.test(msg)) {
      msg += ' → Cek HMAC symmetric (Client Secret + minify JSON body).'
    }
    const err = new Error(msg)
    err.detail = res.data
    err.request = request
    err.httpStatus = res.status
    throw err
  }

  return {
    ...res.data,
    _exchange: {
      request,
      httpStatus: res.status,
      response: res.data,
    },
  }
}

/**
 * ECR Request Payment Purchase
 * Endpoint: POST /openapi/v1.0/ecr/payment
 * Body minimal (spec UAT): partnerReferenceNo, merchantId, terminalId, transType, additionalInfo.amount1
 * transType: 01 = Debit / Credit / QRIS Tap / Flazz Payment
 */
async function requestPurchase({
  amount,
  amount2,
  rewardFlag,
  partnerReferenceNo,
  merchantId,
  terminalId,
  transType,
}) {
  const c = cfg()
  // partnerReferenceNo wajib non-kosong (BCA 400RP02); generate jika tidak dikirim
  const requestRef =
    partnerReferenceNo != null && String(partnerReferenceNo).trim() !== ''
      ? String(partnerReferenceNo).trim()
      : generatePartnerRef()
  const additionalInfo = {
    amount1: formatAmount(amount),
  }
  if (amount2 !== undefined && amount2 !== null && String(amount2) !== '') {
    additionalInfo.amount2 = formatAmount(amount2)
  }
  if (rewardFlag !== undefined && rewardFlag !== null && String(rewardFlag) !== '') {
    additionalInfo.rewardFlag = String(rewardFlag)
  }

  const body = {
    partnerReferenceNo: requestRef,
    merchantId: merchantId || c.merchantId,
    terminalId: terminalId || c.terminalId,
    transType: transType || '01',
    additionalInfo,
  }

  const data = await callTransaction({
    method: 'POST',
    relativeUrl: '/openapi/v1.0/ecr/payment',
    body,
  })

  const exchange = data._exchange || null
  delete data._exchange
  const resolvedRef = String(
    data.partnerReferenceNo || data.originalPartnerReferenceNo || requestRef || ''
  ).trim()

  return {
    ...data,
    partnerReferenceNo: resolvedRef,
    merchantId: body.merchantId,
    terminalId: body.terminalId,
    method: 'ECR_PURCHASE',
    transType: body.transType,
    _exchange: exchange,
  }
}

/**
 * ECR Request Payment QRIS (dinamis)
 * Endpoint: POST /openapi/v1.0/ecr/payment
 * Body minimal seperti Purchase; transType 31 (default) — override dari MID_MASTER.QRIS_CODE
 */
async function requestQris({
  amount,
  amount2,
  rewardFlag,
  partnerReferenceNo,
  merchantId,
  terminalId,
  transType,
}) {
  const c = cfg()
  const requestRef =
    partnerReferenceNo != null && String(partnerReferenceNo).trim() !== ''
      ? String(partnerReferenceNo).trim()
      : generatePartnerRef()
  const additionalInfo = {
    amount1: formatAmount(amount),
  }
  if (amount2 !== undefined && amount2 !== null && String(amount2) !== '') {
    additionalInfo.amount2 = formatAmount(amount2)
  }
  if (rewardFlag !== undefined && rewardFlag !== null && String(rewardFlag) !== '') {
    additionalInfo.rewardFlag = String(rewardFlag)
  }

  const body = {
    partnerReferenceNo: requestRef,
    merchantId: merchantId || c.merchantId,
    terminalId: terminalId || c.terminalId,
    transType: transType || '31',
    additionalInfo,
  }

  const data = await callTransaction({
    method: 'POST',
    relativeUrl: '/openapi/v1.0/ecr/payment',
    body,
  })

  const exchange = data._exchange || null
  delete data._exchange
  const resolvedRef = String(
    data.partnerReferenceNo || data.originalPartnerReferenceNo || requestRef || ''
  ).trim()

  return {
    ...data,
    partnerReferenceNo: resolvedRef,
    merchantId: body.merchantId,
    terminalId: body.terminalId,
    method: 'ECR_QRIS',
    transType: body.transType,
    _exchange: exchange,
  }
}

/**
 * Inquiry Status - POST /openapi/v1.0/ecr/inquiry-status · transType 42
 */
async function inquiryStatus({
  originalPartnerReferenceNo,
  merchantId,
  terminalId,
  transType,
}) {
  const c = cfg()
  if (!originalPartnerReferenceNo) throw new Error('originalPartnerReferenceNo wajib')

  const body = {
    merchantId: merchantId || c.merchantId,
    terminalId: terminalId || c.terminalId,
    transType: transType || '42',
    partnerType: '',
    originalPartnerReferenceNo,
  }

  return callTransaction({
    method: 'POST',
    relativeUrl: '/openapi/v1.0/ecr/inquiry-status',
    body,
  })
}

/** Sukses bisnis inquiry (bukan sekadar HTTP 200 / request in progress). */
function isInquiryBusinessSuccess(data) {
  if (!data) return false
  const rc = String(data.responseCode || '').trim()
  if (/^[45]/.test(rc)) return false
  // SNAP success biasanya 200xxxx
  if (/^200/.test(rc)) return true
  const status = String(
    data.latestTransactionStatus ||
      data.transactionStatus ||
      data.additionalInfo?.latestTransactionStatus ||
      data.additionalInfo?.transactionStatus ||
      ''
  ).trim()
  if (status === '00') return true
  const msg = String(data.responseMessage || '')
  return /success(ful)?/i.test(msg) && !/progress|pending|in progress/i.test(msg)
}

/**
 * Poll inquiry-status tiap intervalMs sampai sukses / timeout / shouldStop.
 */
async function waitInquirySuccess(params, { intervalMs, maxMs, onAttempt, shouldStop } = {}) {
  const c = cfg()
  const every = Number(intervalMs || c.inquiryIntervalMs || 5000)
  const limit = Number(maxMs || c.inquiryMaxMs || 180000)
  const started = Date.now()
  let attempt = 0
  let lastExchange = null

  await new Promise((r) => setTimeout(r, every))

  while (Date.now() - started < limit) {
    if (typeof shouldStop === 'function' && shouldStop()) {
      const err = new Error('Inquiry dibatalkan (worker stop)')
      err.exchange = lastExchange
      err.step = 'inquiry'
      throw err
    }

    attempt += 1
    try {
      const res = await inquiryStatus(params)
      lastExchange = res._exchange || null
      if (isInquiryBusinessSuccess(res)) {
        if (typeof onAttempt === 'function') {
          onAttempt({ attempt, ok: true, exchange: lastExchange, data: res })
        }
        return { ok: true, data: res, attempts: attempt, exchange: lastExchange }
      }

      const pendingMsg =
        res.responseMessage ||
        `Inquiry belum final (responseCode ${res.responseCode || '-'})`
      if (typeof onAttempt === 'function') {
        onAttempt({
          attempt,
          ok: false,
          message: pendingMsg,
          exchange: lastExchange,
          detail: res,
        })
      }
    } catch (err) {
      lastExchange =
        err.request
          ? { request: err.request, httpStatus: err.httpStatus, response: err.detail }
          : lastExchange
      if (typeof onAttempt === 'function') {
        onAttempt({
          attempt,
          ok: false,
          message: err.message,
          exchange: lastExchange,
          detail: err.detail || null,
        })
      }
    }

    const remain = limit - (Date.now() - started)
    if (remain <= 0) break
    await new Promise((r) => setTimeout(r, Math.min(every, remain)))
  }

  const err = new Error(
    `Inquiry timeout setelah ${Math.round((Date.now() - started) / 1000)}s · ${params.originalPartnerReferenceNo || '-'}`
  )
  err.exchange = lastExchange
  err.step = 'inquiry'
  err.pending = true
  throw err
}

/**
 * Void - transType 08
 */
async function requestVoid({ originalPartnerReferenceNo, partnerReferenceNo }) {
  const c = cfg()
  if (!originalPartnerReferenceNo) throw new Error('originalPartnerReferenceNo wajib')
  const ref = partnerReferenceNo || generatePartnerRef()

  const body = {
    partnerReferenceNo: ref,
    merchantId: c.merchantId,
    terminalId: c.terminalId,
    transType: '08',
    partnerType: '',
    additionalInfo: {
      originalPartnerReferenceNo,
    },
  }

  const data = await callTransaction({
    method: 'POST',
    relativeUrl: '/openapi/v1.0/ecr/payment',
    body,
  })

  return { ...data, partnerReferenceNo: ref }
}

module.exports = {
  isConfigured,
  getAccessToken,
  testSignature,
  requestPurchase,
  requestQris,
  inquiryStatus,
  waitInquirySuccess,
  isInquiryBusinessSuccess,
  requestVoid,
  generatePartnerRef,
  signAsymmetric,
  signSymmetric,
  timestampNow,
  cfg,
}
