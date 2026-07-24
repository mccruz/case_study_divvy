# Reproducibility guide

This guide rebuilds the analysis from the public August 2022-July 2023 monthly trip files without committing raw data to Git.

## 1. Get the source files

Download the 12 monthly files from the official [Divvy Data page](https://divvybikes.com/system-data). Review the current [Divvy Data License Agreement](https://divvybikes.com/data-license-agreement) before use.

Keep downloaded ZIP and CSV files outside this repository, or under the ignored `data/` directory. The repository does not redistribute the source dataset.

Expected months:

- August-December 2022
- January-July 2023

Each CSV is expected to contain these columns in this order:

```text
ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,
end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual
```

## 2. Create the local database and raw table

```bash
createdb divvy_case_study
psql -d divvy_case_study -f sql/00_create_source_table.sql
```

The raw table intentionally accepts nulls so the profiling script can measure source-data quality before filtering.

## 3. Import all 12 CSV files

Run one `\copy` command per extracted CSV, replacing the example path:

```bash
psql -d divvy_case_study \
  -c "\copy raw_divvy_rides FROM '/absolute/path/to/202208-divvy-tripdata.csv' WITH (FORMAT csv, HEADER true)"
```

Repeat for every month through July 2023. Use an empty `raw_divvy_rides` table for each fresh run; importing a file twice creates duplicate rows that the profile stage will report.

To deliberately start over:

```bash
psql -d divvy_case_study -c "TRUNCATE TABLE raw_divvy_rides"
```

## 4. Run the pipeline

```bash
psql -d divvy_case_study -f data_cleaning.sql
```

This executes the numbered scripts in order:

1. confirms the raw table contract;
2. profiles source quality;
3. creates `prepared_rides` and `analysis_rides`;
4. emits analysis summaries; and
5. reports validation results and row accounting.

For easier inspection in pgAdmin, run the files under `sql/` individually in numeric order.

## 5. Migrate the original combined table

The 2023 project used a table named `"2022_08-2023_07"`. If that table already exists locally, populate the new raw contract without reimporting CSVs:

```sql
INSERT INTO raw_divvy_rides (
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
    member_casual
)
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
    member_casual
FROM "2022_08-2023_07";
```

## 6. Interpret validation

`sql/04_validate_pipeline.sql` should report `PASS` for every integrity check. Its second result set accounts for:

- source rows;
- prepared rows;
- analysis rows;
- rows missing a core identifier or bike type;
- duplicate rows excluded;
- unsupported rider-category rows;
- invalid-duration rows excluded;
- rows without usable endpoints; and
- flagged operational-station rows.

The exact refreshed metrics are not committed because the historical dataset is not included and the corrected pipeline has not been rerun against the author's local snapshot. Any published result should include the query version, run date, source period, and row-accounting output.
