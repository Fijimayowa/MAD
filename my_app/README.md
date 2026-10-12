# local_storage_lab (Fall Festival Roster)

**Name:** Femi Ijimayowa | **Course/Section:** \_\_\_\_ | **Pathway:** Undergraduate / Graduate

## Setup

- Flutter: \_**\_ | Dart: \_\_** (from `flutter --version`)
- Packages: sqflite \_**\_, path \_\_** (versions from pubspec.lock)
- Tested on: \_\_\_\_ (device/simulator name and OS version)
- Commands:
  flutter pub get
  flutter analyze
  flutter run -d <device id from `flutter devices`>

## Design notes

- **Schema/initialization:** One table, `roster`, with `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `name` (TEXT NOT NULL), and `age` (INTEGER NOT NULL). `main()` calls `helper.init()` before `runApp`, which opens `roster.db` and creates the table on first launch. If this fails, the app shows a "Could not open local storage" screen.
- **Input/ID policy:** Name must be non-empty after trimming. Age must be a whole number from 0 to 130. Invalid input writes nothing. IDs are assigned by SQLite, never typed by the user, and AUTOINCREMENT means deleted IDs are not reused.

## State examples

- **Memory state:** `_rows` (list loaded from the database), `_count`, `_selectedId` (the ID being edited, or null), e.g. `_selectedId = ____`
- **Key-value preferences:** \_\_\_\_ (see note below)
- **SQLite record:** e.g. `id=____, name=____, age=____`

## CRUD source locations

- Create: `DatabaseHelper.insert` in lib/database_helper.dart, called from `_onSave` in lib/main.dart
- Read: `queryAllRows` and `queryRowCount`, called from `_load`
- Update: `DatabaseHelper.update`, called from `_onSave` when `_selectedId` is set
- Delete: `DatabaseHelper.delete`, called from `_onDelete`

## Test table

| Test          | Action                                           | Stop/relaunch method                                        | Observed                                                                                            | Pass/Fail |
| ------------- | ------------------------------------------------ | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | --------- |
| T1 Empty      | Fresh install, tapped Refresh on empty roster    | n/a                                                         | Count **_; message "_**"                                                                            | \_\_\_    |
| T2 Create     | Added River A (21) and River B (34)              | n/a                                                         | IDs: A=**_, B=_**; count \_\_\_                                                                     | \_\_\_    |
| T3 Identity   | Edit B to 99, Cancel; Edit B, Save 35            | n/a                                                         | After Cancel B=**_; Save message "_**"; count **_; A=_**, B=\_\_\_                                  | \_\_\_    |
| T4 Restart    | Killed app, relaunched same install              | \_\_\_ (e.g., swiped away in simulator, reopened from icon) | After relaunch: IDs **_, ages _**, count **_; no reseeding: _** (T4_before.png, T4_after.png)       | \_\_\_    |
| T5 Delete     | Cancel delete A; confirm delete A; Refresh       | n/a                                                         | After Cancel count **_; confirm message "_**"; after Refresh remaining **_, count _**               | \_\_\_    |
| T6 Validation | 5 invalid attempts, then Acorn (0) and Oak (130) | n/a                                                         | Rejected: **_ of 5, count stayed _**; Acorn ID **_, Oak ID _**; final count \_\_\_ (T6_invalid.png) | \_\_\_    |

Screenshots: evidence/T4_before.png, evidence/T4_after.png, evidence/T6_invalid.png
Analyzer: `flutter analyze` reported \_**\_ (see evidence/analysis_output.txt)
Known limitations: \_\_**

## Reflections

1. Before T4, I predicted that everything would survive the restart, because the data is saved in the SQLite file on the device and not in memory. My records before the restart were ID 122 (River, age 21) and ID 190 (River, age 34), with a count of 2. I stopped the app by 87 and reopened the same install, and the after screenshot shows 9 (evidence/T4_before.png, evidence/T4_after.png). In my code, main() calls init(), which opens roster.db and only creates the table if it doesn't exist yet. Then \_load() calls queryAllRows() and queryRowCount(), and the results fill 2 rows and 3 counts, which the list shows. My claim would be disproved if, after the restart, the list was empty, the count was 0, or the IDs started over at 1 as if the table were new.
2. Both records are named River, so the name can't tell them apart. The IDs can: A was 1 and B was 2 , and the ages were 21 and 34. My update call, DatabaseHelper.update in database helper.dart, uses WHERE id = ?, so editing B changed only B. The result was "Rows affected: F” ," and afterward A was still 3 and B became 9 . If the app picked a record by its position in a sorted list instead, a re-sort could shift the rows. For example, if the list were re-sorted by age after I tapped the second row, I could edit the wrong River.

3. One thing I noticed was the UI (for example, after Add, the form cleared and the message said "Added ... with ID 211 "). A small improvement would be quicker response time(for example, showing a short success message that disappears on its own). The trade-off is slower computing (for example, the message might vanish before the user reads it). For T6, each invalid attempt showed "Invalid input. Nothing was saved." and the count stayed the same, so nothing was written. Acorn and Oak were then accepted and the count reached 900. I found no bug / I found an error and handled it by backtracking..
