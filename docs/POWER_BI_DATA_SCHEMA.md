# Data schema for the Power BI dashboard

Send this file to the Power BI developer.

## How to get data

In the app: **More → Export data for Power BI**. The app shares 5 UTF-8 CSV files (comma separated, header row, ISO dates `YYYY-MM-DD`, timestamps ISO 8601 UTC). Collect exports from test users and append files of the same name together in Power Query — `install_id` keeps users apart.

Later (Phase 3) the same tables will come from BigQuery or SQL with the **same column names**, so the dashboards won't need rebuilding — only the data source changes.

No names, phone numbers, bill reference numbers or addresses are exported. `install_id` is a random ID generated on the phone. Users must opt in (More → Privacy) before export.

---

## Tables

### `meters.csv` — one row per meter
| Column | Type | Example | Notes |
|---|---|---|---|
| install_id | text | `a3f9c2e1b7d04e55` | Random per app install |
| meter_id | integer | `1` | Unique within an install |
| meter_key | text | `a3f9c2e1b7d04e55-1` | **Primary key** (install_id-meter_id) |
| disco | text | `LESCO` | LESCO, IESCO, FESCO, GEPCO, MEPCO, PESCO, HAZECO, TESCO, HESCO, SEPCO, QESCO, K-Electric, AJK-ED, GB-WPD |
| city | text | `Lahore` | Typed by user (clean in Power Query: trim, proper case) |
| province | text | `Punjab` | Punjab, Sindh, KP, Balochistan, ICT, AJK, GB |
| connection_type | text | `home` | home, shop, other |
| phase | text | `single` | single, three |
| sanctioned_load_kw | decimal | `2` | |
| protected_setting | text | `auto` | protected, unprotected, auto |
| reading_day | integer | `10` | Day of month the meter is read |
| created_at | timestamp | `2026-10-21T17:02:11Z` | |

### `readings.csv` — meter readings entered by the user
| Column | Type | Example |
|---|---|---|
| install_id | text | |
| meter_key | text | FK → meters.meter_key |
| reading_date | date | `2026-10-18` |
| reading_value | decimal | `12450` |
| source | text | `manual` / `bill` |
| created_at | timestamp | |

### `bills.csv` — monthly bills
| Column | Type | Example | Notes |
|---|---|---|---|
| install_id | text | | |
| meter_key | text | | FK |
| bill_month | text | `2026-09` | `YYYY-MM` |
| bill_month_date | date | `2026-09-01` | Use this for the date axis |
| units | integer | `214` | |
| amount_rs | decimal | `8420` | Amount payable within due date (0 if unknown) |
| due_date | date | `2026-10-12` | May be empty |
| slab_band | text | `201-300` | 1-100, 101-200, 201-300, 301-400, 401-500, 501-600, 601-700, 700+ |
| source | text | `scan` | scan, manual, history |
| created_at | timestamp | | |

### `appliances.csv`
| Column | Type | Example |
|---|---|---|
| install_id | text | |
| meter_key | text | |
| appliance | text | `AC (1.5 ton inverter)` |
| category | text | `cooling` (cooling, heating, kitchen, laundry, lighting, entertainment, pump, other) |
| watts | integer | `1200` |
| quantity | integer | `1` |
| hours_per_day | decimal | `6` |
| est_units_month | decimal | `216` |

### `events.csv` — app usage log
| Column | Type | Example | Notes |
|---|---|---|---|
| install_id | text | | |
| event_type | text | `slab_warning` | see list below |
| meter_key | text | | may be empty |
| value | decimal | `214` | meaning depends on event |
| detail | text | `limit=200` | short key=value text |
| created_at | timestamp | | |

Event types: `app_open`, `onboarding_done`, `meter_added`, `reading_added` (value = reading), `bill_added` (value = units, detail = source), `bill_scanned` (detail = fields detected), `slab_warning` (value = projected units, detail = limit), `appliance_added`, `export_done`, `backup_saved`, `backup_restored` (value = rows added, detail = replace|merge). Readings also have `source` = manual | bill | photo.

---

## Relationships (model view)
```
meters.meter_key 1 ──── * readings.meter_key
meters.meter_key 1 ──── * bills.meter_key
meters.meter_key 1 ──── * appliances.meter_key
meters.meter_key 1 ──── * events.meter_key
```
Add a `Date` table (CALENDAR) and relate it to `bills.bill_month_date` and `readings.reading_date`.

## Dashboards wanted
1. **Overview:** active installs, meters, bills logged, readings this month (cards).
2. **Usage:** average units and average bill by month, by DISCO, by city (line + bar, slicers for DISCO/province/connection type).
3. **Seasonality:** summer (May–Sep) vs winter (Nov–Feb) average units.
4. **Slab impact:** share of bills in each slab band; # of meters that crossed 200 units; slab warnings vs. outcome (did the next bill stay under the limit?).
5. **Appliances:** top categories by estimated units.
6. **App health:** events per day, readings per active user, day-7 retention (first `app_open` vs later `app_open`).

## Example DAX measures
```DAX
Avg Units = AVERAGE(bills[units])
Avg Bill (Rs) = AVERAGEX(FILTER(bills, bills[amount_rs] > 0), bills[amount_rs])
Meters Over 200 = CALCULATE(DISTINCTCOUNT(bills[meter_key]), bills[units] > 200)
Active Installs (30d) =
    CALCULATE(DISTINCTCOUNT(events[install_id]),
              events[created_at] >= TODAY() - 30)
```

Deliverables expected: `.pbix` file, a list of measures with one-line explanations, and a short note on how to refresh with new CSVs.
