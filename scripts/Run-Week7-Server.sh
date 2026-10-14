#!/usr/bin/env bash
# Build a new v1.0 sample database and prepare a private Web application config.
set -Eeuo pipefail
: "${DB_CONTAINER:?Set DB_CONTAINER privately to the existing SQL Server container}"
cd "$(dirname "$0")/.."
mkdir -p output/week7
LOG="output/week7/deploy-$(date +%Y%m%d%H%M%S).txt"
exec > >(tee "$LOG") 2>&1

if ! command -v uv >/dev/null 2>&1; then
  echo 'uv is required to create the isolated Python environment' >&2
  exit 1
fi
if [[ ! -x output/week7/.venv/bin/python ]]; then
  uv venv --python python3.12 output/week7/.venv
fi
uv pip install --python output/week7/.venv/bin/python -r app/requirements.txt

bash scripts/Run-Week6-Server.sh | tee output/week7/week6-stage.txt
DB_NAME="$(sed -n 's/^STAGING_DATABASE \(DataBaseLab_Week6_[A-Za-z0-9_]*\)$/\1/p' output/week7/week6-stage.txt | tail -1)"
if [[ -z "$DB_NAME" ]] || ! grep -q "^WEEK6_SERVER_PASS $DB_NAME$" output/week7/week6-stage.txt; then
  echo 'Week6 database preparation did not pass; stopping before Web deployment' >&2
  exit 1
fi

CONFIG_DIR="${APP_PRIVATE_DIR:-$HOME/.config/database-lab/week7-${DB_NAME##DataBaseLab_Week6_}}"
output/week7/.venv/bin/python -m app.bootstrap init --database "$DB_NAME" --directory "$CONFIG_DIR"
CONFIG_FILE="$CONFIG_DIR/app-config.json"

sqlcmd_master() {
  docker exec -i "$DB_CONTAINER" sh -lc \
    'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -I -b -r 1 -d master -i /dev/stdin'
}
sqlcmd_app() {
  docker exec -i "$DB_CONTAINER" sh -lc \
    'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -I -b -r 1 -d "$1" -i /dev/stdin' sh "$DB_NAME"
}
output/week7/.venv/bin/python -m app.bootstrap login-sql --config "$CONFIG_FILE" | sqlcmd_master
output/week7/.venv/bin/python -m app.bootstrap grants-sql --config "$CONFIG_FILE" | sqlcmd_app

printf '%s\n' "$CONFIG_FILE" > output/week7/config-path.txt
chmod 600 output/week7/config-path.txt
printf 'WEEK7_DEPLOY_PREP_PASS %s\n' "$DB_NAME"
printf 'PRIVATE_CONFIG %s\n' "$CONFIG_FILE"
printf 'PRIVATE_DEMO_CREDENTIALS %s\n' "$CONFIG_DIR/demo-credentials.txt"
