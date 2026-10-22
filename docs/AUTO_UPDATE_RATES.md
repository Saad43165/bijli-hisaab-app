# Automatic rate updates

Electricity rates in Pakistan change often: the **FCA** every month, the **QTA** every quarter, and the slab rates when NEPRA issues a new SRO. The app updates itself so you never have to change code or release a new version for that.

## How it works
```
 rates repo on GitHub            every phone running the app
 ┌────────────────────┐   HTTPS   ┌──────────────────────────────┐
 │ tariff_pk.json     │ ────────▶ │ checks on start / resume     │
 │ (you edit this)    │           │ at most every 12 hours       │
 └────────────────────┘           │ validates → keeps the newest │
         ▲                        │ falls back to built-in rates │
         │ issue: "new NEPRA      └──────────────────────────────┘
         │ notification"
 ┌────────────────────┐
 │ daily NEPRA watch  │  (GitHub Actions)
 └────────────────────┘
```
- The app ships with rates built in (`assets/config/tariff_pk.json`), so it works offline from day one.
- On start and whenever it's reopened (max every 12 h), it downloads `tariff_pk.json` from your repo.
- The file is **validated** (slabs continuous, rates in sane ranges, supported schema). A broken file is ignored and the app keeps the last good rates.
- The app keeps whichever tariff has the **highest `version`** — built-in or downloaded — so an old file never replaces newer rates.
- Users can see the status in **More → Electricity rates** and press **Check now**. They can turn auto-update off to enter their own rates.
- Only the rates file is downloaded. Nothing about the user is sent.

## One-time setup (10 minutes)
1. Create a **public** GitHub repo named `bijli-hisaab-rates`.
2. Upload everything inside the `rates_repo/` folder of this project to it (keep the `.github` folder).
3. In the repo: **Settings → Actions → General → Workflow permissions → Read and write permissions** → Save. (Lets the NEPRA watcher open issues and save its list.)
4. Open `lib/core/config/remote_config.dart` and replace `Saad43165` with your GitHub username. Rebuild the app.
5. In the repo's **Actions** tab, run **Watch NEPRA for new rates** once by hand. The first run just records existing documents.

Test it: in the app go to **More → Electricity rates → Check now**. It should say "You have the latest rates".

## Every month
When NEPRA announces the new FCA (usually the 5th–10th), the watcher opens a GitHub issue. Then:
1. Edit `tariff_pk.json` on GitHub: update `adjustments.fca_per_unit` and `fca_label` (and the QTA at the start of each quarter).
2. Increase `version` (e.g. `2026112001`) and `updated_at`.
3. Commit. The validation check runs; when it's green, phones pick it up within 12 hours.

Full field reference: `rates_repo/README.md`.

## Why not read NEPRA's PDFs automatically?
NEPRA publishes decisions as **scanned PDFs** with no text layer, and the format changes. Parsing them unattended would eventually put a wrong number into every user's bill estimate. So the detection is automatic, and a human confirms the number — a 2-minute edit. The validator and the "highest version wins" rule protect users from mistakes.
