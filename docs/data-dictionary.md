# Data dictionary

## `raw_divvy_rides`

The raw import table mirrors the monthly CSV schema and deliberately applies no null constraints.

| Column | Type | Meaning |
| --- | --- | --- |
| `ride_id` | `text` | Source trip identifier. |
| `rideable_type` | `text` | Bike category supplied by the source. |
| `started_at` | `timestamp` | Local trip start timestamp. |
| `ended_at` | `timestamp` | Local trip end timestamp. |
| `start_station_name` | `text` | Source start-station label, when present. |
| `start_station_id` | `text` | Source start-station identifier, when present. |
| `end_station_name` | `text` | Source end-station label, when present. |
| `end_station_id` | `text` | Source end-station identifier, when present. |
| `start_lat`, `start_lng` | `double precision` | Start coordinates, when present. |
| `end_lat`, `end_lng` | `double precision` | End coordinates, when present. |
| `member_casual` | `text` | Source rider category: expected values are `member` or `casual`. |

## `prepared_rides`

The prepared table preserves all imported rows and adds reviewable transformations.

| Column or group | Meaning |
| --- | --- |
| `raw_start_station_name`, `raw_end_station_name` | Unchanged station labels from the source. |
| `start_station_name`, `end_station_name` | Normalized labels; a missing label with other endpoint evidence becomes `Unmapped Endpoint`. |
| `start_date` | Calendar date derived from `started_at`. |
| `start_month` | Numeric month from 1 through 12. |
| `start_day_of_week` | PostgreSQL day number: Sunday `0` through Saturday `6`. |
| `start_day_name` | Stable three-letter English day label. |
| `start_hour` | Trip-start hour from 0 through 23. |
| `trip_duration_minutes` | Full timestamp difference expressed in minutes. |
| `ride_id_occurrence_count` | Number of imported rows sharing the same `ride_id`. |
| `ride_id_row_number` | Deterministic rank used to keep one row per ID in the analysis view. |
| `has_start_endpoint`, `has_end_endpoint` | Whether a station label, station ID, or complete coordinate pair identifies the endpoint. |
| `is_operational_station` | Whether either raw station label matches the documented vaccination, repair, or testing markers. |
| `has_valid_duration` | Whether both timestamps exist and the ride lasts at least 60 seconds. |
| `has_supported_rider_type` | Whether the category is `member` or `casual`. |

## `analysis_rides`

The analysis view selects one row per non-null ride ID and requires:

- a non-null bike type;
- usable start and end endpoints;
- a duration of at least 60 seconds;
- a supported rider category; and
- no operational-station marker.

It retains docked-bike rows, unmapped endpoints, the source duplicate count,
and the quality flags used by the validation query. See
[methodology.md](methodology.md) for the rationale and limitations.
