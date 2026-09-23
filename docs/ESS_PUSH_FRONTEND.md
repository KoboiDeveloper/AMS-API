# ESS Push Notification — Panduan Frontend

Konteks untuk tim frontend (termasuk Cursor). Semua path di bawah prefix `/api/v1/ess` dan **wajib JWT**.

```
Authorization: Bearer <token login ESS>
Content-Type: application/json
```

NIK diambil dari JWT (`userId`). Tidak perlu kirim `nik` kecuali testing.

Envelope backend:

```json
{ "responseCode": "2002500", "responseMessage": "ok", "data": {} }
```

Sukses: `responseCode` diawali `200` atau `00`. Jangan pakai `{ status: true }`.

---

## Dua saluran, dua UI

| Saluran | Kapan | Tugas frontend |
|---|---|---|
| **Drawer / bell** | `GET /notifications` | Histori di header. Selalu ada meski user menolak izin browser. |
| **Web Push** | OS/browser toast | Hanya setelah user izinkan notifikasi + `subscribe` sukses. |

Backend sudah mengirim **email + push** sendiri saat izin/cuti/lembur create / approve / delete. Frontend tidak perlu trigger event itu.

---

## Alur yang harus diimplementasi

```
Login sukses
  → GET /notifications (isi drawer + badge unread_count)
  → minta izin Notification
      → GET /notifications/vapid-public-key
      → PushManager.subscribe(applicationServerKey)
      → POST /notifications/subscribe
Logout / user matikan notifikasi
  → POST /notifications/unsubscribe
Klik item drawer
  → PUT /notifications/:id/read
  → router.push(target_url)
Klik "tandai semua dibaca"
  → PUT /notifications/read-all
Klik toast Web Push
  → Service Worker baca payload.notification.data.url → buka tab itu
```

---

## Endpoint

Base: `/api/v1/ess`

| Method | Path | Fungsi |
|---|---|---|
| GET | `/notifications/vapid-public-key` | Public key VAPID untuk `PushManager.subscribe` |
| POST | `/notifications/subscribe` | Daftar / update subscription browser |
| POST | `/notifications/unsubscribe` | Hapus subscription (logout / izin dimatikan) |
| GET | `/notifications?page&limit&unread_only` | Histori drawer + `unread_count` |
| PUT | `/notifications/read-all` | Tandai semua dibaca |
| PUT | `/notifications/{id}/read` | Tandai satu item dibaca |

---

## 1. `GET /notifications/vapid-public-key`

Ambil public key VAPID untuk `PushManager.subscribe`. **Jangan hardcode** key di repo.

Response:

```json
{
  "responseCode": "2002500",
  "responseMessage": "ok",
  "data": {
    "publicKey": "BNxxxx..."
  }
}
```

`publicKey` adalah **base64 URL-safe**. Harus diubah ke `Uint8Array` sebelum subscribe.

```ts
function urlBase64ToUint8Array(base64: string) {
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const raw = atob((base64 + padding).replace(/-/g, "+").replace(/_/g, "/"));
  return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)));
}
```

Kalau `responseCode` = `5000003` → env `VAPID_PUBLIC_KEY` belum di-set di API. Drawer tetap boleh jalan; toast browser tidak.

---

## 2. `POST /notifications/subscribe`

Daftar device/browser user. Panggil **setelah** `PushManager.subscribe` berhasil, biasanya sekali per login/device (idempotent: endpoint sama → update).

Body:

```json
{
  "endpoint": "https://fcm.googleapis.com/fcm/send/....",
  "keys": {
    "p256dh": "BNcRdreHz...",
    "auth": "tBHx..."
  }
}
```

Contoh:

```ts
const reg = await navigator.serviceWorker.register("/sw.js");
const { data } = await api.get("/notifications/vapid-public-key");
const sub = await reg.pushManager.subscribe({
  userVisibleOnly: true,
  applicationServerKey: urlBase64ToUint8Array(data.publicKey),
});
const json = sub.toJSON();
await api.post("/notifications/subscribe", {
  endpoint: json.endpoint,
  keys: { p256dh: json.keys.p256dh, auth: json.keys.auth },
});
```

Simpan `endpoint` di `localStorage` supaya logout bisa unsubscribe.

---

## 3. `POST /notifications/unsubscribe`

Hapus langganan saat logout atau user mematikan izin.

```json
{
  "endpoint": "https://fcm.googleapis.com/fcm/send/...."
}
```

Juga panggil `registration.pushManager.getSubscription()?.unsubscribe()`.

---

## 4. `GET /notifications?page=1&limit=20&unread_only=false`

Isi Notification Drawer + badge.

| Query | Default | Keterangan |
|---|---|---|
| `page` | 1 | 1-based |
| `limit` | 20 | max 100 |
| `unread_only` | false | `true` / `1` = hanya belum dibaca |

Response `data`:

```json
{
  "unread_count": 3,
  "items": [
    {
      "id": 101,
      "category": "APPROVAL",
      "title": "Pengajuan Cuti Disetujui ✅",
      "body": "Pengajuan Cuti Tahunan Anda telah disetujui.",
      "target_url": "/dashboard/cuti",
      "is_read": false,
      "created_at": "2026-09-23T08:30:00",
      "metadata": { "id": "12", "type": "CUTI", "action": "APPROVED" }
    }
  ]
}
```

- Badge header = `unread_count` (total unread, bukan hanya halaman ini).
- Klik item → `router.push(item.target_url)` lalu `PUT /notifications/{id}/read`.
- Poll drawer tiap 30–60 detik, atau refresh saat window focus. Jangan andalkan Web Push saja (iOS / izin ditolak).

### `target_url` dari backend

| Event | Penerima | `target_url` |
|---|---|---|
| Pengajuan izin baru / batal | Atasan | `/dashboard/approval/izin` |
| Pengajuan cuti baru / batal | Atasan | `/dashboard/approval/cuti` |
| Pengajuan lembur baru / batal | Atasan | `/dashboard/approval/lembur` |
| Izin approve/reject | Pengaju | `/dashboard/izin` |
| Cuti approve/reject | Pengaju | `/dashboard/cuti` |
| Lembur approve/reject | Pengaju | `/dashboard/lembur` |

Pastikan route Next/React sama. Kalau beda, mapping di frontend.

`metadata.action`: `NEW` \| `APPROVED` \| `REJECTED` \| `CANCELLED`  
`metadata.type`: `IZIN` \| `CUTI` \| `LEMBUR`

---

## 5. `PUT /notifications/:id/read`

Tandai 1 item dibaca. Optimistic update `is_read` + `unread_count - 1`.

---

## 6. `PUT /notifications/read-all`

Tandai semua milik user. Badge → 0.

---

## Service Worker (wajib untuk toast)

Backend menembakkan payload ini. `sw.js` harus baca **bentuk ini**.

```json
{
  "notification": {
    "title": "Pengajuan Cuti Baru",
    "body": "Ahmad Fauzi mengajukan cuti 3 hari. Perlu review Anda.",
    "icon": "/icons/icon-192x192.png",
    "badge": "/icons/badge-72x72.png",
    "tag": "new-cuti-12",
    "renotify": true,
    "vibrate": [100, 50, 100],
    "data": {
      "url": "/dashboard/approval/cuti",
      "id": 101,
      "category": "APPROVAL"
    }
  }
}
```

```js
// sw.js
self.addEventListener("push", (event) => {
  const payload = event.data?.json() ?? {};
  const n = payload.notification ?? payload;
  event.waitUntil(
    self.registration.showNotification(n.title || "AMS ESS", {
      body: n.body,
      icon: n.icon,
      badge: n.badge,
      tag: n.tag,
      renotify: n.renotify,
      data: n.data,
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = event.notification.data?.url || "/dashboard";
  event.waitUntil(clients.openWindow(url));
});
```

Sediakan `/icons/icon-192x192.png` dan `/icons/badge-72x72.png` (atau override di SW). HTTPS wajib (localhost OK).

---

## Checklist implementasi

1. Register `sw.js` setelah login.
2. Drawer memakai `GET /notifications`, bukan mock.
3. Subscribe hanya jika `Notification.permission === "granted"`.
4. Unsubscribe saat logout.
5. Klik item / toast → `target_url` / `data.url`.
6. Role 1313 vs atasan: backend yang pilih penerima. Frontend hanya tampilkan milik user login.
7. Jangan panggil API create/approve hanya untuk “kirim notif” — itu sudah di backend + email.

---

