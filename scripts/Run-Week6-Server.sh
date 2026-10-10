#!/usr/bin/env bash
# Run on an authorized Linux host with an existing SQL Server 2022 container.
# Set DB_CONTAINER privately; original output stays in ignored output/week6/.
set -Eeuo pipefail
: "${DB_CONTAINER:?Set DB_CONTAINER to the existing SQL Server container name}"
cd "$(dirname "$0")/.."
mkdir -p output/week6
DB="DataBaseLab_Week6_$(date +%Y%m%d%H%M%S)"
LOG="output/week6/run-$DB.txt"
exec > >(tee "$LOG") 2>&1

run_query() {
  local db="$1" query="$2"
  docker exec "$DB_CONTAINER" sh -lc 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -I -b -r 1 -d "$1" -Q "$2"' sh "$db" "$query"
}
run_file() {
  local db="$1" file="$2"
  printf 'RUN %s\n' "$file"
  docker exec -i "$DB_CONTAINER" sh -lc 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -I -b -r 1 -y 0 -d "$1" -i /dev/stdin' sh "$db" < "$file"
}

printf 'STAGING_DATABASE %s\n' "$DB"
run_query master "IF DB_ID(N'$DB') IS NOT NULL THROW 51900, 'Staging database already exists.', 1; EXEC(N'CREATE DATABASE [$DB]');"
for file in \
  sql/week3/01-schema.sql \
  sql/week3/02-seed.sql \
  sql/week3/04-verify.sql \
  sql/week3/03-crud.sql \
  sql/week3/04-verify.sql \
  sql/week4/constraint.sql \
  sql/week3/05-constraint-tests.sql \
  sql/week4/query.sql \
  sql/week4/view.sql \
  sql/week4/role.sql \
  sql/week5/verify-er.sql \
  sql/week3/04-verify.sql \
  sql/week6/migration.sql \
  sql/week4/role.sql \
  sql/week6/regression.sql
do
  run_file "$DB" "$file"
done
printf 'WEEK6_SERVER_PASS %s\n' "$DB"
