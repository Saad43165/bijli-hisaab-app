# Bijli Hisaab — published rates

This repo holds `tariff_pk.json`, the electricity rates every Bijli Hisaab app downloads. Change this file and all installed apps update within about 12 hours. No new app release needed.

## Monthly update (5 minutes)
NEPRA announces the **FCA** around the 5th–10th of each month and the **QTA** every quarter. When the "Watch NEPRA" workflow opens an issue (or you see it in the news):

1. Open `tariff_pk.json` on GitHub → ✏️ Edit.
2. Change what moved, usually only:
   ```json
   "adjustments": {
     "fca_per_unit": 1.1086,
     "fca_label": "FCA for Aug 2026 (on Oct 2026 bills)",
     "qta_per_unit": 0.5194,
     "qta_label": "QTA Q2 CY2026 (Sep–Nov 2026 bills)"
   }
   ```
3. **Increase `version`.** Use the date + a counter: `2026112001` = 20 Nov 2026, update 01. Apps ignore a file whose version didn't go up.
4. Update `updated_at` (YYYY-MM-DD).
5. Commit. The **Validate tariff** check runs automatically — if it turns red, fix the error it shows. A broken file is never used by the apps; they keep the last good rates.

When NEPRA issues a new base tariff (new SRO for slab rates), update the `slabs` too, and `effective_from` and `sources`.

## Files
| File | What it is |
|---|---|
| `tariff_pk.json` | The rates the apps download |
| `scripts/validate_tariff.py` | Same checks the app does; run locally with `python scripts/validate_tariff.py` |
| `scripts/nepra_watch.py` | Finds new NEPRA PDFs |
| `.github/workflows/validate.yml` | Validates every change |
| `.github/workflows/nepra-watch.yml` | Daily NEPRA check → opens an issue when something new appears |

## Field reference
| Field | Meaning |
|---|---|
| `schema_version` | Format version. Keep `2` |
| `version` | Must increase with every change |
| `gst_percent` | Sales tax % on energy + fixed + surcharge + FCA + QTA |
| `tv_fee` | PTV fee per month (0 since July 2025) |
| `electricity_duty_percent` | Per province (0 since July 2025) |
| `adjustments.fca_per_unit` | Monthly fuel charges adjustment, Rs/unit (can be negative) |
| `adjustments.qta_per_unit` | Quarterly adjustment, Rs/unit (can be negative) |
| `lifeline` / `protected` / `unprotected` | Slab tables: `from`, `to` (null = no upper limit), `rate` Rs/unit, `fixed_per_kw` Rs/kW/month |
| `billing_mode` | `whole`, `previous_slab` or `incremental` |
| `fc_surcharge_per_unit` | FC / debt servicing surcharge, Rs/unit |
| `applies_adjustments` | Whether FCA and QTA apply to that category (false for lifeline) |

## Rate news on Home (optional)
Add a short message that appears on every app's Home screen in the "Rate news" card, in English and Urdu:
```json
"news": {
  "en": "FCA for October is +Rs 1.11/unit on November bills.",
  "ur": "نومبر کے بلوں پر اکتوبر کا FCA +1.11 روپے فی یونٹ ہے۔"
}
```
Remove the `news` block (or leave the text empty) to hide it. Remember to increase `version`.
