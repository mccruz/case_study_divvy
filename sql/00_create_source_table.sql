-- Raw import contract for the August 2022-July 2023 monthly trip files.
--
-- This table deliberately has no NOT NULL constraints: the profiling stage
-- must be able to measure source-data gaps before any rows are filtered.

CREATE TABLE IF NOT EXISTS raw_divvy_rides (
    ride_id text,
    rideable_type text,
    started_at timestamp without time zone,
    ended_at timestamp without time zone,
    start_station_name text,
    start_station_id text,
    end_station_name text,
    end_station_id text,
    start_lat double precision,
    start_lng double precision,
    end_lat double precision,
    end_lng double precision,
    member_casual text
);

COMMENT ON TABLE raw_divvy_rides IS
    'Raw Divvy trip rows imported from the August 2022-July 2023 monthly CSV files.';
