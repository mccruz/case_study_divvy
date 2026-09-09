# Reproducibility guide

This guide rebuilds the analysis from the public August 2022-July 2023 monthly trip files without committing raw data to Git.

> This guide is optional. Recruiters and other reviewers can understand the project through the [README](../README.md), [methodology](methodology.md), and [Tableau story](https://public.tableau.com/app/profile/mark.cruz4539/viz/CaseStudyDivvy/Story1) without installing software or downloading the dataset.

## 1. Prepare the local tools

### Download the repository

Install [Git](https://git-scm.com/downloads) if needed, then confirm `git --version` works.

```bash
git clone https://github.com/mccruz/case_study_divvy.git
cd case_study_divvy
```

All later commands assume the terminal is in the repository root. A quick check:

```bash
pwd
test -f sql/00_create_source_table.sql && echo "Repository files found"
```

### Install PostgreSQL

On macOS with [Homebrew](https://brew.sh/):

```bash
brew install postgresql@18
brew services start postgresql@18
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
psql --version
pg_isready
```

`pg_isready` should report that the local server is accepting connections. The `export PATH=...` line applies to the current terminal window; repeat it after opening a new terminal if `psql` is not found.

Windows and Linux users can use the [official PostgreSQL download instructions](https://www.postgresql.org/download/). The SQL workflow needs a PostgreSQL server plus the `psql`, `createdb`, and `pg_isready` command-line tools.

## 2. Get the source files

Download the 12 monthly files from the official [Divvy Data page](https://divvybikes.com/system-data). Review the current [Divvy Data License Agreement](https://divvybikes.com/data-license-agreement) before use.

Keep downloaded ZIP and CSV files outside this repository, or under the ignored `data/` directory. The repository does not redistribute the source dataset.

Expected months:

- August-December 2022
- January-July 2023

Each CSV is expected to contain these columns in this order:

```text
ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,
end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual
```

## 3. Create the local database and raw table

```bash
createdb divvy_case_study
psql -d divvy_case_study -f sql/00_create_source_table.sql
```

The raw table accepts nulls for profiling. The guarded importer requires a
start timestamp in the named source month; other missing fields remain available
for quality analysis rather than being silently discarded.

If `createdb` reports that `divvy_case_study` already exists, continue with the `psql` command. A successful table command prints `CREATE TABLE` or reports that the existing table was retained.

## 4. Import all 12 CSV files

Use the supplied importer rather than manual `\copy`. It accepts only the
expected `YYYYMM-divvy-tripdata.csv` names, checks the exact 13-column header,
copies and hashes a local snapshot before streaming those exact bytes to
PostgreSQL, rejects empty or mixed-month files, and records the source rows
plus a `source_imports` receipt in one database transaction.
It refuses a second import for an already-recorded month and never truncates a
table.

Run it once for every extracted file, in any order:

```bash
python3 scripts/import_divvy_month.py --database divvy_case_study \
  /absolute/path/to/202208-divvy-tripdata.csv
```

For a directory containing exactly the twelve expected files:

```bash
for file in /absolute/path/to/divvy-csvs/*-divvy-tripdata.csv; do
  python3 scripts/import_divvy_month.py --database divvy_case_study "$file"
done
```

Confirm that all twelve receipts exist before building the pipeline:

```bash
psql -d divvy_case_study -c 'TABLE source_imports ORDER BY source_month'
```

The importer does not offer a reset command. To begin again, create a new
database and rerun steps 3–4; this avoids accidentally mixing or destroying a
prior local import.

## 5. Run the pipeline

```bash
psql -d divvy_case_study -f data_cleaning.sql
```

This executes the numbered scripts in order:

1. confirms the raw table contract;
2. profiles source quality;
3. creates `prepared_rides` and `analysis_rides`;
4. emits analysis summaries; and
5. reports validation results and row accounting.

For easier inspection in pgAdmin, run the files under `sql/` individually in numeric order.

## 6. Legacy combined-table limitation

The 2023 project used a table named `"2022_08-2023_07"`. It has no per-file
filename, checksum, or import receipt, so it cannot satisfy this reproducible
import contract. Do not copy it into `raw_divvy_rides` and claim the result was
manifest-verified. Use the twelve source CSVs with the importer above for a
validated rerun. A legacy table can still be inspected separately for
historical comparison:

```sql
SELECT
    COUNT(*) AS legacy_rows,
    MIN(started_at) AS earliest_start,
    MAX(started_at) AS latest_start
FROM "2022_08-2023_07";
```

## 7. Interpret validation

`sql/04_validate_pipeline.sql` raises a database error (and makes `psql` exit
nonzero) if any import or build prerequisite fails. On success it reports
`PASS` for every integrity check. It requires nonempty raw, prepared, and
analysis relations; exactly one manifest receipt and at least one raw and
analysis row for every month from August 2022 through July 2023; no outside
months; matching raw/prepared row counts; and manifest row counts that match
the raw rows for each month. Its second result set accounts for:

- source rows;
- prepared rows;
- analysis rows;
- rows missing a core identifier or bike type;
- duplicate rows excluded;
- unsupported rider-category rows;
- invalid-duration rows excluded;
- rows without usable endpoints; and
- flagged operational-station rows.

The exact refreshed metrics are not committed because the historical dataset is not included and the corrected pipeline has not been rerun against the author's local snapshot. Any published result should include the query version, run date, source period, and row-accounting output.

## 8. Run synthetic SQL checks

The test fixture contains no Divvy source data. It verifies cross-midnight
duration, deterministic duplicate removal, endpoint and rider-type exclusions,
and that empty input, a missing month, a raw/prepared mismatch, and a missing
or row-count-mismatched manifest make validation fail. It creates a disposable
local database and refuses to use an existing database:

```bash
tests/run_sql_tests.sh
```

Pass a different unused test database name as the first argument if needed.

## Troubleshooting

| Message | Likely cause | Resolution |
| --- | --- | --- |
| `command not found: createdb` or `psql` | PostgreSQL is missing or its versioned Homebrew tools are not on the current path. | Complete step 1, including the `export PATH=...` line. |
| `connection ... failed` | PostgreSQL is installed but its local service is stopped. | Run `brew services start postgresql@18`, then confirm with `pg_isready`. |
| `No such file or directory` for a path under `sql/` | The terminal is not in the repository root. | Run `cd case_study_divvy` and confirm with the file check in step 1. |
| `database "divvy_case_study" already exists` | An earlier attempt already created the database. | Skip `createdb` and continue. |
| Validation exits with an error | A required receipt, source month, analysis month, or row-accounting invariant is missing. | Read the error, then create a fresh database and import each expected month exactly once with `scripts/import_divvy_month.py`. |
