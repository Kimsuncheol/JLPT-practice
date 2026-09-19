import {describe, expect, it} from "vitest";
import {parseNotificationJob} from "./job";

describe("parseNotificationJob", () => {
  it("accepts a valid targeted job", () => {
    expect(parseNotificationJob({
      targetUserId: "user-1",
      title: "New lesson",
      body: "Your N3 lesson is ready.",
      data: {type: "new_lesson", route: "/study"},
    })).toMatchObject({targetUserId: "user-1", title: "New lesson"});
  });

  it("rejects non-string FCM data values", () => {
    expect(() => parseNotificationJob({
      targetUserId: "user-1",
      title: "Title",
      body: "Body",
      data: {count: 3},
    })).toThrow("Invalid data value");
  });

  it("rejects oversized content", () => {
    expect(() => parseNotificationJob({
      targetUserId: "user-1",
      title: "x".repeat(101),
      body: "Body",
      data: {},
    })).toThrow("title");
  });

  it("rejects invalid user paths and oversized aggregate data", () => {
    expect(() => parseNotificationJob({
      targetUserId: "users/user-1",
      title: "Title",
      body: "Body",
      data: {},
    })).toThrow("slash");
    expect(() => parseNotificationJob({
      targetUserId: "user-1",
      title: "Title",
      body: "Body",
      data: {one: "x".repeat(1000), two: "x".repeat(1000), three: "x".repeat(1000)},
    })).toThrow("too large");
  });
});
