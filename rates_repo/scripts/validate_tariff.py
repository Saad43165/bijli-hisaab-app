#!/usr/bin/env python3
"""Validates tariff_pk.json with the same rules the app uses.

The app silently ignores an invalid file, so this check (run by GitHub
Actions on every push) tells you immediately if you made a typo.

Usage: python scripts/validate_tariff.py [path/to/tariff_pk.json] [--previous-version N]
"""
import json
import sys

SUPPORTED_SCHEMA = 2


def fail(msg):
    print(f"::error::{msg}")
    sys.exit(1)


def check_category(name, cat, must_be_open_ended):
    slabs = cat.get("slabs") or []
    if not slabs:
        fail(f"{name}: no slabs")
    if cat.get("billing_mode") not in ("whole", "previous_slab", "incremental"):
        fail(f"{name}: billing_mode must be whole, previous_slab or incremental")
    fc = cat.get("fc_surcharge_per_unit", 0)
    if not (0 <= fc <= 30):
        fail(f"{name}: fc_surcharge_per_unit out of range")
    expected_from = 1
    for i, s in enumerate(slabs):
        frm, to, rate = s.get("from"), s.get("to"), s.get("rate")
        if frm != expected_from:
            fail(f"{name}: slab #{i + 1} should start at {expected_from}, got {frm}")
        if not isinstance(rate, (int, float)) or not (0 < rate <= 500):
            fail(f"{name}: slab #{i + 1} rate out of range: {rate}")
        if not (0 <= s.get("fixed_per_kw", 0) <= 5000):
            fail(f"{name}: slab #{i + 1} fixed_per_kw out of range")
        if to is None:
            if i != len(slabs) - 1:
                fail(f"{name}: only the last slab may have \"to\": null")
            break
        if to < frm:
            fail(f"{name}: slab #{i + 1} has to < from")
        expected_from = to + 1
    if must_be_open_ended and slabs[-1].get("to") is not None:
        fail(f"{name}: last slab must have \"to\": null")


def main():
    args = sys.argv[1:]
    path = "tariff_pk.json"
    previous = None
    if args and not args[0].startswith("--"):
        path = args.pop(0)
    if "--previous-version" in args:
        previous = int(args[args.index("--previous-version") + 1])

    try:
        with open(path, encoding="utf-8") as f:
            t = json.load(f)
    except json.JSONDecodeError as e:
        fail(f"Not valid JSON: {e}")

    for key in ("schema_version", "version", "id", "name", "protected", "unprotected"):
        if key not in t:
            fail(f"Missing \"{key}\"")
    if t["schema_version"] > SUPPORTED_SCHEMA:
        fail(f"schema_version {t['schema_version']} is newer than the app supports ({SUPPORTED_SCHEMA})")
    if not isinstance(t["version"], int) or t["version"] <= 0:
        fail("version must be a positive whole number, e.g. 2026112001")
    if previous is not None and t["version"] <= previous:
        fail(f"version must increase (was {previous}, now {t['version']}). Apps ignore files that don't.")
    if not (50 <= t.get("protected_threshold_units", 200) <= 1000):
        fail("protected_threshold_units out of range")
    if not (0 <= t.get("gst_percent", 18) <= 40):
        fail("gst_percent out of range")
    if not (0 <= t.get("tv_fee", 0) <= 500):
        fail("tv_fee out of range")
    adj = t.get("adjustments", {})
    for key in ("fca_per_unit", "qta_per_unit"):
        if abs(adj.get(key, 0)) > 30:
            fail(f"adjustments.{key} out of range")

    known = {"LESCO", "IESCO", "FESCO", "GEPCO", "MEPCO", "PESCO", "HAZECO", "TESCO",
             "HESCO", "SEPCO", "QESCO", "K-Electric", "AJK-ED", "GB-WPD"}
    for code, o in (t.get("company_overrides") or {}).items():
        if code not in known:
            fail(f"company_overrides: unknown company code {code!r} (use one of {sorted(known)})")
        for key in ("fca_per_unit", "qta_per_unit"):
            if key in o and (not isinstance(o[key], (int, float)) or abs(o[key]) > 30):
                fail(f"company_overrides.{code}.{key} out of range")
        if "gst_percent" in o and not (0 <= o["gst_percent"] <= 40):
            fail(f"company_overrides.{code}.gst_percent out of range")

    check_category("protected", t["protected"], False)
    check_category("unprotected", t["unprotected"], True)
    if "lifeline" in t:
        check_category("lifeline", t["lifeline"], False)

    print(f"OK: version {t['version']} ({t.get('updated_at', '?')}) — "
          f"FCA {adj.get('fca_per_unit', 0)}, QTA {adj.get('qta_per_unit', 0)}")


if __name__ == "__main__":
    main()
