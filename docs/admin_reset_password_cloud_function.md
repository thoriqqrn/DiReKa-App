# Admin Reset Password Cloud Function

Nama endpoint callable:
- `adminResetUserPassword`

Tujuan:
- Admin app bisa reset password user menjadi password sementara.
- Semua aksi tercatat dalam audit log.

## Kontrak Request

Payload dari client (Admin App):

```json
{
  "targetUid": "uid-user-yang-direset",
  "newPassword": "123456",
  "reason": "Permintaan lupa kata sandi via WhatsApp Admin"
}
```

## Kontrak Response

Sukses:

```json
{
  "ok": true,
  "targetUid": "uid-user-yang-direset",
  "resetBy": "uid-admin",
  "at": "2026-04-30T12:00:00.000Z"
}
```

## Aturan Keamanan (wajib)

1. Hanya menerima request dari user yang sudah login (`context.auth != null`).
2. Verifikasi peran admin di server:
   - Disarankan pakai custom claim `role=admin`, atau
   - Firestore `users/{uid}.isAdmin == true`.
3. Tolak jika:
   - `targetUid` kosong.
   - `newPassword` < 6 karakter.
   - admin mencoba reset dirinya sendiri (opsional, untuk disiplin operasional).
4. Jangan pernah log plaintext password ke Firestore/console.
5. Simpan audit log immutable di koleksi khusus.

## Skema Audit Log

Collection:
- `admin_password_reset_audit`

Dokumen:

```json
{
  "action": "reset_password",
  "targetUid": "uid-user",
  "targetEmail": "user@mail.com",
  "adminUid": "uid-admin",
  "adminEmail": "admin@mail.com",
  "reason": "Permintaan lupa kata sandi via WhatsApp Admin",
  "createdAt": "<serverTimestamp>",
  "clientApp": "direka_admin_flutter"
}
```

## Contoh Implementasi (TypeScript / Firebase Functions v2)

```ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

export const adminResetUserPassword = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Harus login.");
  }

  const adminUid = auth.uid;
  const adminUserDoc = await admin.firestore().collection("users").doc(adminUid).get();
  const isAdmin = adminUserDoc.exists && adminUserDoc.data()?.isAdmin == true;

  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Hanya admin yang diizinkan.");
  }

  const targetUid = String(request.data?.targetUid ?? "").trim();
  const newPassword = String(request.data?.newPassword ?? "");
  const reason = String(request.data?.reason ?? "Reset manual dari Admin App").trim();

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid wajib diisi.");
  }
  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password minimal 6 karakter.");
  }
  if (targetUid === adminUid) {
    throw new HttpsError("failed-precondition", "Tidak boleh reset password akun sendiri.");
  }

  const targetUser = await admin.auth().getUser(targetUid);
  await admin.auth().updateUser(targetUid, { password: newPassword });

  await admin.firestore().collection("admin_password_reset_audit").add({
    action: "reset_password",
    targetUid,
    targetEmail: targetUser.email ?? "",
    adminUid,
    adminEmail: auth.token.email ?? "",
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    clientApp: "direka_admin_flutter",
  });

  return {
    ok: true,
    targetUid,
    resetBy: adminUid,
    at: new Date().toISOString(),
  };
});
```

## Catatan Operasional

1. Setelah reset, admin wajib meminta user segera ganti password dari menu:
   - `Pengaturan > Ubah Kata Sandi`.
2. Disarankan batasi akses endpoint menggunakan App Check untuk menekan abuse dari client tidak resmi.
