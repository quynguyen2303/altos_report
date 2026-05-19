#!/usr/bin/env bash
# Upload report artifacts. Point BUCKET at your S3 bucket / GCS path.
# Usage: ./deploy/upload.sh [s3|gcs|netlify]
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-s3}"
BUCKET="${BUCKET:-altos-internal/report}"

case "$TARGET" in
  s3)
    aws s3 cp ./data.json  "s3://${BUCKET}/data.json"  --cache-control "max-age=60,public"
    aws s3 cp ./index.html "s3://${BUCKET}/index.html" --cache-control "max-age=3600,public"
    ;;
  gcs)
    gsutil -h "Cache-Control:max-age=60,public"   cp ./data.json  "gs://${BUCKET}/data.json"
    gsutil -h "Cache-Control:max-age=3600,public" cp ./index.html "gs://${BUCKET}/index.html"
    ;;
  netlify)
    # One-shot deploy of the report directory.
    netlify deploy --dir=. --prod
    ;;
  *)
    echo "unknown target: $TARGET (expected s3|gcs|netlify)" >&2
    exit 2
    ;;
esac

echo "uploaded data.json + index.html → ${TARGET}:${BUCKET}"
