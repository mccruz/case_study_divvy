-- Post-build validation. A PASS row has zero failures.

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
