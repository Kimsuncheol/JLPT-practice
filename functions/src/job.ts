export interface NotificationJobInput {
  targetUserId: string;
  title: string;
  body: string;
  data: Record<string, string>;
}

const RESERVED_DATA_KEYS = new Set(["from", "message_type", "notificationJobId"]);

export function parseNotificationJob(value: unknown): NotificationJobInput {
  if (!value || typeof value !== "object") throw new Error("Job must be an object");
  const job = value as Record<string, unknown>;
  const targetUserId = requiredString(job.targetUserId, "targetUserId", 128);
  if (targetUserId.includes("/")) throw new Error("targetUserId cannot contain a slash");
  const title = requiredString(job.title, "title", 100);
  const body = requiredString(job.body, "body", 500);

  if (!job.data || typeof job.data !== "object" || Array.isArray(job.data)) {
    throw new Error("data must be a string map");
  }
  const entries = Object.entries(job.data as Record<string, unknown>);
  if (entries.length > 20) throw new Error("data has too many entries");
  const data: Record<string, string> = {};
  let dataSize = 0;
  for (const [key, rawValue] of entries) {
    if (!key || key.length > 128 || RESERVED_DATA_KEYS.has(key)) {
      throw new Error(`Invalid data key: ${key}`);
    }
    if (typeof rawValue !== "string" || rawValue.length > 1000) {
      throw new Error(`Invalid data value for: ${key}`);
    }
    dataSize += key.length + rawValue.length;
    data[key] = rawValue;
  }
  if (dataSize > 3000) throw new Error("data payload is too large");
  return {targetUserId, title, body, data};
}

function requiredString(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string" || value.trim() === "" || value.length > maxLength) {
    throw new Error(`${field} must be a non-empty string of at most ${maxLength} characters`);
  }
  return value;
}
