# ICA16 Class A: General Knowledge cloud-backed round

Flutter app: Open Trivia DB questions, Firebase Auth sign-in, one immutable score
document per round in Cloud Firestore, read back with a server-only read.

## Setup (no credentials are stored in this repo)

1. Create a Firebase project (or use the instructor-approved one).
2. Firestore: create a **Standard edition, Native mode** database in **production mode**.
3. Authentication: enable **Email/Password**. Create two test users (A and B) in the console.
   Share their passwords only through the instructor-approved private channel.
4. In a new Flutter project, copy `lib/`, `firestore.rules` and the dependencies below.
5. From the project root:

```
flutter pub add http html_unescape firebase_core firebase_auth cloud_firestore
firebase login
dart pub global activate flutterfire_cli
flutterfire configure        # choose the real Android app; generates lib/firebase_options.dart
firebase init firestore      # point it at firestore.rules (do NOT overwrite with open rules)
firebase deploy --only firestore:rules
```

6. Add to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`, above `<application>`):
   `<uses-permission android:name="android.permission.INTERNET"/>`
7. Fully rebuild after native changes: `flutter clean && flutter run`.

## Data contract

Path: `users/{uid}/attempts/{roundId}`. Exactly six fields:
`schemaVersion` (1), `variant` ("A"), `categoryId` (9), `questionCount` (10),
`correctCount` (0-10), `submittedAt` (server timestamp). Rules forbid updates and deletes.

## Design notes

- Round ID is created once per round with `attempts.doc().id` and reused on every retry.
- Save = Firestore transaction (read first; create if absent; reuse if matching; collision if different).
- After the transaction, a `Source.server` read verifies existence and all fields before showing "Cloud verified".
- Lost acknowledgement -> `saveUnknown` -> "Check server" reads the same round ID.
- Retry policy: user-triggered only; at least 5 s between OpenTDB requests; one submission at a time;
  replay and sign-out disabled while a save is unresolved.
- Debug builds include a clearly labeled fault-injection panel (T03, T09, T12). It is hidden in release builds.

## Finding the record (restart test, T07)

After signing in as the same user, paste the saved round ID into "Retrieve a saved attempt by round ID".
A grader with console access can find it at `users/<uid>/attempts/<roundId>` (redacted in the evidence document).

## Build

```
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk  ->  rename to ICA16_A_YourName.apk
```
