#!/usr/bin/env python3
"""Run the Altos founder query and write data.json next to index.html.

Usage:
    DATABASE_URL=postgres://user:pass@host/db ./refresh.py [--since 2026-01-01]

Exits non-zero on any failure so cron will alert and we never overwrite
data.json with stale or partial data.
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

HERE = Path(__file__).parent
SQL = (HERE / "query.sql").read_text()


def main() -> int:
    args = parse_args()
    url = os.environ.get("DATABASE_URL")
    if not url:
        print("DATABASE_URL not set", file=sys.stderr)
        return 2

    with psycopg.connect(url, row_factory=dict_row) as conn:
        rows = conn.execute(SQL, {"since": args.since}).fetchall()

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "since": args.since,
        "count": len(rows),
        "founders": [normalize(r) for r in rows],
    }

    out = HERE / "data.json"
    tmp = out.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, default=str, ensure_ascii=False, indent=2))
    tmp.replace(out)
    print(f"wrote {out} · {len(rows)} founders", file=sys.stderr)
    return 0


def normalize(r: dict) -> dict:
    return {k: (v if v != "" else None) for k, v in r.items()}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--since", default=None, help="ISO date; defaults to 30 days ago.")
    return p.parse_args()


if __name__ == "__main__":
    sys.exit(main())
