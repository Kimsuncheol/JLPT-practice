import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {NotificationJobInput, parseNotificationJob} from "./job";

initializeApp();

const db = getFirestore();
const MAX_TOKENS_PER_SEND = 500;
const MAX_ATTEMPTS = 3;
const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

export const deleteAccount = onCall(
  {enforceAppCheck: true, timeoutSeconds: 120},
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Sign in before deleting an account.");
    }

    try {
      await db.recursiveDelete(db.collection("users").doc(userId));
      await getAuth().deleteUser(userId);
      logger.info("Deleted user account and synchronized data", {userId});
      return {deleted: true};
    } catch (error) {
      logger.error("Account deletion failed", {userId, error});
      throw new HttpsError("internal", "The account could not be deleted.");
    }
  },
);

interface MessagingFailure {
  code?: string;
}

export const deliverNotificationJob = onDocumentCreated(
  {document: "notificationJobs/{jobId}", retry: true, timeoutSeconds: 540},
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    let job: NotificationJobInput;
    try {
      job = parseNotificationJob(snapshot.data());
    } catch (error) {
      await snapshot.ref.set({
        status: "failed",
        error: error instanceof Error ? error.message : "Invalid job",
        completedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.warn("Rejected invalid notification job", {jobId: event.params.jobId});
      return;
    }

    const attempt = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(snapshot.ref);
      if (current.get("status") !== "queued") return 0;
      const nextAttempt = (current.get("attemptCount") ?? 0) + 1;
      transaction.update(snapshot.ref, {
        status: "processing",
        startedAt: FieldValue.serverTimestamp(),
        attemptCount: nextAttempt,
      });
      return nextAttempt;
    });
    if (attempt === 0) return;

    try {
      const devices = await db.collection("users").doc(job.targetUserId)
        .collection("devices").where("enabled", "==", true).get();
      const validDevices = devices.docs.filter((doc) => {
        const token = doc.get("token");
        return typeof token === "string" && token.length >= 20;
      });

      let successCount = 0;
      let failureCount = 0;
      let invalidTokensRemoved = 0;
      for (let offset = 0; offset < validDevices.length; offset += MAX_TOKENS_PER_SEND) {
        const chunk = validDevices.slice(offset, offset + MAX_TOKENS_PER_SEND);
        const response = await getMessaging().sendEachForMulticast({
          tokens: chunk.map((doc) => doc.get("token") as string),
          notification: {title: job.title, body: job.body},
          data: {...job.data, notificationJobId: event.params.jobId},
          android: {
            priority: "normal",
            collapseKey: event.params.jobId.slice(0, 64),
          },
          apns: {
            headers: {"apns-collapse-id": event.params.jobId.slice(0, 64)},
          },
        });
        successCount += response.successCount;
        failureCount += response.failureCount;

        const invalidRefs = response.responses.flatMap((result, index) => {
          const code = (result.error as MessagingFailure | undefined)?.code;
          return code && INVALID_TOKEN_CODES.has(code) ? [chunk[index].ref] : [];
        });
        if (invalidRefs.length > 0) {
          const batch = db.batch();
          invalidRefs.forEach((ref) => batch.delete(ref));
          await batch.commit();
          invalidTokensRemoved += invalidRefs.length;
        }
      }

      await snapshot.ref.set({
        status: "completed",
        completedAt: FieldValue.serverTimestamp(),
        result: {
          targetedDevices: validDevices.length,
          successCount,
          failureCount,
          invalidTokensRemoved,
        },
      }, {merge: true});
      logger.info("Notification job completed", {
        jobId: event.params.jobId,
        targetedDevices: validDevices.length,
        successCount,
        failureCount,
        invalidTokensRemoved,
      });
    } catch (error) {
      const retry = attempt < MAX_ATTEMPTS;
      await snapshot.ref.set({
        status: retry ? "queued" : "failed",
        error: error instanceof Error ? error.message.slice(0, 500) : "Delivery failed",
        completedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      logger.error("Notification job attempt failed", {
        jobId: event.params.jobId,
        attempt,
        retry,
        error,
      });
      if (retry) throw error;
    }
  },
);
