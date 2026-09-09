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

-- One import receipt per expected source month. The importer writes the raw
-- rows and this receipt in the same transaction, so a successful import has
-- both the data and enough provenance to audit it.
CREATE TABLE IF NOT EXISTS source_imports (
    source_month date PRIMARY KEY,
    filename text NOT NULL,
    sha256 text NOT NULL,
    row_count bigint NOT NULL CHECK (row_count > 0),
    imported_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (source_month = date_trunc('month', source_month)::date),
    CHECK (sha256 ~ '^[0-9a-f]{64}$')
);

COMMENT ON TABLE raw_divvy_rides IS
    'Raw Divvy trip rows imported from the August 2022-July 2023 monthly CSV files.';

COMMENT ON TABLE source_imports IS
    'Atomic import receipts for the required August 2022-July 2023 monthly CSV files.';
