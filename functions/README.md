# Remote push Cloud Function

Daily study reminders are scheduled locally by the Flutter app for exact,
offline, device-local delivery. This backend is for trusted server-originated
push notifications such as new-content announcements or account events.

## Firestore contract

The Flutter client writes one document per installation at
`users/{uid}/devices/{deviceId}`:

```text
token: FCM registration token
platform: "android" | "ios"
enabled: boolean
updatedAt: server timestamp
```

Use a random stable installation ID as `deviceId`, not the FCM token. Refresh
the document whenever FCM rotates the token and delete or disable it on
sign-out. Invalid registrations are automatically removed after a send.

A trusted service using the Firebase Admin SDK creates a job with status
`queued`. Client access to this collection is denied by Firestore Rules:

```js
await getFirestore().collection("notificationJobs").add({
  status: "queued",
  targetUserId: "firebase-auth-uid",
  title: "New N3 lesson",
  body: "Your next lesson is ready.",
  data: {type: "new_lesson", route: "/study"}, // FCM requires string values
  createdAt: FieldValue.serverTimestamp(),
});
```

The function validates the payload, fans out in FCM's 500-token batches,
removes permanently invalid device registrations, and writes `completed` or
`failed` plus aggregate results to the job. Transient whole-job failures retry
up to three times. Push delivery is inherently at-least-once, so consumers
should deduplicate important actions using the injected `notificationJobId`
data field. Never place
secrets or full records in the push payload; send identifiers that the
authorized app resolves.

## Develop and deploy

```sh
cd functions
npm install
npm run check
cd ..
firebase deploy --only firestore:rules,functions
```

Upload an APNs authentication key in Firebase for iOS. Production job creators
should use a narrowly scoped service account and apply retention (Firestore TTL
or scheduled cleanup) to old completed jobs.
