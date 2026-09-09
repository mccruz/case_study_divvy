#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
db_name="${1:-divvy_case_study_test}"
maintenance_db="${PGDATABASE:-postgres}"

if [[ ! "$db_name" =~ ^[A-Za-z_][A-Za-z0-9_]{0,62}$ ]]; then
  echo "Test database name must be a simple PostgreSQL identifier." >&2
  exit 2
fi

if ! command -v createdb >/dev/null || ! command -v dropdb >/dev/null || ! command -v psql >/dev/null; then
  echo "PostgreSQL client tools (createdb, dropdb, psql) are required." >&2
  exit 2
fi
if psql -d "$maintenance_db" -Atqc 'SELECT 1' >/dev/null 2>&1; then :; else
  echo "A local PostgreSQL server accepting psql connections is required." >&2
  exit 2
fi
if psql -X -v ON_ERROR_STOP=1 -d "$maintenance_db" -Atqc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
  echo "Refusing to use existing database: $db_name" >&2
  exit 2
fi

createdb -- "$db_name"
cleanup() { dropdb --if-exists -- "$db_name"; }
trap cleanup EXIT

psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/sql/00_create_source_table.sql"
python3 "$repo_root/tests/test_importer.py" --database "$db_name"
psql -X -v ON_ERROR_STOP=1 -d "$db_name" -c 'TRUNCATE raw_divvy_rides, source_imports;' >/dev/null
psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/tests/fixtures.sql"
psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/sql/02_build_prepared_rides.sql"
psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/tests/assertions.sql"
psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/sql/04_validate_pipeline.sql" >/dev/null
psql -X -v ON_ERROR_STOP=1 -d "$db_name" -c 'TRUNCATE raw_divvy_rides, source_imports;' >/dev/null

for scenario in empty_input missing_month source_prepared_mismatch missing_manifest manifest_row_count_mismatch; do
  psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/tests/fixtures.sql" >/dev/null
  psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/sql/02_build_prepared_rides.sql" >/dev/null
  case "$scenario" in
    empty_input) expected_error='raw_divvy_rides is empty' ;;
    missing_month) expected_error='raw_divvy_rides is missing required months' ;;
    source_prepared_mismatch) expected_error='source/prepared row mismatch' ;;
    missing_manifest) expected_error='source_imports must contain exactly one receipt' ;;
    manifest_row_count_mismatch) expected_error='source_imports row_count does not match raw rows' ;;
  esac
  if scenario_output="$(psql -X -v ON_ERROR_STOP=1 -d "$db_name" -f "$repo_root/tests/$scenario.sql" 2>&1)"; then
    echo "Expected validation failure for $scenario" >&2
    exit 1
  fi
  if [[ "$scenario_output" != *"$expected_error"* ]]; then
    echo "Unexpected failure for $scenario: $scenario_output" >&2
    exit 1
  fi
  psql -X -v ON_ERROR_STOP=1 -d "$db_name" -c 'TRUNCATE raw_divvy_rides, source_imports;' >/dev/null
done

echo "SQL fixtures and validation-failure checks passed."
