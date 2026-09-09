-- Post-build validation. Any failed prerequisite raises a database error so
-- psql exits nonzero under ON_ERROR_STOP, rather than merely printing FAIL.
\set ON_ERROR_STOP on

DO $$
DECLARE
    expected_months constant date[] := ARRAY[
        DATE '2022-08-01', DATE '2022-09-01', DATE '2022-10-01',
        DATE '2022-11-01', DATE '2022-12-01', DATE '2023-01-01',
        DATE '2023-02-01', DATE '2023-03-01', DATE '2023-04-01',
        DATE '2023-05-01', DATE '2023-06-01', DATE '2023-07-01'
    ];
    raw_count bigint;
    prepared_count bigint;
    analysis_count bigint;
    manifest_count bigint;
    outside_raw bigint;
    outside_analysis bigint;
    missing_raw date[];
    missing_analysis date[];
    missing_manifest date[];
    integrity_failures bigint;
BEGIN
    SELECT COUNT(*) INTO raw_count FROM raw_divvy_rides;
    SELECT COUNT(*) INTO prepared_count FROM prepared_rides;
    SELECT COUNT(*) INTO analysis_count FROM analysis_rides;
    SELECT COUNT(*) INTO manifest_count FROM source_imports;

    IF raw_count = 0 THEN
        RAISE EXCEPTION 'validation failed: raw_divvy_rides is empty';
    END IF;
    IF prepared_count = 0 THEN
        RAISE EXCEPTION 'validation failed: prepared_rides is empty';
    END IF;
    IF raw_count <> prepared_count THEN
        RAISE EXCEPTION 'validation failed: source/prepared row mismatch (% vs %)', raw_count, prepared_count;
    END IF;
    IF analysis_count = 0 THEN
        RAISE EXCEPTION 'validation failed: analysis_rides is empty';
    END IF;

    SELECT COUNT(*) INTO outside_raw
    FROM raw_divvy_rides
    WHERE started_at IS NULL
       OR date_trunc('month', started_at)::date <> ALL (expected_months);
    IF outside_raw > 0 THEN
        RAISE EXCEPTION 'validation failed: raw_divvy_rides contains % null or out-of-scope month rows', outside_raw;
    END IF;

    SELECT COUNT(*) INTO outside_analysis
    FROM analysis_rides
    WHERE date_trunc('month', started_at)::date <> ALL (expected_months);
    IF outside_analysis > 0 THEN
        RAISE EXCEPTION 'validation failed: analysis_rides contains % out-of-scope month rows', outside_analysis;
    END IF;

    SELECT array_agg(month_start ORDER BY month_start) INTO missing_raw
    FROM (
        SELECT month_start
        FROM unnest(expected_months) AS month_start
        EXCEPT
        SELECT date_trunc('month', started_at)::date FROM raw_divvy_rides
    ) AS missing;
    IF missing_raw IS NOT NULL THEN
        RAISE EXCEPTION 'validation failed: raw_divvy_rides is missing required months: %', missing_raw;
    END IF;

    SELECT array_agg(month_start ORDER BY month_start) INTO missing_analysis
    FROM (
        SELECT month_start
        FROM unnest(expected_months) AS month_start
        EXCEPT
        SELECT date_trunc('month', started_at)::date FROM analysis_rides
    ) AS missing;
    IF missing_analysis IS NOT NULL THEN
        RAISE EXCEPTION 'validation failed: analysis_rides is missing required months: %', missing_analysis;
    END IF;

    SELECT array_agg(month_start ORDER BY month_start) INTO missing_manifest
    FROM (
        SELECT month_start
        FROM unnest(expected_months) AS month_start
        EXCEPT
        SELECT source_month FROM source_imports
    ) AS missing;
    IF manifest_count <> 12 OR missing_manifest IS NOT NULL OR EXISTS (
        SELECT 1 FROM source_imports WHERE source_month <> ALL (expected_months)
    ) THEN
        RAISE EXCEPTION 'validation failed: source_imports must contain exactly one receipt for each required month (count %, missing %)', manifest_count, missing_manifest;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM source_imports AS manifest
        LEFT JOIN (
            SELECT date_trunc('month', started_at)::date AS source_month, COUNT(*) AS raw_rows
            FROM raw_divvy_rides
            GROUP BY 1
        ) AS raw_month ON raw_month.source_month = manifest.source_month
        WHERE manifest.row_count IS DISTINCT FROM raw_month.raw_rows
    ) THEN
        RAISE EXCEPTION 'validation failed: source_imports row_count does not match raw rows for every month';
    END IF;

    SELECT COUNT(*) INTO integrity_failures
    FROM (
        SELECT ride_id FROM analysis_rides GROUP BY ride_id HAVING COUNT(*) > 1
    ) AS duplicate_ids;
    IF integrity_failures > 0 THEN
        RAISE EXCEPTION 'validation failed: duplicate ride_id in analysis_rides (%)', integrity_failures;
    END IF;

    SELECT COUNT(*) INTO integrity_failures
    FROM analysis_rides
    WHERE ride_id IS NULL OR rideable_type IS NULL OR started_at IS NULL OR ended_at IS NULL;
    IF integrity_failures > 0 THEN
        RAISE EXCEPTION 'validation failed: missing required identifier, type, or timestamp (%)', integrity_failures;
    END IF;

    SELECT COUNT(*) INTO integrity_failures FROM analysis_rides WHERE NOT has_valid_duration;
    IF integrity_failures > 0 THEN RAISE EXCEPTION 'validation failed: duration below 60 seconds (%)', integrity_failures; END IF;
    SELECT COUNT(*) INTO integrity_failures FROM analysis_rides WHERE NOT has_supported_rider_type;
    IF integrity_failures > 0 THEN RAISE EXCEPTION 'validation failed: unsupported rider type (%)', integrity_failures; END IF;
    SELECT COUNT(*) INTO integrity_failures FROM analysis_rides WHERE NOT has_start_endpoint;
    IF integrity_failures > 0 THEN RAISE EXCEPTION 'validation failed: missing usable start endpoint (%)', integrity_failures; END IF;
    SELECT COUNT(*) INTO integrity_failures FROM analysis_rides WHERE NOT has_end_endpoint;
    IF integrity_failures > 0 THEN RAISE EXCEPTION 'validation failed: missing usable end endpoint (%)', integrity_failures; END IF;
    SELECT COUNT(*) INTO integrity_failures FROM analysis_rides WHERE is_operational_station;
    IF integrity_failures > 0 THEN RAISE EXCEPTION 'validation failed: operational station included (%)', integrity_failures; END IF;
END;
$$;

WITH checks AS (
    SELECT
        'duplicate ride_id in analysis_rides'::text AS check_name,
        COUNT(*)::bigint AS failure_count
    FROM (
        SELECT ride_id
        FROM analysis_rides
        GROUP BY ride_id
        HAVING COUNT(*) > 1
    ) AS duplicate_ids

    UNION ALL

    SELECT
        'missing required identifier, type, or timestamp',
        COUNT(*)::bigint
    FROM analysis_rides
    WHERE ride_id IS NULL
       OR rideable_type IS NULL
       OR started_at IS NULL
       OR ended_at IS NULL

    UNION ALL

    SELECT
        'duration below 60 seconds',
        COUNT(*)::bigint
    FROM analysis_rides
    WHERE NOT has_valid_duration

    UNION ALL

    SELECT
        'unsupported rider type',
        COUNT(*)::bigint
    FROM analysis_rides
    WHERE NOT has_supported_rider_type

    UNION ALL

    SELECT
        'missing usable start endpoint',
        COUNT(*)::bigint
    FROM analysis_rides
    WHERE NOT has_start_endpoint

    UNION ALL

    SELECT
        'missing usable end endpoint',
        COUNT(*)::bigint
    FROM analysis_rides
    WHERE NOT has_end_endpoint

    UNION ALL

    SELECT
        'operational station included',
        COUNT(*)::bigint
    FROM analysis_rides
    WHERE is_operational_station
)
SELECT
    check_name,
    failure_count,
    CASE WHEN failure_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks
ORDER BY check_name;

-- Row-accounting summary for audit and documentation.
SELECT
    (SELECT COUNT(*) FROM raw_divvy_rides) AS source_rows,
    (SELECT COUNT(*) FROM prepared_rides) AS prepared_rows,
    (SELECT COUNT(*) FROM analysis_rides) AS analysis_rows,
    (
        SELECT COUNT(*)
        FROM prepared_rides
        WHERE ride_id IS NULL OR rideable_type IS NULL
    ) AS missing_core_rows_excluded,
    (
        SELECT COUNT(*)
        FROM prepared_rides
        WHERE ride_id_row_number > 1
    ) AS duplicate_rows_excluded,
    (
        SELECT COUNT(*)
        FROM prepared_rides
        WHERE NOT COALESCE(has_supported_rider_type, false)
    ) AS unsupported_rider_rows_excluded,
    (
        SELECT COUNT(*)
        FROM prepared_rides
        WHERE NOT has_valid_duration
    ) AS invalid_duration_rows_excluded,
    (
        SELECT COUNT(*)
        FROM prepared_rides
        WHERE NOT has_start_endpoint OR NOT has_end_endpoint
    ) AS endpoint_rows_excluded,
    (
        SELECT COUNT(*)
        FROM prepared_rides
        WHERE is_operational_station
    ) AS operational_station_rows_excluded;
