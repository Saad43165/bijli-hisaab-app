#!/usr/bin/env python3
"""Watches NEPRA's tariff pages and lists new notification PDFs.

Run daily by .github/workflows/nepra-watch.yml. When NEPRA publishes a new
FCA / QTA / tariff SRO, the workflow opens a GitHub issue with the links so
you know to update tariff_pk.json. NEPRA publishes scanned PDFs, so the
numbers themselves still need a human (or Claude) to read them.
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

PAGES = [
    # Lists XWDISCO and K-Electric notifications, FCA and quarterly adjustments.
    "https://nepra.org.pk/tariff/Distribution%20K-Electric.php",
]
SEEN_FILE = "nepra_seen.json"
RELEVANT = re.compile(r"FCA|MFPA|FUEL|QUARTER|QTR|PERIODIC|S\.?R\.?O|RATIONALI|UNIFORM|CONSUMER END", re.I)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "bijli-bachao-rates-watch/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", errors="replace")


def pdf_links(page_url, html):
    links = set()
    for href in re.findall(r'href\s*=\s*["\']([^"\']+\.pdf)["\']', html, re.I):
        links.add(urllib.parse.urljoin(page_url, href.strip()))
    return links


def main():
    found = set()
    for page in PAGES:
        try:
            found |= pdf_links(page, fetch(page))
        except Exception as e:  # keep going if one page is down
            print(f"::warning::Could not read {page}: {e}")
    if not found:
        print("::warning::No PDF links found — NEPRA page may have changed")
        return

    first_run = not os.path.exists(SEEN_FILE)
    seen = set() if first_run else set(json.load(open(SEEN_FILE)))
    new = sorted(u for u in found - seen if RELEVANT.search(urllib.parse.unquote(u)))

    json.dump(sorted(seen | found), open(SEEN_FILE, "w"), indent=1)

    if first_run:
        print(f"First run: recorded {len(found)} existing PDFs, no issue opened.")
        return
    if not new:
        print("No new tariff notifications.")
        return

    lines = ["NEPRA published new tariff documents. Check whether FCA, QTA or slab rates changed,",
             "then update `tariff_pk.json` (and increase `version`).", ""]
    for u in new:
        name = urllib.parse.unquote(u.rsplit("/", 1)[-1])
        lines.append(f"- [{name}]({u})")
    with open(os.environ.get("GITHUB_OUTPUT", os.devnull), "a") as out:
        out.write("new=true\n")
    with open("issue_body.md", "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    sys.exit(main())
