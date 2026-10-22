# Bijli Hisaab — Design

## 1. Design direction

Calm, trustworthy, utility-first. The app talks about money people are worried about, so the UI stays clear and quiet, and colour is reserved for meaning: **green = safe, amber = close to the limit, red = over the limit**.

- **Brand:** deep navy (trust) + electric amber (electricity, the bolt).
- **Numbers first:** the big number on every card is the thing the user cares about (units, rupees, units/day).
- **One action per screen:** "Add reading" is always one tap away (floating button on Home).

## 2. Design tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `navy` | `#0E1A2B` | — | Brand, app bar on splash, icon background |
| `amber` | `#F5B700` | `#F5B700` | Primary accent, bolt, primary buttons |
| `background` | `#F6F4EE` | `#0B1220` | Scaffold |
| `surface` | `#FFFFFF` | `#131C2E` | Cards |
| `ink` | `#101828` | `#EEF1F6` | Primary text |
| `muted` | `#667085` | `#98A2B3` | Secondary text |
| `safe` | `#1F9D6B` | `#34C38F` | Under limit |
| `warn` | `#E58A00` | `#F5A524` | Within 15% of a slab limit |
| `danger` | `#D64545` | `#F06565` | Projected to cross a limit |

Spacing scale: 4, 8, 12, 16, 20, 24, 32. Card radius 20, input radius 14, button radius 14.
Type: **Plus Jakarta Sans** (bundled) for everything, **Noto Nastaliq Urdu** for Urdu text (line height 2.0). Display numbers 52/800, titles 20/700, body 14.5/400, labels 11/700 uppercase.

Components: `AppCard` (soft shadow light / hairline dark, gradient variant for hero cards), `IconTile`, `LoadingButton` (haptic), `AnimatedNumber`, `InfoBanner`, `StatusPill`, `UrduText`.

## 3. Navigation

```
Splash ──> Onboarding (first run only)
              1. Welcome
              2. Privacy & data consent
              3. Add your meter
                    │
                    ▼
Home shell (bottom navigation)
 ├── Home          → Add reading, Scan bill, Slab details, Switch meter
 ├── History       → Bill detail/edit, Add bill, Add past months
 ├── Appliances    → Add / edit appliance (bottom sheet)
 └── More          → Meters, Tariff rates, Tips, Export for Power BI, Reminders, About, Reset
```

## 4. Screens

### 4.1 Onboarding
- **Welcome:** bolt logo, "Know your units before the bill comes."
- **Consent:** what is stored (on phone only), optional anonymous analytics export. Toggle for analytics (default off).
- **Add meter:** name, DISCO (dropdown), city, province, single/three phase, sanctioned load (kW), protected status (Yes / No / Not sure), reading day of month, last bill reading + date.

### 4.2 Home (dashboard)
1. Meter switcher chip (if more than one meter).
2. **Hero usage card (navy gradient):** units used this cycle inside a ring that fills toward the next slab limit, faint arc for the projection; day / per-day / month-end stats.
2b. **Slab ladder:** slabs as coloured segments with the per-unit rate above each, solid marker = now, hollow = month end.
3. **Slab alert card** (colour by status): "At this pace you'll reach 214 units. Stay under 200 — use max 3.6 units/day for the next 12 days." Protected users get the 6-month warning.
4. **Bill estimate card:** projected bill in Rs, tap to see breakdown (energy, fixed, FC surcharge, FPA, ED, GST, TV fee).
5. **Daily usage chart:** units per day between readings (line).
6. Quick actions: Add reading · Scan bill · Appliances.
7. Tip of the day.

Empty state (no readings yet): illustration + "Add today's meter reading to start".

### 4.3 Add reading
Big numeric field, date picker (defaults today), shows last reading for sanity and blocks a reading lower than the previous one (with an option for meter replacement). After save: SnackBar + re-calculation + notification if a limit is now projected to be crossed.

### 4.4 Scan bill
Camera / gallery → on-device OCR → **Review** form pre-filled with detected values (bill month, units, amount, due date, present reading). Each detected field shows a "detected" badge so the user knows what to double-check. Save → bill + optional reading.

### 4.5 History
- Bar chart: last 12 bill months, bars coloured by slab band (≤100, ≤200, ≤300, >300) with a dashed line at 200.
- Summary row: average units, highest month, total paid.
- List of bills (month, units, amount, source badge: scanned/manual). Tap to edit or delete.
- "Add past months" — a 12-row grid to quickly fill history from the bill's history table.

### 4.6 Appliances
- Pie/donut of estimated monthly units by appliance + legend.
- List: icon, name, watts × qty × hours/day → units/month and Rs/month at the current marginal rate.
- Add/edit bottom sheet with presets (AC 1.5 ton inverter, AC non-inverter, fridge, fan, LED, iron, washing machine, water motor, TV, laptop, geyser electric, microwave, PC).

### 4.7 More
- Meters (list, add, edit, delete, set active).
- Tariff rates: view slabs for protected/unprotected, edit rates, FPA, GST, ED %, FC surcharge, TV fee, billing modes. "Reset to default".
- Saving tips (English + Urdu).
- Export for Power BI: shows what's included, then shares 5 CSV files.
- Reminders: weekly "add your reading" notification on/off.
- About + disclaimer: "Estimates only. Your DISCO bill is final."

## 5. Architecture

```
lib/
├── main.dart                 entry: init DB, notifications, prefs → runApp
├── app.dart                  MaterialApp, themes, first-run routing
├── core/                     theme, constants, formatting utils
├── data/
│   ├── models/               plain Dart models with toMap/fromMap
│   ├── db/                   SQLite schema + migrations
│   └── repositories/         CRUD per table
├── services/                 tariff maths, forecasting, OCR, parsing,
│                             notifications, CSV export, settings
├── state/                    AppState (ChangeNotifier via provider)
├── features/                 one folder per screen group, each with widgets/
└── shared/widgets/           reusable UI pieces
```

- **State:** a single `AppState` (provider `ChangeNotifier`) loads the active meter, readings, bills, appliances and tariff, and exposes a computed `CycleSummary`. Screens read from it and call its methods; repositories never get called from widgets directly.
- **Pure logic is isolated:** `TariffCalculator`, `UsageForecaster` and `BillTextParser` have no Flutter imports, so they're unit-tested in `test/`.
- **Offline first:** everything lives in SQLite on the phone. Phase 2 adds Firestore sync behind the same repositories.

## 6. Core calculations

**Units this cycle** = latest reading − baseline reading, where baseline is the last reading on or before the cycle start (or the first reading in the cycle).

**Daily rate** = units ÷ days between baseline and latest reading.
**Projected units** = units + daily rate × days left in the cycle.

**Next limit** = smallest slab boundary ≥ projected units, with 200 treated as critical for protected users.
**Safe daily budget** = (limit − units) ÷ days left.

**Status:** safe if projected < 85% of the current limit window, warn if within it, danger if projected > limit.

**Bill estimate** (all configurable in `tariff_pk.json`):
```
energy   = slab maths (whole-units | previous-slab benefit | incremental)
fixed    = fixed Rs/kW for the slab × sanctioned load
fc       = FC surcharge/unit × units
fpa      = FPA/unit × units
ed       = electricity duty % × energy
gst      = GST % × (energy + fixed + fc + fpa)
total    = energy + fixed + fc + fpa + ed + gst + TV fee
```
