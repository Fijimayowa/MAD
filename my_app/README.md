# Chatboards (message_board)

Flutter + Firebase Auth + Cloud Firestore message board.

## Setup
1. `flutter create message_board`, then copy `lib/`, `firestore.rules`, `firebase.json`, `test_rules/` into it.
2. `flutter pub add firebase_core firebase_auth cloud_firestore`
3. `firebase login`, `dart pub global activate flutterfire_cli`, `flutterfire configure` (select Android). This generates `lib/firebase_options.dart`; do not hand-write it.
4. Firebase console: enable Email/Password; create Firestore database.
5. `firebase deploy --only firestore:rules`
6. Confirm `<uses-permission android:name="android.permission.INTERNET" />` is in `android/app/src/main/AndroidManifest.xml`.
7. `flutter run`; release: `flutter build apk --release`.

## Auth flow
Splash (Firebase init + retry on failure) -> `AuthGate` listens to `authStateChanges()` -> signed-out: AuthScreen (login/register), signed-in: BoardScreen. All auth calls live in `AuthService`.

## Data model (public vs private, with writers)
| Path | Fields | Writer |
|---|---|---|
| `users/{uid}` (private to uid) | uid, firstName, lastName, role, registrationDateTime | Client, once at registration; time stamped by server; no update/delete |
| `messages/{msgId}` (public to signed-in) | text, authorUid, authorName, createdAt | Author at create (createdAt = server time) |
| | editedAt | Author on update (server time) |
| `users/{uid}/prefs/*` | private prefs | Owner only (optional spice) |

`role` is descriptive only and never used for access. Every Firestore call is in `BoardService`.

## Authentication vs authorization
Auth (Firebase Auth) proves who you are. Authorization (`firestore.rules`) decides what you may do: read needs sign-in; update/delete need `resource.data.authorUid == request.auth.uid`; create must carry your own uid and server time. Hidden buttons are UX only.

## Duplicate submits
Button disables while sending, and the message id is generated once per compose attempt (`set()` on a fixed id), so retries and offline replays write the same document.

## Tests
- Manual smoke test and evidence: see assignment checklist.
- Automated rules tests (emulator): `firebase emulators:exec --only firestore "cd test_rules && npm test"` (run `npm install` in `test_rules/` first).
