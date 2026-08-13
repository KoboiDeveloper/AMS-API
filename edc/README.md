# AMS EDC Bridge (local, ITILPOS-style)

HTTP bridge for POS_React cashier EDC. Runs on **store PC** so it can read `MID_MASTER` from `.\SQLEXPRESS` and reach the EDC machine. **No Electron.**

## Quick start

```bash
cd edc
copy .env.example .env   # then fill SQL_TOKO_* + bank keys
npm install
npm start
```

Listens on `http://127.0.0.1:8787`

## Routes

| Method | Path | Same as ITILPOS |
|--------|------|-----------------|
| POST | `/api/payment/edc/start` | yes |
| POST | `/api/payment/edc/status` | yes |
| POST | `/api/payment/edc/cancel` | yes |
| GET | `/health` | — |

## Env (toko)

```env
SQL_PROFILE=toko
SQL_TOKO_SERVER=.\SQLEXPRESS
SQL_TOKO_DATABASE=NEW_POS
SQL_TOKO_USER=sa
SQL_TOKO_PASSWORD=...
SQL_TABLE_MID=dbo.MID_MASTER
SQL_TABLE_LOG=dbo.LOG_TIPE_BAYAR
```

MID / TID / SALE_CODE / QRIS_CODE come from `MID_MASTER` per bank.

## POS_React

In POS_React `.env`:

```env
REACT_APP_EDC_API_BASE_URL=http://127.0.0.1:8787
```

Cloud/Render Go API is **not** used for EDC start/status/cancel on cashier.
