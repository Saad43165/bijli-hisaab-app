# Next features — plan

Built in this order. Each one is finished (code, tests, docs) before the next starts.

---

## 1. Meter photo reading ✅ built

Files: `services/meter_reading_extractor.dart`, `services/meter_ocr_service.dart`, `features/readings/meter_camera_screen.dart`, `features/readings/widgets/meter_frame_overlay.dart`, `test/meter_reading_extractor_test.dart`. Readings saved from a scan have source `photo`.

**Goal:** add a reading by pointing the camera at the meter. No typing 5-digit numbers.

**User flow**
1. Add reading → **Scan meter** (big button, also a camera icon inside the number field).
2. Full-screen camera with a frame in the middle: "Fit the meter numbers inside the frame". Torch on/off, zoom slider, tap-to-focus.
3. Shutter → "Reading the meter…" (on-device ML Kit OCR).
4. Back on Add reading: the number is filled in, with the photo thumbnail and up to 2 alternative chips ("Did you mean 12458?"). User confirms and saves.

**How the number is chosen** (`MeterReadingExtractor`, pure Dart, unit-tested)
- Collect number candidates from every OCR line, fixing letter/digit swaps (O→0, I/L→1, S→5, B→8) and joining digits the OCR split apart ("1 2 4 5 0" → 12450).
- Drop things that aren't readings: serial/model numbers (lines with NO., S/N, SERIAL, MODEL, IMP/kWh, V, A, Hz), dates, and numbers with fewer than 3 or more than 8 digits.
- Score each candidate:
  - **Plausibility (strongest):** between the last reading and the last reading + 150 units per day since then. Lower than the last reading is penalised hard.
  - **Size:** meter digits are the biggest text on the face.
  - **Position:** closest to the centre (where the frame is).
  - **Digit count:** 5–6 digits typical for Pakistani meters.
  - **"kWh" nearby.**
- Return the top 3 with a confidence; the best goes in the field.

**Edge cases:** dial (analog) meters can't be read — show "Couldn't read the numbers. Type them in." Camera permission denied → explain and open settings. No camera → hide the button.

**Package:** `camera` (official Flutter plugin, CameraX on Android) for the live preview, torch and zoom.

---

## 2. Backup and restore ✅ built

Files: `services/backup/backup_data.dart` (format + validation), `services/backup/restore_plan.dart` (replace/merge planning), `services/backup/backup_service.dart` (database, files, share), `features/settings/backup_screen.dart`, `features/settings/widgets/restore_preview_sheet.dart`, `test/backup_test.dart`. Package: `file_picker`. Also: copy before "Reset app", and "Have a backup? Restore it" on the welcome screen.

**Goal:** never lose readings and bills when changing phones.

- **Backup file:** one JSON file (`bijli-bachao-backup-YYYY-MM-DD.json`) with meters, readings, bills, appliances and settings (not the install ID or analytics consent). Versioned format.
- **Save:** More → Backup & restore → **Save backup** → Android share sheet (Google Drive, WhatsApp to self, Files…).
- **Restore:** **Restore from file** → file picker → preview ("3 meters, 182 readings, 24 bills, from 21 Oct 2026") → **Replace** or **Merge**.
  - Merge keeps existing data and adds what's missing (readings matched by meter + date, bills by meter + month).
- **Safety:** validate before touching the database; restore runs in one database transaction (all or nothing); an automatic local backup is taken right before a restore.
- **Automatic:** a local backup is written weekly (last 4 kept) so a bad restore or accidental reset can be undone from the same screen.

---

## 3. Smart reminders ✅ built

Files: `services/reminders/reminder_planner.dart` (pure planner), `services/notification_service.dart` (`scheduleReminders`, `zonedSchedule` in Asia/Karachi, inexact so no alarm permission), `features/settings/reminders_screen.dart`, `test/reminder_planner_test.dart`. Replaces the old fixed weekly reminder. Re-planned on every data change, serialised so edits can't interleave. Per-type switches are included in backups.

**Goal:** remind users at the moments that matter, not on a fixed weekly timer.

| Reminder | When | Example |
|---|---|---|
| Reading-day reminder | 3 days and 1 day before the meter reading day, 7 pm | "Your meter is read on the 10th. Check it now — you're on track for 196 units." |
| Close-to-slab alert | Daily at 8 pm, only while projected within 10% of a limit or over it, in the last 10 days of the cycle | "4 days left. Use max 3.2 units a day to stay under 200." |
| Bill due date | 2 days before and on the due date of the latest bill, 10 am | "Your LESCO bill of Rs 8,420 is due on Friday." |
| No recent reading | 6 days without a reading | "Add a reading to keep your projection accurate." |

- Scheduled with exact local dates (`zonedSchedule` + `timezone`, Asia/Karachi), re-planned every time data changes and when the app opens.
- Each type can be switched on/off in More → Reminders, with a preview of the next reminder.
- Quiet hours: nothing before 9 am or after 9:30 pm.
