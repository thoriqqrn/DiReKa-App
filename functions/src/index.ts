import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

const REGION = "asia-southeast2";
const FALLBACK_ADMIN_EMAILS = new Set(["admin@direka.app"]);
const AUDIT_COLLECTION = "admin_password_reset_audit";

type ResetPasswordPayload = {
  targetUid?: unknown;
  uid?: unknown;
  newPassword?: unknown;
  reason?: unknown;
};

function asNonEmptyString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function getAllowedAdminEmails(): Set<string> {
  const envValue = process.env.RESET_ADMIN_EMAILS ?? "";
  const extras = envValue
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  return new Set([
    ...Array.from(FALLBACK_ADMIN_EMAILS),
    ...extras,
  ]);
}

export const adminResetUserPassword = onCall<ResetPasswordPayload>(
  {
    region: REGION,
    cors: true,
  },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Harus login sebagai admin.");
    }

    const adminUid = auth.uid;
    const adminEmail = asNonEmptyString(auth.token.email).toLowerCase();
    const allowedAdminEmails = getAllowedAdminEmails();

    const adminDoc = await admin.firestore().collection("users").doc(adminUid).get();
    const adminData = adminDoc.data() ?? {};
    const hasAdminClaim =
      auth.token.role === "admin" || auth.token.admin === true;
    const hasAdminDocFlag =
      adminData["isAdmin"] === true || adminData["role"] === "admin";
    const hasAllowedAdminEmail = allowedAdminEmails.has(adminEmail);

    if (!hasAdminClaim && !hasAdminDocFlag && !hasAllowedAdminEmail) {
      throw new HttpsError(
        "permission-denied",
        "Akun ini tidak memiliki hak reset password admin."
      );
    }

    const raw = request.data ?? {};
    const targetUid =
      asNonEmptyString(raw.targetUid) || asNonEmptyString(raw.uid);
    const newPassword = asNonEmptyString(raw.newPassword);
    const reason =
      asNonEmptyString(raw.reason) || "Reset manual dari Admin App";

    if (!targetUid) {
      throw new HttpsError("invalid-argument", "targetUid wajib diisi.");
    }
    if (newPassword.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Password sementara minimal 6 karakter."
      );
    }
    if (targetUid === adminUid) {
      throw new HttpsError(
        "failed-precondition",
        "Admin tidak boleh reset password akun sendiri."
      );
    }

    let targetUserRecord: admin.auth.UserRecord;
    try {
      targetUserRecord = await admin.auth().getUser(targetUid);
    } catch (error) {
      logger.error("Failed to load target user before password reset", {
        targetUid,
        adminUid,
        error,
      });
      throw new HttpsError(
        "not-found",
        "User target tidak ditemukan di Firebase Authentication."
      );
    }
    const hasPasswordProvider = targetUserRecord.providerData.some(
      (provider) => provider.providerId === "password"
    );

    if (!hasPasswordProvider) {
      throw new HttpsError(
        "failed-precondition",
        "Akun target tidak menggunakan login email/password."
      );
    }

    await admin.auth().updateUser(targetUid, {
      password: newPassword,
    });

    await admin.firestore().collection(AUDIT_COLLECTION).add({
      action: "reset_password",
      targetUid,
      targetEmail: targetUserRecord.email ?? "",
      adminUid,
      adminEmail,
      reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      clientApp: "direka_admin_flutter",
      region: REGION,
    });

    logger.info("Admin password reset executed", {
      targetUid,
      adminUid,
      reason,
    });

    return {
      ok: true,
      targetUid,
      resetBy: adminUid,
      at: new Date().toISOString(),
      mustChangePassword: true,
    };
  }
);
