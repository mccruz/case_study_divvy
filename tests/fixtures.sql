-- Synthetic records only. One valid ride anchors every required source month;
-- August also covers the transformation edge cases asserted below.
INSERT INTO raw_divvy_rides (
    ride_id, rideable_type, started_at, ended_at, start_station_name,
    start_station_id, end_station_name, end_station_id, start_lat, start_lng,
    end_lat, end_lng, member_casual
)
SELECT
    'month-' || to_char(month_start, 'YYYYMM'),
    'classic_bike',
    month_start + time '09:00',
    month_start + time '09:30',
    'Start', 'start-id', 'End', 'end-id', 41.0, -87.0, 41.1, -87.1, 'member'
FROM generate_series(DATE '2022-08-01', DATE '2023-07-01', INTERVAL '1 month') AS month_start;

INSERT INTO raw_divvy_rides VALUES
('midnight', 'electric_bike', '2022-08-10 23:30', '2022-08-11 01:00', 'A', 'a', 'B', 'b', 41, -87, 41.1, -87.1, 'casual'),
('duplicate', 'classic_bike', '2022-08-12 09:00', '2022-08-12 09:30', 'A', 'a', 'B', 'b', 41, -87, 41.1, -87.1, 'member'),
('duplicate', 'classic_bike', '2022-08-12 09:00', '2022-08-12 09:30', 'A', 'a', 'B', 'b', 41, -87, 41.1, -87.1, 'member'),
('missing-endpoint', 'classic_bike', '2022-08-13 09:00', '2022-08-13 09:30', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'member'),
('unsupported-rider', 'classic_bike', '2022-08-14 09:00', '2022-08-14 09:30', 'A', 'a', 'B', 'b', 41, -87, 41.1, -87.1, 'visitor');

INSERT INTO source_imports (source_month, filename, sha256, row_count)
SELECT
    source_month,
    to_char(source_month, 'YYYYMM') || '-divvy-tripdata.csv',
    repeat('a', 64),
    raw_rows
FROM (
    SELECT date_trunc('month', started_at)::date AS source_month, COUNT(*) AS raw_rows
    FROM raw_divvy_rides
    GROUP BY 1
) AS monthly_rows;
