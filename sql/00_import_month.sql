-- Called only by scripts/import_divvy_month.py. The temporary staging table
-- keeps the CSV load and receipt insertion inside one transaction.
\set ON_ERROR_STOP on

BEGIN;

LOCK TABLE raw_divvy_rides, source_imports IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMPORARY TABLE import_divvy_metadata ON COMMIT DROP AS
SELECT
    :'source_month'::date AS source_month,
    :'filename'::text AS filename,
    :'sha256'::text AS sha256;

DO $$
DECLARE
    target_month date;
BEGIN
    SELECT source_month INTO target_month FROM import_divvy_metadata;
    IF EXISTS (SELECT 1 FROM source_imports WHERE source_month = target_month) THEN
        RAISE EXCEPTION 'refusing duplicate import for source month %', target_month;
    END IF;
END;
$$;

CREATE TEMPORARY TABLE import_divvy_month (LIKE raw_divvy_rides) ON COMMIT DROP;
-- The Python importer snapshots and hashes the file, then streams those exact
-- bytes to this COPY command. This avoids shell/path quoting and TOCTOU gaps.
\copy import_divvy_month FROM PSTDIN WITH (FORMAT csv, HEADER true)

DO $$
DECLARE
    staged_rows bigint;
    wrong_month_rows bigint;
    target_month date;
BEGIN
    SELECT source_month INTO target_month FROM import_divvy_metadata;
    SELECT COUNT(*) INTO staged_rows FROM import_divvy_month;
    IF staged_rows = 0 THEN
        RAISE EXCEPTION 'refusing empty source file for %', target_month;
    END IF;
    SELECT COUNT(*) INTO wrong_month_rows
    FROM import_divvy_month
    WHERE started_at IS NULL
       OR date_trunc('month', started_at)::date <> target_month;
    IF wrong_month_rows > 0 THEN
        RAISE EXCEPTION 'source file for % contains % null or other-month started_at rows', target_month, wrong_month_rows;
    END IF;
END;
$$;

INSERT INTO raw_divvy_rides SELECT * FROM import_divvy_month;

INSERT INTO source_imports (source_month, filename, sha256, row_count)
SELECT source_month, filename, sha256, (SELECT COUNT(*) FROM import_divvy_month)
FROM import_divvy_metadata;

COMMIT;
