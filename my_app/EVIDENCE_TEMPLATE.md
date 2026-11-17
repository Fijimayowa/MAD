# ICA16_A_YourName: Evidence document (template)

Device/platform: ____  Build: ____  App commit: ____  AI assistance disclosure: ____

## Checkpoints (record each when you reach it)
1. Services connected (Firebase project, sign-in works): date/screenshot ____
2. Questions fetched and validated: ____
3. Quiz and review working: ____
4. Cloud write + server read working: ____
Failed-first correction (what broke first, how you fixed it): ____

## State diagram
Draw it from `Phase` in `lib/quiz_controller.dart`. Include the guards (`_busy`, `_isCurrent`, `canReplay`, `unresolved`).

## Test log (fill in from your own runs)
| ID | Precondition | Action | Expected | Observed | Pass/Fail | Screenshot/log | Time | Round ID suffix |
|----|--------------|--------|----------|----------|-----------|----------------|------|-----------------|
| T01 | | | | | | | | |
| T02 | | | | | | | | |
| T03 | | | | | | | | |
| T04 | | | | | | | | |
| T05 | | | | | | | | |
| T06 | | | | | | | | |
| T07 | | | | | | | | |
| T08 | | | | | | | | |
| T09 | | | | | | | | |
| T10 | | | | | | | | |
| T11 | | | | | | | | |
| T12 | | | | | | | | |

T10 and T11 need a deliberate bad request (user B reading user A's path; score 11; extra field; update).
Write these as temporary debug-only code, run them, then remove them. Never deploy open rules.

## Six responses (120-180 words each, plus a diagram/trace/code-line/test reference)
1. Two success layers (use T02/T03; see `TriviaApi.fetch`): ____
2. Unknown is not failed (use T09, your round ID suffix): ____
3. Retry identity (new ID per retry vs one ID per round): ____
4. Cloud trust (rules are not authoritative scoring; server-side improvement): ____
5. Critique the AI (prompt, tool/date, excerpt, two tested claims, one flaw, revised design): ____
6. Design defense (one visual cue + one recovery trade-off, screenshot, a failed-first fix): ____

## Redacted proof
Console screenshot of `users/<uid>/attempts/<roundId>` and the app's "Cloud verified" screen (redact UID/round ID).
