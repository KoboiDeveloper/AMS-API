const sql = require('mssql')

let pool = null
let midCache = null

const PROFILE_KEYS = {
  toko: {
    SERVER: 'SQL_TOKO_SERVER',
    PORT: 'SQL_TOKO_PORT',
    DATABASE: 'SQL_TOKO_DATABASE',
    USER: 'SQL_TOKO_USER',
    PASSWORD: 'SQL_TOKO_PASSWORD',
    ENCRYPT: 'SQL_TOKO_ENCRYPT',
    TRUST_CERT: 'SQL_TOKO_TRUST_CERT',
  },
  lokal: {
    SERVER: 'SQL_LOKAL_SERVER',
    PORT: 'SQL_LOKAL_PORT',
    DATABASE: 'SQL_LOKAL_DATABASE',
    USER: 'SQL_LOKAL_USER',
    PASSWORD: 'SQL_LOKAL_PASSWORD',
    ENCRYPT: 'SQL_LOKAL_ENCRYPT',
    TRUST_CERT: 'SQL_LOKAL_TRUST_CERT',
  },
}

const FALLBACK_KEYS = {
  SERVER: 'SQL_SERVER',
  PORT: 'SQL_PORT',
  DATABASE: 'SQL_DATABASE',
  USER: 'SQL_USER',
  PASSWORD: 'SQL_PASSWORD',
  ENCRYPT: 'SQL_ENCRYPT',
  TRUST_CERT: 'SQL_TRUST_CERT',
}

function normalizeProfile(raw) {
  const p = String(raw || '').toLowerCase().trim()
  return p === 'lokal' || p === 'local' ? 'lokal' : 'toko'
}

function getActiveProfile() {
  return normalizeProfile(process.env.SQL_PROFILE || 'toko')
}

function envVal(profile, key) {
  const specific = process.env[PROFILE_KEYS[profile]?.[key]]
  let raw =
    specific != null && String(specific).trim() !== ''
      ? String(specific).trim()
      : process.env[FALLBACK_KEYS[key]] != null
        ? String(process.env[FALLBACK_KEYS[key]]).trim()
        : ''
  // Strip accidental surrounding quotes from .env
  if (
    (raw.startsWith('"') && raw.endsWith('"')) ||
    (raw.startsWith("'") && raw.endsWith("'"))
  ) {
    raw = raw.slice(1, -1)
  }
  return raw
}

function getConfig() {
  const profile = getActiveProfile()
  const server = (envVal(profile, 'SERVER') || 'localhost').trim()
  // Named instance (.\SQLEXPRESS / HOST\INSTANCE) → jangan set port
  const isNamedInstance = server.includes('\\')
  const portRaw = envVal(profile, 'PORT')
  const port = portRaw ? Number(portRaw) : NaN

  const cfg = {
    server,
    database: envVal(profile, 'DATABASE') || '',
    user: envVal(profile, 'USER') || '',
    password: envVal(profile, 'PASSWORD') || '',
    options: {
      encrypt: String(envVal(profile, 'ENCRYPT') || 'false') === 'true',
      trustServerCertificate: String(envVal(profile, 'TRUST_CERT') || 'true') === 'true',
      enableArithAbort: true,
      ...(isNamedInstance ? { instanceName: server.split('\\').pop() } : {}),
    },
    connectionTimeout: 8000,
    requestTimeout: 15000,
  }

  // Hanya pakai port untuk default instance (bukan HOST\INSTANCE)
  if (!isNamedInstance && Number.isFinite(port) && port > 0) {
    cfg.port = port
  } else if (!isNamedInstance) {
    cfg.port = 1433
  }

  // mssql: untuk named instance, server harus hostname saja + options.instanceName
  if (isNamedInstance) {
    const host = server.split('\\')[0]
    cfg.server = host === '.' || host === '(local)' ? 'localhost' : host
  }

  return cfg
}

function tableLog() {
  return (process.env.SQL_TABLE_LOG || 'dbo.LOG_TIPE_BAYAR').trim()
}

function splitTable(full) {
  const raw = String(full || 'dbo.LOG_TIPE_BAYAR').replace(/[\[\]]/g, '')
  const parts = raw.split('.')
  if (parts.length >= 2) return { schema: parts[0], name: parts.slice(1).join('.') }
  return { schema: 'dbo', name: raw }
}

const ECR_COL = 'ECR_TRANS_ID'

let ecrColExists = undefined

async function hasEcrColumn() {
  if (ecrColExists !== undefined) return ecrColExists
  try {
    const { schema, name } = splitTable(tableLog())
    const p = await getPool()
    const result = await p
      .request()
      .input('schema', sql.NVarChar, schema)
      .input('name', sql.NVarChar, name)
      .input('col', sql.NVarChar, ECR_COL)
      .query(`
        SELECT 1 AS ok
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @name AND COLUMN_NAME = @col
      `)
    ecrColExists = Boolean(result.recordset?.[0])
  } catch {
    ecrColExists = false
  }
  return ecrColExists
}

function tableMid() {
  return (process.env.SQL_TABLE_MID || 'dbo.MID_MASTER').trim()
}

async function getPool() {
  if (pool && pool.connected) return pool
  pool = await sql.connect(getConfig())
  return pool
}

async function closePool() {
  if (!pool) {
    midCache = null
    return
  }
  try {
    await pool.close()
  } catch {
    /* ignore */
  }
  pool = null
  midCache = null
}

function getProfileInfo() {
  const profile = getActiveProfile()
  const cfg = getConfig()
  return {
    profile,
    canSwitch: String(process.env.SQL_PROFILE_LOCKED || '') !== '1',
    server: cfg.server,
    port: cfg.port || null,
    database: cfg.database,
    tableLog: tableLog(),
    tableMid: tableMid(),
    configured: Boolean(cfg.server && cfg.database),
  }
}

function setActiveProfile(next) {
  const profile = normalizeProfile(next)
  process.env.SQL_PROFILE = profile
  return getProfileInfo()
}

async function ping() {
  const cfg = getConfig()
  if (!cfg.database) {
    return { ok: false, message: 'SQL_DATABASE belum diisi di .env' }
  }
  try {
    const p = await getPool()
    const result = await p.request().query('SELECT 1 AS ok')
    return {
      ok: true,
      message: 'Connected',
      server: cfg.server,
      database: cfg.database,
      tableLog: tableLog(),
      tableMid: tableMid(),
      result: result.recordset?.[0] || null,
    }
  } catch (err) {
    return { ok: false, message: err.message }
  }
}

function normalizeBankKey(bank) {
  const b = String(bank || '')
    .trim()
    .toUpperCase()
  if (b === 'MANDIRI' || b === 'MDR' || b === 'YOKKE') return 'MDR'
  if (b === 'BNI' || b === 'BANK BNI') return 'BNI'
  if (b === 'BCA') return 'BCA'
  if (b === 'BRI') return 'BRI'
  return b
}

/**
 * Load MID_MASTER once. STORE comes from DB (single-store POS).
 * Returns { storeId, banks: { BCA: {mid,tid,saleCode,qrisCode}, ... }, warning }
 */
async function loadMidMaster({ force = false } = {}) {
  if (midCache && !force) return midCache

  const p = await getPool()
  const q = `
    SELECT STORE, BANK, MID, TID, SALE_CODE, QRIS_CODE
    FROM ${tableMid()}
  `
  const result = await p.request().query(q)
  const rows = result.recordset || []
  if (!rows.length) {
    throw new Error(`MID_MASTER kosong (${tableMid()})`)
  }

  const stores = [...new Set(rows.map((r) => String(r.STORE ?? '').trim()).filter(Boolean))]
  let warning = null
  if (stores.length === 0) {
    throw new Error('MID_MASTER tidak punya nilai STORE')
  }
  if (stores.length > 1) {
    warning = `MID_MASTER punya ${stores.length} STORE (${stores.join(', ')}); memakai ${stores[0]}`
  }
  const storeId = stores[0]

  const banks = {}
  for (const row of rows) {
    const store = String(row.STORE ?? '').trim()
    if (store !== storeId) continue
    const key = normalizeBankKey(row.BANK)
    if (!key) continue
    banks[key] = {
      bank: key,
      mid: String(row.MID ?? '').trim(),
      tid: String(row.TID ?? '').trim(),
      saleCode: String(row.SALE_CODE ?? '').trim(),
      qrisCode: String(row.QRIS_CODE ?? '').trim(),
      store: storeId,
    }
  }

  midCache = { storeId, storeIds: stores, banks, warning, loadedAt: Date.now() }
  return midCache
}

function getMidCache() {
  return midCache
}

function clearMidCache() {
  midCache = null
}

/**
 * Ambil 1 antrian pembayaran STATUS_TRANS = NEW untuk store ini.
 */
async function fetchNextLog(storeId, storeIds) {
  const stores = (Array.isArray(storeIds) && storeIds.length ? storeIds : [storeId])
    .map((s) => String(s || '').trim())
    .filter(Boolean)
  if (!stores.length) throw new Error('storeId wajib untuk fetchNextLog')
  const p = await getPool()
  const req = p.request()
  const inList = stores
    .map((name, i) => {
      req.input(`s${i}`, sql.NVarChar, name)
      return `UPPER(LTRIM(RTRIM(@s${i})))`
    })
    .join(', ')
  const result = await req.query(`
      SELECT TOP (1) *
      FROM ${tableLog()}
      WHERE UPPER(LTRIM(RTRIM(STORE))) IN (${inList})
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
    `)
  const row = result.recordset?.[0]
  if (!row) return null
  const ecrId = String(row.ECR_TRANS_ID ?? row.ecr_trans_id ?? '').trim()
  return {
    store: String(row.STORE ?? '').trim(),
    bank: String(row.BANK ?? '').trim(),
    tipeBayar: String(row.TIPE_BAYAR ?? '').trim(),
    nominal: Number(row.NOMINAL),
    statusTrans: String(row.STATUS_TRANS ?? '').trim(),
    merchantEcrTransID: ecrId,
  }
}

/**
 * UPDATE row NEW yang sudah ada — SET ECR_TRANS_ID.
 * Tidak pernah INSERT record baru.
 */
async function saveEcrTransId(row, ecrId) {
  if (!row || !ecrId) return { ok: false, rowsAffected: 0, message: 'row / ECR id kosong' }
  if (!(await hasEcrColumn())) {
    return {
      ok: false,
      rowsAffected: 0,
      message: `Kolom ${ECR_COL} tidak ada di ${tableLog()} — hanya UPDATE, tidak insert`,
    }
  }

  const p = await getPool()
  const req = p
    .request()
    .input('store', sql.NVarChar, String(row.store))
    .input('bank', sql.NVarChar, String(row.bank))
    .input('tipe', sql.NVarChar, String(row.tipeBayar))
    .input('nominal', sql.Float, Number(row.nominal))
    .input('ecrId', sql.NVarChar, String(ecrId).slice(0, 40))

  const result = await req.query(`
    UPDATE TOP (1) ${tableLog()}
    SET ${ECR_COL} = @ecrId
    WHERE STORE = @store
      AND BANK = @bank
      AND TIPE_BAYAR = @tipe
      AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
      AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
  `)
  let rows = result.rowsAffected?.[0] || 0

  // Fallback: BANK di tabel kadang MANDIRI vs MDR
  if (!rows) {
    const aliases = bankAliases(row.bank)
    const req2 = p
      .request()
      .input('store', sql.NVarChar, String(row.store))
      .input('tipe', sql.NVarChar, String(row.tipeBayar))
      .input('nominal', sql.Float, Number(row.nominal))
      .input('ecrId', sql.NVarChar, String(ecrId).slice(0, 40))
    const inList = aliases
      .map((alias, i) => {
        req2.input(`b${i}`, sql.NVarChar, alias)
        return `@b${i}`
      })
      .join(', ')
    const result2 = await req2.query(`
      UPDATE TOP (1) ${tableLog()}
      SET ${ECR_COL} = @ecrId
      WHERE STORE = @store
        AND UPPER(LTRIM(RTRIM(BANK))) IN (${inList})
        AND TIPE_BAYAR = @tipe
        AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
    `)
    rows = result2.rowsAffected?.[0] || 0
  }

  if (!rows) {
    const aliases = bankAliases(row.bank)
    const req3 = p
      .request()
      .input('store', sql.NVarChar, String(row.store))
      .input('nominal', sql.Float, Number(row.nominal))
      .input('ecrId', sql.NVarChar, String(ecrId).slice(0, 40))
    const inList = aliases
      .map((alias, i) => {
        req3.input(`b${i}`, sql.NVarChar, alias)
        return `@b${i}`
      })
      .join(', ')
    const result3 = await req3.query(`
      UPDATE TOP (1) ${tableLog()}
      SET ${ECR_COL} = @ecrId
      WHERE STORE = @store
        AND UPPER(LTRIM(RTRIM(BANK))) IN (${inList})
        AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
    `)
    rows = result3.rowsAffected?.[0] || 0
  }

  return {
    ok: rows > 0,
    rowsAffected: rows,
    column: ECR_COL,
    inserted: false,
    ecrId: rows > 0 ? String(ecrId).trim() : '',
    message:
      rows > 0
        ? `UPDATE ${ECR_COL}=${ecrId}`
        : `UPDATE 0 row — tidak insert. Cek STORE/BANK/TIPE/NOMINAL NEW`,
  }
}

/** Baca ECR_TRANS_ID dari row NEW yang sudah ada. Kosong = jangan inquiry. */
async function readEcrTransId(row) {
  if (!(await hasEcrColumn()) || !row) return { ok: false, ecrId: '' }
  const p = await getPool()
  const aliases = bankAliases(row.bank || 'MDR')
  const req = p
    .request()
    .input('store', sql.NVarChar, String(row.store || ''))
    .input('tipe', sql.NVarChar, String(row.tipeBayar || ''))
    .input('nominal', sql.Float, Number(row.nominal))
  const inList = aliases
    .map((alias, i) => {
      req.input(`b${i}`, sql.NVarChar, alias)
      return `@b${i}`
    })
    .join(', ')
  const tipeClause = row.tipeBayar
    ? 'AND TIPE_BAYAR = @tipe'
    : ''
  const result = await req.query(`
    SELECT TOP (1) ${ECR_COL} AS ecrId
    FROM ${tableLog()}
    WHERE STORE = @store
      AND UPPER(LTRIM(RTRIM(BANK))) IN (${inList})
      ${tipeClause}
      AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
      AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
      AND ${ECR_COL} IS NOT NULL
      AND LTRIM(RTRIM(${ECR_COL})) <> ''
  `)
  const ecrId = String(result.recordset?.[0]?.ecrId || '').trim()
  return { ok: Boolean(ecrId), ecrId, column: ECR_COL }
}

async function findEcrTransId({ amount, bankKey, preferQris } = {}) {
  const master = await loadMidMaster()
  return readEcrTransId({
    store: master.storeId,
    bank: bankKey || 'MDR',
    tipeBayar: preferQris ? undefined : undefined,
    nominal: amount,
  })
}

/**
 * Update STATUS_TRANS (NEW → SUCCESS / FAILED). Tidak delete row.
 */
async function updateLogStatus(row, status) {
  if (!row) throw new Error('row wajib')
  const next = String(status || '').trim().toUpperCase()
  if (next !== 'SUCCESS' && next !== 'FAILED') {
    throw new Error(`STATUS_TRANS tidak valid: ${status}`)
  }
  const p = await getPool()
  const result = await p
    .request()
    .input('store', sql.NVarChar, String(row.store))
    .input('bank', sql.NVarChar, String(row.bank))
    .input('tipe', sql.NVarChar, String(row.tipeBayar))
    .input('nominal', sql.Float, Number(row.nominal))
    .input('status', sql.NVarChar, next)
    .query(`
      UPDATE TOP (1) ${tableLog()}
      SET STATUS_TRANS = @status
      WHERE STORE = @store
        AND BANK = @bank
        AND TIPE_BAYAR = @tipe
        AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
    `)
  let rows = result.rowsAffected?.[0] || 0

  if (!rows) {
    const aliases = bankAliases(row.bank)
    const req2 = p
      .request()
      .input('store', sql.NVarChar, String(row.store))
      .input('nominal', sql.Float, Number(row.nominal))
      .input('status', sql.NVarChar, next)
    const inList = aliases
      .map((alias, i) => {
        req2.input(`b${i}`, sql.NVarChar, alias)
        return `@b${i}`
      })
      .join(', ')
    const result2 = await req2.query(`
      UPDATE TOP (1) ${tableLog()}
      SET STATUS_TRANS = @status
      WHERE STORE = @store
        AND UPPER(LTRIM(RTRIM(BANK))) IN (${inList})
        AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
    `)
    rows = result2.rowsAffected?.[0] || 0
  }

  const ecrId = String(row.merchantEcrTransID || '').trim()
  if (!rows && ecrId && (await hasEcrColumn())) {
    const result3 = await p
      .request()
      .input('store', sql.NVarChar, String(row.store))
      .input('ecrId', sql.NVarChar, ecrId)
      .input('status', sql.NVarChar, next)
      .query(`
        UPDATE TOP (1) ${tableLog()}
        SET STATUS_TRANS = @status
        WHERE STORE = @store
          AND LTRIM(RTRIM(${ECR_COL})) = @ecrId
          AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
      `)
    rows = result3.rowsAffected?.[0] || 0
  }

  return { ok: rows > 0, rowsAffected: rows, status: next }
}

function bankAliases(bankKey) {
  const key = normalizeBankKey(bankKey)
  if (key === 'MDR') return ['MDR', 'MANDIRI', 'YOKKE', 'BANK MANDIRI']
  if (key === 'BNI') return ['BNI', 'BANK BNI']
  if (key === 'BCA') return ['BCA', 'BANK BCA']
  if (key === 'BRI') return ['BRI', 'BANK BRI']
  return [String(bankKey || '').trim().toUpperCase()].filter(Boolean)
}

/**
 * UPDATE STATUS_TRANS pada row NEW yang sudah ada (SUCCESS / FAILED). Bukan INSERT.
 */
async function markLogOutcome({ bankKey, amount, preferQris, status } = {}) {
  const next = String(status || 'SUCCESS').trim().toUpperCase()
  if (next !== 'SUCCESS' && next !== 'FAILED') {
    return { ok: false, rowsAffected: 0, message: `STATUS_TRANS tidak valid: ${status}` }
  }
  const master = await loadMidMaster()
  const storeId = master.storeId
  const amt = Number(amount)
  if (!storeId) {
    return { ok: false, rowsAffected: 0, message: 'STORE dari MID_MASTER kosong' }
  }
  if (!Number.isFinite(amt) || amt <= 0) {
    return { ok: false, rowsAffected: 0, message: `Nominal tidak valid: ${amount}` }
  }

  const aliases = bankAliases(bankKey || 'MDR')
  const p = await getPool()

  async function run(qrisOnly) {
    const req = p
      .request()
      .input('store', sql.NVarChar, storeId)
      .input('nominal', sql.Float, amt)
      .input('status', sql.NVarChar, next)
    const inList = aliases
      .map((alias, i) => {
        req.input(`b${i}`, sql.NVarChar, alias)
        return `@b${i}`
      })
      .join(', ')
    const qrisClause = qrisOnly ? `AND UPPER(LTRIM(RTRIM(TIPE_BAYAR))) LIKE '%QRIS%'` : ''
    return req.query(`
      UPDATE TOP (1) ${tableLog()}
      SET STATUS_TRANS = @status
      WHERE STORE = @store
        AND UPPER(LTRIM(RTRIM(STATUS_TRANS))) = 'NEW'
        AND UPPER(LTRIM(RTRIM(BANK))) IN (${inList})
        AND ABS(CAST(NOMINAL AS FLOAT) - @nominal) < 0.05
        ${qrisClause}
    `)
  }

  let result = preferQris ? await run(true) : await run(false)
  let rows = result.rowsAffected?.[0] || 0
  if (!rows && preferQris) {
    result = await run(false)
    rows = result.rowsAffected?.[0] || 0
  }

  return {
    ok: rows > 0,
    rowsAffected: rows,
    storeId,
    amount: amt,
    status: next,
    message: rows
      ? `STATUS_TRANS=${next} · STORE ${storeId} · Rp ${amt}`
      : `UPDATE 0 row NEW ${aliases.join('/')} Rp ${amt} di STORE ${storeId}`,
  }
}

function markLogSuccess(opts) {
  return markLogOutcome({ ...opts, status: 'SUCCESS' })
}

function markLogFailed(opts) {
  return markLogOutcome({ ...opts, status: 'FAILED' })
}

function normalizeStatusTrans(value) {
  return String(value || '').trim().toUpperCase()
}

function isPosStoppedStatus(statusTrans) {
  const st = normalizeStatusTrans(statusTrans)
  return st === 'CANCEL' || st === 'SUCCESS' || st === 'FAILED'
}

/**
 * Baca STATUS_TRANS by ECR_TRANS_ID (semua status, termasuk CANCEL dari POS).
 */
async function readStatusByEcrTransId(ecrId) {
  const id = String(ecrId || '').trim()
  if (!id) return { ok: false, ecrId: '', statusTrans: '' }
  if (!(await hasEcrColumn())) {
    return { ok: false, ecrId: id, statusTrans: '', message: `Kolom ${ECR_COL} tidak ada` }
  }
  const p = await getPool()
  const result = await p
    .request()
    .input('ecrId', sql.NVarChar, id)
    .query(`
      SELECT TOP (1) STATUS_TRANS AS statusTrans, ${ECR_COL} AS ecrId
      FROM ${tableLog()}
      WHERE LTRIM(RTRIM(${ECR_COL})) = @ecrId
    `)
  const rec = result.recordset?.[0]
  const statusTrans = normalizeStatusTrans(rec?.statusTrans)
  return {
    ok: Boolean(rec),
    ecrId: String(rec?.ecrId || id).trim(),
    statusTrans,
    cancelled: statusTrans === 'CANCEL',
    stopped: isPosStoppedStatus(statusTrans),
  }
}

module.exports = {
  ping,
  getConfig,
  getPool,
  closePool,
  getActiveProfile,
  getProfileInfo,
  setActiveProfile,
  normalizeProfile,
  loadMidMaster,
  getMidCache,
  clearMidCache,
  fetchNextLog,
  updateLogStatus,
  saveEcrTransId,
  readEcrTransId,
  findEcrTransId,
  readStatusByEcrTransId,
  isPosStoppedStatus,
  markLogSuccess,
  markLogFailed,
  markLogOutcome,
  normalizeBankKey,
  tableLog,
  tableMid,
}
