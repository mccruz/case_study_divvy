UPDATE source_imports
SET row_count = row_count + 1
WHERE source_month = DATE '2022-08-01';
\ir ../sql/04_validate_pipeline.sql
