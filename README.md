# Bijli Hisaab ⚡

Track your electricity units during the month, predict your bill, and stay under the slab limit. Built with Flutter for Android.

- **Plan:** [`docs/PLAN.md`](docs/PLAN.md)
- **Design:** [`docs/DESIGN.md`](docs/DESIGN.md)
- **For the Power BI developer:** [`docs/POWER_BI_DATA_SCHEMA.md`](docs/POWER_BI_DATA_SCHEMA.md)
- **Automatic rate updates:** [`docs/AUTO_UPDATE_RATES.md`](docs/AUTO_UPDATE_RATES.md) ← do the one-time setup before publishing

## Features
- **Meter photo reading:** live camera with frame, flashlight, zoom and tap-to-focus; picks the reading using your last reading, text size, position, digit count and "kWh"; shows alternatives ("Did you mean")
- **Backup & restore:** one JSON file shared to Drive/WhatsApp; restore from file with preview, Replace or Add-to-my-data (merge), all-or-nothing transaction, automatic safety copy before restore/reset, weekly copies on the phone; "Restore a backup" on the welcome screen for new phones
- **Smart reminders:** before the meter reading day, evenings near a slab limit (with a daily budget), bill due dates, and after 6 days without a reading; each can be switched off, with a "Coming up" preview; quiet hours 9 pm–9 am
- Meter readings → units this cycle, daily average, month-end projection
- Slab warnings with a **safe daily budget** + local notifications
- Lifeline, protected (≤200 units × 6 months) and normal rate categories
- Slab ladder showing where you are and the per-unit rate of each slab
- Bill estimate: energy, fixed charges per kW, FC surcharge, monthly FCA, quarterly QTA, GST
- **Rates update automatically** from a JSON file you host on GitHub (validated, cached, offline fallback)
- Bill scanner: Google's document scanner (edge detection, auto-capture, crop, shadow removal, flash on/off, 2 pages), on-device OCR, layout-aware reading of labels and table columns, OCR digit fixes, cross-checks (units vs readings × MF, amount vs expected bill, dates), confidence per value, highlights on the photo, "Scan again" merge, raw text view
- 12-month history chart, quick "past months" entry
- Appliance calculator with usage donut
- Rates screen with sources; optional manual editing
- Saving tips in English + Urdu
- Anonymised CSV export for Power BI
- Multiple meters, light/dark theme, fully offline (SQLite)

## Electricity companies
All 14 are supported, each with region, helpline, official bill link and bill-scanner detection:

| Group | Companies | Tariff |
|---|---|---|
| WAPDA DISCOs | LESCO, IESCO, FESCO, GEPCO, MEPCO, PESCO, HAZECO, TESCO, HESCO, SEPCO, QESCO | NEPRA uniform tariff |
| Private | K-Electric | Same NEPRA tariff since Feb 2026; FCA and QTA applied uniformly |
| Own tariff | AJK Electricity Department, GB Water & Power | Area sets its own rates — app warns and lets the user enter them |

If NEPRA ever sets a different FCA/QTA for one company, add it under `company_overrides` in the published `tariff_pk.json` (e.g. `"K-Electric": {"fca_per_unit": 1.2}`); every phone picks it up automatically.

Company data lives in `lib/core/constants/companies.dart`.

**Logos:** all 14 company logos are bundled in `assets/images/companies/` (512×512, transparent, trimmed and centred the same way; shown on a white tile so they read in light and dark mode). Logos are trademarks of each company — the Play Store listing should say the app is not affiliated with them. Remove a file to fall back to the coloured badge.

## Images and fonts
- 3D illustrations: Microsoft Fluent Emoji (MIT) — `assets/images/3d/`, licence in `assets/images/`
- App icon, splash and Play Store icon (`store/play_store_icon_512.png`) rendered from vector at full resolution for each screen density
- Fonts: Plus Jakarta Sans, Noto Nastaliq Urdu (OFL) — `assets/fonts/`
- The notification icon is a white silhouette on purpose: Android requires monochrome status-bar icons.

## Requirements
| Tool | Version |
|---|---|
| Flutter | **3.44 or newer** (stable). Check with `flutter --version`, update with `flutter upgrade` |
| Android Studio | Latest, with Android SDK 36 and the Android SDK command-line tools |
| JDK | 17+ (Android Studio's bundled JDK works) |
| Phone | Android 7.0 (API 24) or newer |

Run `flutter doctor` and fix anything red before continuing.

## Run it
```bash
cd bijli_bachao
flutter pub get
flutter run            # with a phone connected (USB debugging on) or an emulator running
```
The first build downloads Gradle and Android dependencies, so it can take 5–10 minutes.

Run the tests:
```bash
flutter test
```

## Build an APK
```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Release build for Play Store
The release build currently uses the debug key so it runs out of the box. Before uploading to Play:
1. Create a keystore: `keytool -genkey -v -keystore %USERPROFILE%\bijli-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Add `android/key.properties` (don't commit it) and a `release` signing config in `android/app/build.gradle.kts` — see https://docs.flutter.dev/deployment/android#sign-the-app
3. `flutter build appbundle --release` and upload `build/app/outputs/bundle/release/app-release.aab`.

You will also need a privacy policy URL for the Play listing (the text in *More → About & privacy* is a good start).

## Project structure
```
lib/
├── main.dart                     entry point
├── core/config/remote_config.dart  URL of your published rates file
├── app.dart                      MaterialApp, themes, splash/onboarding/home routing
├── core/
│   ├── constants/                DISCOs, provinces, appliance presets, saving tips
│   ├── theme/                    colours + Material 3 theme (light/dark)
│   └── utils/                    formatting and date helpers
├── data/
│   ├── models/                   Meter, MeterReading, Bill, Appliance, Tariff, AppEvent
│   ├── db/                       SQLite schema
│   └── repositories/             one repository per table + tariff loader
├── services/                     tariff maths, forecasting, OCR, bill parser,
│                                 notifications, CSV export, settings
├── state/app_state.dart          app state (provider ChangeNotifier)
├── features/
│   ├── onboarding/               welcome, privacy consent, add meter
│   ├── home/                     dashboard + its widgets
│   ├── readings/                 add reading, readings list
│   ├── bills/                    scan, add/edit bill, history, past months
│   ├── appliances/               appliance list, add sheet, donut chart
│   ├── meters/                   meter list, add/edit meter, shared form
│   └── settings/                 more, tariff rates, export, tips, about
└── shared/widgets/               cards, headers, empty states, badges, dialogs
assets/config/tariff_pk.json      built-in rates (offline fallback)
assets/fonts/                     Plus Jakarta Sans + Noto Nastaliq Urdu (OFL)
rates_repo/                       upload to GitHub: published rates + validator + NEPRA watcher
test/                             unit tests for tariff maths, forecasting, parser
```

## Updating tariff rates
**Don't edit code.** Rates come from `tariff_pk.json` in your rates repo and update on every phone automatically — see [`docs/AUTO_UPDATE_RATES.md`](docs/AUTO_UPDATE_RATES.md).

Current built-in rates (checked 21 Oct 2026):
- Slab and fixed charges: NEPRA decision of 11 Feb 2026, notified as S.R.O. 279(I)/2026
- FCA: +Rs 1.1086/unit on October 2026 bills (August 2026 fuel)
- QTA: +Rs 0.5194/unit on September–November 2026 bills (S.R.O. 1501(I)/2026)
- GST 18%; FC surcharge Rs 3.23/unit for normal consumers (protected exempt)
- Electricity duty and PTV fee: removed from bills since July 2025

Before each app release, copy the latest `rates_repo/tariff_pk.json` into `assets/config/tariff_pk.json` so new installs start with current rates even offline.

## Troubleshooting
| Problem | Fix |
|---|---|
| `version solving failed` on `pub get` | Your Flutter is older than 3.44 — run `flutter upgrade` |
| Gradle/AGP version error | Run `flutter upgrade`, then `flutter clean && flutter pub get` |
| `Could not find com.android.tools:desugar_jdk_libs` | Check internet/proxy, then `cd android && gradlew --refresh-dependencies` |
| No notifications | Allow notifications for Bijli Hisaab in Android settings; check More → Reminders & alerts → Coming up. Some phones (Xiaomi, Oppo, Vivo) also need battery saver set to "No restrictions" for the app |
| Meter scan picks the wrong number | Zoom so only the digits fill the frame, turn the light off if the glass shines, or tap a "Did you mean" chip |
| Camera won't open | Allow camera in Settings → Apps → Bijli Hisaab → Permissions, or use "Pick from gallery" |
| "This file isn't a Bijli Hisaab backup" | Pick the `bijli-bachao-backup-….json` file itself, not a screenshot or zip |
| Scanner reads nothing | Better light, flat bill, fill the frame with the top half of the bill |
| "Online updates not set up" in Rates screen | Set your GitHub username in `lib/core/config/remote_config.dart` |
| Rates didn't update | Did `version` increase? Is the Validate check green? Press Check now in the app |
