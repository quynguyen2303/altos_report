# Altos Founder Pipeline Report

Internal HTML dashboard for triaging founder applications. Each card is a founder who applied + completed the Turing AI interview, with structured fields (problem, solution, traction, cap table, transcript) extracted by the interview pipeline.

**Aesthetic:** editorial monochrome matching altos.vc.
**Refresh:** Vercel cron hits `/api/data` hourly; the endpoint queries Postgres and Vercel's edge caches the result for an hour with `stale-while-revalidate`.

## Layout

```
.
├── index.html         # the report (vanilla JS + CSS, no build)
├── api/
│   ├── data.py        # Vercel Python serverless: runs query.sql, returns JSON
│   └── requirements.txt
├── query.sql          # the SQL (parameterized by :since, defaults to last 30 days)
├── vercel.json        # cron schedule + function config
├── refresh.py         # standalone CLI: writes data.json for non-Vercel hosting
└── deploy/            # legacy S3/GCS/k8s cron examples
```

## Deploy

### Vercel (production)

```bash
# 1. Install CLI (one time)
npm i -g vercel

# 2. Link project (interactive)
vercel link

# 3. Set the DB env var for prod + preview
vercel env add DATABASE_URL production
vercel env add DATABASE_URL preview

# 4. Ship
vercel --prod
```

Cron is declared in `vercel.json` (`crons: [{ path: "/api/data", schedule: "0 * * * *" }]`). The cron's job is to warm the edge cache — it hits the function once an hour so the next visitor gets a fresh response without paying for a cold DB query.

### Local dev

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

# Generate data.json once:
DATABASE_URL='postgres://...' .venv/bin/python refresh.py

# Serve:
python3 -m http.server 8765
open http://localhost:8765/
```

The HTML tries `/api/data` first and falls back to `data.json` — works in both modes.

## Data flow

```
Postgres (altos_application + altos_attempts + meeting)
        │
        │ query.sql  (last 30 days, COMPLETED | PARTIALLY_COMPLETE)
        ▼
api/data.py  ──►  Vercel CDN  ──►  index.html (browser)
                       ▲
                       │
              Vercel Cron (hourly: keeps cache warm)
```

## Security note

This report exposes founder PII (email, phone, passport/visa status, cap table). The URL is unlisted — keep it that way. If it ever needs to be shared with anyone outside the Altos team, add Vercel Password Protection (Pro feature) or move it behind SSO before sharing.
