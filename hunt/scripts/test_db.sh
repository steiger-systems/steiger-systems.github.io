#!/usr/bin/env bash
# Applies all migrations to a fresh local Postgres database and runs the SQL tests.
# Needs a local Postgres (psql) with superuser access. Usage:
#   PGUSER=postgres scripts/test_db.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${HUNT_TEST_DB:-hunt_test}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1 -d "$DB")

dropdb --if-exists "$DB"
createdb "$DB"
"${PSQL[@]}" -f supabase/sql-tests/00_shim.sql
for f in supabase/migrations/*.sql; do
  echo "migrate: $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
for f in supabase/sql-tests/[1-9]*.sql; do
  echo "test: $(basename "$f")"
  "${PSQL[@]}" -o /dev/null -f "$f" 2>&1 | sed 's/^psql:[^ ]* NOTICE:  /  /'
done
echo "All database tests passed."
