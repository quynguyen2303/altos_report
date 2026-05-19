#!/usr/bin/env bash
# Local cron entrypoint: refresh data.json from Postgres, commit, push.
# Vercel auto-redeploys on push to main.
#
# Required env:
#   DATABASE_URL     - Postgres connection string (export in your shell or .env)
# Optional env:
#   ALTOS_BRANCH     - branch to push to (default: main)
#   ALTOS_REMOTE     - remote name (default: origin)
#   ALTOS_PYTHON     - path to python (default: .venv/bin/python)
#
# Add to crontab (`crontab -e`):
#   0 * * * * cd /Users/quy/claude/altos_report && ./refresh-and-push.sh >> /tmp/altos_refresh.log 2>&1

set -euo pipefail

cd "$(dirname "$0")"

# Load .env if present (DATABASE_URL etc.)
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

: "${DATABASE_URL:?DATABASE_URL is not set}"
PY="${ALTOS_PYTHON:-.venv/bin/python}"
REMOTE="${ALTOS_REMOTE:-origin}"
BRANCH="${ALTOS_BRANCH:-main}"

# 1. Pull latest in case index.html or query.sql moved.
git pull --rebase --autostash "$REMOTE" "$BRANCH" >/dev/null

# 2. Regenerate data.json.
"$PY" refresh.py

# 3. Commit + push only if the snapshot changed.
if git diff --quiet -- data.json; then
  echo "$(date -u +%FT%TZ) no changes"
  exit 0
fi

COUNT=$("$PY" -c "import json; print(json.load(open('data.json'))['count'])")
TS=$(date -u +%FT%TZ)

git add data.json
git -c user.email="report-bot@altos.local" \
    -c user.name="altos-report-bot" \
    commit -m "data: refresh ${TS} (${COUNT} founders)" >/dev/null
git push "$REMOTE" "$BRANCH" >/dev/null

echo "${TS} pushed refresh (${COUNT} founders)"
