#!/usr/bin/env bash
# Start the Web UI on loopback; connect through an authorized SSH tunnel.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
: "${APP_CONFIG_FILE:?Set APP_CONFIG_FILE to the private app-config.json path}"
PORT="${APP_PORT:-8767}"
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  echo 'APP_PORT must be an unprivileged TCP port' >&2
  exit 1
fi
mkdir -p output/week7
exec output/week7/.venv/bin/gunicorn \
  --bind "127.0.0.1:$PORT" --workers 2 --threads 4 \
  --pid output/week7/web.pid \
  --access-logfile output/week7/access.log \
  --error-logfile output/week7/error.log \
  app.wsgi:app
