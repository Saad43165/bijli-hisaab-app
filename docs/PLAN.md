# Bijli Hisaab — Project Plan

**One line:** An Android app that helps Pakistani households track electricity units during the month, predict the bill, and stay under the slab limit — with an analytics side built in Power BI.

---

## 1. Problem

- Pakistani domestic tariffs jump sharply at slab boundaries. One extra unit (e.g. 200 → 201) can raise the whole bill and, for protected consumers, removes protected status for the next 6 months.
- Most people only see their usage when the bill arrives — too late to act.
- Bills are confusing: units, slabs, FPA, FC surcharge, GST, electricity duty, fixed charges.

## 2. Solution

The user enters meter readings (or scans the bill). The app:

1. Shows units used so far this billing cycle.
2. Projects month-end units from the current daily pace.
3. Warns before a slab limit is crossed and gives a **safe daily budget** ("use max 4.2 units/day").
4. Estimates the bill in rupees using the current NEPRA tariff (editable in-app because rates change).
5. Shows which appliances use the most electricity.
6. Exports anonymised data (CSV) that feeds the Power BI dashboards.

## 3. Target users

- Households in WAPDA DISCO areas (LESCO, IESCO, FESCO, GEPCO, MEPCO, PESCO, HESCO, SEPCO, QESCO, TESCO, HAZECO) and K-Electric.
- Especially families near the 200-unit protected limit and anyone with AC in summer.

## 4. Scope by phase

### Phase 1 — MVP (this codebase) ✅
| Feature | Status |
|---|---|
| Onboarding + privacy consent | Built |
| Add meter (DISCO, city, province, phase, sanctioned load, protected status, reading day) | Built |
| Multiple meters (home, shop, parents' house) | Built |
| Add meter readings | Built |
| Units this cycle, projection, safe daily budget | Built |
| Slab warning card + local notification | Built |
| Bill estimate (energy, fixed, FC surcharge, FPA, GST, ED, TV fee) | Built |
| Bill scanner (on-device OCR, Google ML Kit) + review screen | Built |
| Manual bill entry + quick past-12-months entry | Built |
| History chart (12 months) with slab colours | Built |
| Appliance calculator + usage pie chart | Built |
| Smart reminders: reading day, close to slab, bill due date, no recent reading | Built |
| Rates screen with sources + optional manual edit | Built |
| Automatic rate updates from GitHub-hosted JSON (validated, cached) | Built |
| Daily NEPRA watcher that opens an issue when new rates are published | Built |
| Lifeline category | Built |
| Saving tips (English + Urdu) | Built |
| CSV export for Power BI (anonymised) | Built |
| Local database (SQLite), works fully offline | Built |

### Phase 2 — Cloud + polish (next)
- Firebase Auth (phone OTP) + Firestore sync, so data survives phone changes.
- Full Urdu UI (Flutter localisation).
- Gemini/LLM fallback when OCR can't read a bill.

### Phase 3 — Analytics pipeline (Power BI)
- Firestore → BigQuery export (Firebase extension) or Cloud Function → Azure SQL.
- Power BI dataset on top, scheduled refresh.
- Monthly public report ("Average Lahore bill in June") for social media marketing.

### Phase 4 — Growth
- Solar savings calculator (natural sponsor: solar companies).
- Home-screen widget showing units used.
- Play Store ASO, Urdu landing page.

## 5. Timeline

| Week | Work |
|---|---|
| 1 | Run this MVP on device, fix device-specific issues, test with 5–10 real bills from different DISCOs |
| 2 | Improve OCR parser with real bill photos, tune slab maths against real bills |
| 3 | Play Store internal testing (signing key, privacy policy page, store listing) |
| 4–5 | Phase 2: Firebase sync + remote tariff |
| 6+ | Phase 3 with the Power BI person |

## 6. Roles

### You (app developer)
- Everything in `lib/` (Flutter app).
- Keep the data schema in `docs/POWER_BI_DATA_SCHEMA.md` stable. If you change a field, tell the Power BI person.
- Phase 2/3 backend (Firebase, export pipeline).

### Power BI person
- Build dashboards **now** using the CSV files the app exports (Settings → Export data for Power BI). The schema is in `docs/POWER_BI_DATA_SCHEMA.md`.
- Later, switch the data source from CSV to BigQuery/SQL — the columns stay the same.
- Deliver the `.pbix` file and a short document explaining each measure (DAX).

## 7. Risks

| Risk | Mitigation |
|---|---|
| Tariff rates change (NEPRA/FCA/quarterly adjustments) | Rates download automatically from the rates repo; NEPRA watcher flags changes daily (docs/AUTO_UPDATE_RATES.md) |
| OCR misreads bills | Always shows a review screen; user confirms values before saving |
| Slab billing rules differ from what we model | Billing mode per category is configurable (whole-units / previous-slab benefit / incremental). Verify against 5+ real bills before launch |
| Privacy | Analytics export is opt-in, anonymised, and excludes names, reference numbers and exact addresses |

## 8. Success metrics (track in Power BI)
- Weekly active users, readings added per user per month.
- % of users who got a slab warning and still ended the month under the limit.
- Retention at day 7 / day 30.
