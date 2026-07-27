-- Compatibility entry point for the original public file URL.
--
-- Prerequisite: import the August 2022-July 2023 CSV files into
-- raw_divvy_rides as described in docs/reproducibility.md.
--
-- Run from the repository root:
--   psql -d divvy_case_study -f data_cleaning.sql
--
-- pgAdmin users can run the numbered files under sql/ in the same order.

\set ON_ERROR_STOP on

\ir sql/00_create_source_table.sql
\ir sql/01_profile_source.sql
\ir sql/02_build_prepared_rides.sql
\ir sql/03_analysis.sql
\ir sql/04_validate_pipeline.sql
