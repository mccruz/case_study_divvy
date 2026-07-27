-- Build an auditable prepared table and an analysis-ready view.
--
-- prepared_rides preserves raw station names and every source row while adding
-- normalized labels and explicit quality flags. analysis_rides applies the
-- documented eligibility rules without hiding how many rows were excluded.

BEGIN;

DROP VIEW IF EXISTS analysis_rides;
DROP TABLE IF EXISTS prepared_rides;

CREATE INDEX IF NOT EXISTS idx_raw_divvy_rides_ride_id
    ON raw_divvy_rides (ride_id);

ANALYZE raw_divvy_rides;

CREATE TABLE prepared_rides AS
WITH ranked_source AS (
    SELECT
        ride_id,
        rideable_type,
        started_at,
        ended_at,
        start_station_name,
        start_station_id,
        end_station_name,
        end_station_id,
        start_lat,
        start_lng,
        end_lat,
        end_lng,
        member_casual,
        COUNT(*) OVER (PARTITION BY ride_id) AS ride_id_occurrence_count,
        ROW_NUMBER() OVER (
            PARTITION BY ride_id
            ORDER BY
                rideable_type NULLS LAST,
                started_at NULLS LAST,
                ended_at NULLS LAST,
                start_station_name NULLS LAST,
                start_station_id NULLS LAST,
                end_station_name NULLS LAST,
                end_station_id NULLS LAST,
                start_lat NULLS LAST,
                start_lng NULLS LAST,
                end_lat NULLS LAST,
                end_lng NULLS LAST,
                member_casual NULLS LAST
        ) AS ride_id_row_number
    FROM raw_divvy_rides
),
normalized AS (
    SELECT
        *,
        CASE
            WHEN start_station_name IS NULL
                 AND (
                     start_station_id IS NOT NULL
                     OR (start_lat IS NOT NULL AND start_lng IS NOT NULL)
                 )
                THEN 'Unmapped Endpoint'
            WHEN start_station_name IS NULL
                THEN NULL
            ELSE BTRIM(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        start_station_name,
                        '^(City Rack|Public Rack) - ',
                        '',
                        'i'
                    ),
                    '(\*| (N|S|E|W|NE|NW|SE|SW)| - (W|SE|SW|NW|NE|East|West|South|North|midblock|midblock south|south corner|north corner)| \((NU|East|South|Temp|NEXT Apts)\))+$',
                    '',
                    'i'
                )
            )
        END AS normalized_start_station_name,
        CASE
            WHEN end_station_name IS NULL
                 AND (
                     end_station_id IS NOT NULL
                     OR (end_lat IS NOT NULL AND end_lng IS NOT NULL)
                 )
                THEN 'Unmapped Endpoint'
            WHEN end_station_name IS NULL
                THEN NULL
            ELSE BTRIM(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        end_station_name,
                        '^(City Rack|Public Rack) - ',
                        '',
                        'i'
                    ),
                    '(\*| (N|S|E|W|NE|NW|SE|SW)| - (W|SE|SW|NW|NE|East|West|South|North|midblock|midblock south|south corner|north corner)| \((NU|East|South|Temp|NEXT Apts)\))+$',
                    '',
                    'i'
                )
            )
        END AS normalized_end_station_name
    FROM ranked_source
)
SELECT
    ride_id,
    rideable_type,
    started_at,
    ended_at,
    start_station_name AS raw_start_station_name,
    start_station_id,
    normalized_start_station_name AS start_station_name,
    end_station_name AS raw_end_station_name,
    end_station_id,
    normalized_end_station_name AS end_station_name,
    start_lat,
    start_lng,
    end_lat,
    end_lng,
    member_casual,
    started_at::date AS start_date,
    EXTRACT(MONTH FROM started_at)::smallint AS start_month,
    EXTRACT(DOW FROM started_at)::smallint AS start_day_of_week,
    CASE EXTRACT(DOW FROM started_at)::smallint
        WHEN 0 THEN 'Sun'
        WHEN 1 THEN 'Mon'
        WHEN 2 THEN 'Tue'
        WHEN 3 THEN 'Wed'
        WHEN 4 THEN 'Thu'
        WHEN 5 THEN 'Fri'
        WHEN 6 THEN 'Sat'
    END AS start_day_name,
    EXTRACT(HOUR FROM started_at)::smallint AS start_hour,
    ROUND(
        EXTRACT(EPOCH FROM (ended_at - started_at)) / 60.0,
        2
    ) AS trip_duration_minutes,
    ride_id_occurrence_count,
    ride_id_row_number,
    (
        start_station_name IS NOT NULL
        OR start_station_id IS NOT NULL
        OR (start_lat IS NOT NULL AND start_lng IS NOT NULL)
    ) AS has_start_endpoint,
    (
        end_station_name IS NOT NULL
        OR end_station_id IS NOT NULL
        OR (end_lat IS NOT NULL AND end_lng IS NOT NULL)
    ) AS has_end_endpoint,
    (
        COALESCE(start_station_name, '') ~*
            '(Vaccination Site|REPAIR MOBILE STATION| - TEST(ING)?$)'
        OR COALESCE(end_station_name, '') ~*
            '(Vaccination Site|REPAIR MOBILE STATION| - TEST(ING)?$)'
    ) AS is_operational_station,
    (
        started_at IS NOT NULL
        AND ended_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (ended_at - started_at)) >= 60
    ) AS has_valid_duration,
    (member_casual IN ('member', 'casual')) AS has_supported_rider_type
FROM normalized;

COMMENT ON TABLE prepared_rides IS
    'Source-preserving Divvy trips with normalized station labels and explicit quality flags.';

CREATE INDEX idx_prepared_rides_started_at
    ON prepared_rides (started_at);

CREATE INDEX idx_prepared_rides_rider_started_at
    ON prepared_rides (member_casual, started_at);

CREATE INDEX idx_prepared_rides_start_station
    ON prepared_rides (start_station_name);

CREATE VIEW analysis_rides AS
SELECT
    ride_id,
    rideable_type,
    started_at,
    ended_at,
    raw_start_station_name,
    start_station_id,
    start_station_name,
    raw_end_station_name,
    end_station_id,
    end_station_name,
    start_lat,
    start_lng,
    end_lat,
    end_lng,
    member_casual,
    start_date,
    start_month,
    start_day_of_week,
    start_day_name,
    start_hour,
    trip_duration_minutes,
    ride_id_occurrence_count,
    has_start_endpoint,
    has_end_endpoint,
    is_operational_station,
    has_valid_duration,
    has_supported_rider_type
FROM prepared_rides
WHERE ride_id IS NOT NULL
  AND rideable_type IS NOT NULL
  AND ride_id_row_number = 1
  AND has_start_endpoint
  AND has_end_endpoint
  AND has_valid_duration
  AND has_supported_rider_type
  AND NOT is_operational_station;

COMMENT ON VIEW analysis_rides IS
    'Analysis-eligible trips: unique IDs, known rider and bike types, usable endpoints, durations of at least 60 seconds, and no flagged operational stations.';

ANALYZE prepared_rides;

COMMIT;
