-- Reusable analysis queries for member-versus-casual behavior.

-- 1. Rider mix.
SELECT
    member_casual,
    COUNT(*) AS trip_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS trip_share_pct
FROM analysis_rides
GROUP BY member_casual
ORDER BY trip_count DESC;

-- 2. Rider mix by bike type.
SELECT
    member_casual,
    rideable_type,
    COUNT(*) AS trip_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS total_trip_share_pct
FROM analysis_rides
GROUP BY member_casual, rideable_type
ORDER BY member_casual, trip_count DESC;

-- 3. Monthly demand.
SELECT
    DATE_TRUNC('month', started_at)::date AS month_start,
    member_casual,
    COUNT(*) AS trip_count
FROM analysis_rides
GROUP BY month_start, member_casual
ORDER BY month_start, member_casual;

-- 4. Day-of-week demand. PostgreSQL DOW: Sunday=0 through Saturday=6.
SELECT
    start_day_of_week,
    start_day_name,
    member_casual,
    COUNT(*) AS trip_count
FROM analysis_rides
GROUP BY start_day_of_week, start_day_name, member_casual
ORDER BY start_day_of_week, member_casual;

-- 5. Hour-of-day demand.
SELECT
    start_hour,
    member_casual,
    COUNT(*) AS trip_count
FROM analysis_rides
GROUP BY start_hour, member_casual
ORDER BY start_hour, member_casual;

-- 6. Duration distribution. Median is less sensitive to extreme rides than
-- average alone, so both are reported.
SELECT
    member_casual,
    COUNT(*) AS trip_count,
    ROUND(AVG(trip_duration_minutes), 2) AS average_duration_minutes,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY trip_duration_minutes
        )::numeric,
        2
    ) AS median_duration_minutes
FROM analysis_rides
GROUP BY member_casual
ORDER BY member_casual;

-- 7. Top start stations. Trips without a source station label are retained in
-- the analysis view but excluded from this station ranking.
SELECT
    start_station_name,
    member_casual,
    COUNT(*) AS trip_count
FROM analysis_rides
WHERE start_station_name <> 'Unmapped Endpoint'
GROUP BY start_station_name, member_casual
ORDER BY trip_count DESC
LIMIT 20;

-- 8. Top end stations.
SELECT
    end_station_name,
    member_casual,
    COUNT(*) AS trip_count
FROM analysis_rides
WHERE end_station_name <> 'Unmapped Endpoint'
GROUP BY end_station_name, member_casual
ORDER BY trip_count DESC
LIMIT 20;
