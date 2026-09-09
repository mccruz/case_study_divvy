DO $$
BEGIN
    IF (SELECT trip_duration_minutes FROM prepared_rides WHERE ride_id = 'midnight') IS DISTINCT FROM 90.00 THEN
        RAISE EXCEPTION 'midnight duration was not calculated from full timestamps';
    END IF;
    IF (SELECT COUNT(*) FROM analysis_rides WHERE ride_id = 'duplicate') <> 1 THEN
        RAISE EXCEPTION 'duplicate ride was not reduced to one analysis row';
    END IF;
    IF EXISTS (SELECT 1 FROM analysis_rides WHERE ride_id = 'missing-endpoint') THEN
        RAISE EXCEPTION 'ride with missing endpoints entered analysis';
    END IF;
    IF EXISTS (SELECT 1 FROM analysis_rides WHERE ride_id = 'unsupported-rider') THEN
        RAISE EXCEPTION 'unsupported rider entered analysis';
    END IF;
    IF (SELECT COUNT(*) FROM raw_divvy_rides) <> 17
       OR (SELECT COUNT(*) FROM prepared_rides) <> 17
       OR (SELECT COUNT(*) FROM analysis_rides) <> 14 THEN
        RAISE EXCEPTION 'synthetic fixture row counts changed unexpectedly';
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
        RAISE EXCEPTION 'synthetic manifest counts do not match raw rows';
    END IF;
END;
$$;
