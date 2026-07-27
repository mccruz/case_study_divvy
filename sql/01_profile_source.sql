-- Read-only source profiling.
-- Run this after all 12 CSV files have been loaded into raw_divvy_rides.

-- Scope and row count.
SELECT
    COUNT(*) AS source_rows,
    MIN(started_at) AS earliest_start,
    MAX(started_at) AS latest_start
FROM raw_divvy_rides;

-- Duplicate ride identifiers. No rows means the source key is unique.
SELECT
    ride_id,
    COUNT(*) AS row_count
FROM raw_divvy_rides
GROUP BY ride_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC, ride_id
LIMIT 100;

-- Null profile by field.
SELECT
    COUNT(*) FILTER (WHERE ride_id IS NULL) AS ride_id_nulls,
    COUNT(*) FILTER (WHERE rideable_type IS NULL) AS rideable_type_nulls,
    COUNT(*) FILTER (WHERE started_at IS NULL) AS started_at_nulls,
    COUNT(*) FILTER (WHERE ended_at IS NULL) AS ended_at_nulls,
    COUNT(*) FILTER (WHERE start_station_name IS NULL) AS start_station_name_nulls,
    COUNT(*) FILTER (WHERE start_station_id IS NULL) AS start_station_id_nulls,
    COUNT(*) FILTER (WHERE end_station_name IS NULL) AS end_station_name_nulls,
    COUNT(*) FILTER (WHERE end_station_id IS NULL) AS end_station_id_nulls,
    COUNT(*) FILTER (WHERE start_lat IS NULL) AS start_lat_nulls,
    COUNT(*) FILTER (WHERE start_lng IS NULL) AS start_lng_nulls,
    COUNT(*) FILTER (WHERE end_lat IS NULL) AS end_lat_nulls,
    COUNT(*) FILTER (WHERE end_lng IS NULL) AS end_lng_nulls,
    COUNT(*) FILTER (WHERE member_casual IS NULL) AS member_casual_nulls
FROM raw_divvy_rides;

-- Rows without enough information to identify either endpoint.
SELECT
    COUNT(*) FILTER (
        WHERE start_station_name IS NULL
          AND start_station_id IS NULL
          AND (start_lat IS NULL OR start_lng IS NULL)
    ) AS missing_start_endpoint,
    COUNT(*) FILTER (
        WHERE end_station_name IS NULL
          AND end_station_id IS NULL
          AND (end_lat IS NULL OR end_lng IS NULL)
    ) AS missing_end_endpoint
FROM raw_divvy_rides;

-- Timestamp and duration quality. Full timestamp subtraction handles
-- cross-midnight and multi-day rides correctly.
SELECT
    COUNT(*) FILTER (
        WHERE started_at IS NULL OR ended_at IS NULL
    ) AS missing_timestamps,
    COUNT(*) FILTER (
        WHERE ended_at <= started_at
    ) AS non_positive_duration,
    COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM (ended_at - started_at)) < 60
    ) AS duration_below_60_seconds
FROM raw_divvy_rides;

-- Source category values.
SELECT
    rideable_type,
    member_casual,
    COUNT(*) AS trip_count
FROM raw_divvy_rides
GROUP BY rideable_type, member_casual
ORDER BY rideable_type, member_casual;
