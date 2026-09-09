DELETE FROM raw_divvy_rides WHERE date_trunc('month', started_at)::date = DATE '2023-07-01';
DELETE FROM source_imports WHERE source_month = DATE '2023-07-01';
\ir ../sql/02_build_prepared_rides.sql
\ir ../sql/04_validate_pipeline.sql
