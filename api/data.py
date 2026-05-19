"""Vercel serverless function: returns founder pipeline as JSON.

Reads query.sql, executes against DATABASE_URL, returns the result with a
CDN cache header so Vercel's edge serves repeats for free until cron busts
the cache (see vercel.json `crons`).
"""
import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "query.sql").read_text()


def fetch_payload() -> dict:
    url = os.environ["DATABASE_URL"]
    with psycopg.connect(url, row_factory=dict_row, connect_timeout=10) as conn:
        rows = conn.execute(SQL, {"since": None}).fetchall()
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "count": len(rows),
        "founders": [{k: (v if v != "" else None) for k, v in r.items()} for r in rows],
    }


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            payload = fetch_payload()
            body = json.dumps(payload, default=str, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            # CDN caches for 1 hour; allow stale-while-revalidate for smooth refresh.
            self.send_header(
                "Cache-Control",
                "public, s-maxage=3600, stale-while-revalidate=86400",
            )
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as exc:  # noqa: BLE001
            body = json.dumps({"error": str(exc)}).encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
