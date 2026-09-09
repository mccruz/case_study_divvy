# Chicago Bike-Share Rider Analysis

A PostgreSQL and Tableau case study that helps a marketing team compare
bike-share usage by annual members and casual riders, then choose testable
membership-campaign ideas.

## Example result

**Historical finding from the original 2023 analysis:** members represented
**64.8% of analyzed trips**; casual usage leaned toward weekends and afternoons.
One possible experiment is to compare leisure-focused membership messaging
with commuter messaging.

This is an observed pattern and a proposed test, **not a measured conversion
improvement**. The refreshed SQL has not been rerun on the full historical
snapshot, so its totals may differ. The [dashboard](#dashboard) shows the
original Tableau story.

## My contribution

I developed the rider comparison and Tableau story, then rebuilt the SQL as
separate profiling, preparation, analysis, and validation stages. The refreshed
version adds import receipts and synthetic regression checks; it uses no LLM.

This independent analysis is not affiliated with or endorsed by Lyft, Divvy,
or the City of Chicago. The Divvy name identifies the public data source.

<a id="review-this-project-in-3-minutes"></a>

## Explore the project

Start with the example above, then follow the diagram and the
[engineering evidence](#engineering-evidence). Setup is optional for review.

## Business question

How did annual members and casual riders use the service differently, and which
observable patterns could support marketing tests that encourage eligible
casual riders to consider membership?

The analysis describes behavior in the trip data. It does not identify
individual riders or prove why they made a trip.

## How the analysis works

1. Load twelve monthly CSV files into a raw PostgreSQL table.
2. Profile duplicates, missing values, station fields, categories, and duration
   problems.
3. Normalize the data while preserving the original fields for review.
4. Apply documented rules that determine which trips are eligible for analysis.
5. Compare rider mix, time, duration, bike type, and station activity.
6. Run validation checks against the final analysis view.

```mermaid
flowchart LR
    A[Monthly CSV files] --> B[Raw trips]
    B --> C[Quality review]
    C --> D[Prepared and flagged trips]
    D --> E[Analysis view]
    E --> F[Findings]
    E --> G[Validation checks]
```

## Engineering evidence

| Capability | Implementation | Check |
| --- | --- | --- |
| Preserve raw fields and handle midnight rides | [Prepared-rides SQL](sql/02_build_prepared_rides.sql) | [Synthetic assertions](tests/assertions.sql) |
| Verify the import and analysis scope | [Importer](scripts/import_divvy_month.py), [validation](sql/04_validate_pipeline.sql) | [Disposable database tests](tests/run_sql_tests.sh) |
| Explain the analytical choices | [Analysis SQL](sql/03_analysis.sql) | [Methodology](docs/methodology.md) |

## Historical findings

The original 2023 analysis reported these patterns. They come from the linked
Tableau and Medium work and have not been recomputed from the refreshed SQL
pipeline.

| Observation | Reported pattern | Possible marketing test |
| --- | --- | --- |
| Rider mix | Members represented 64.8% of analyzed trips | Focus on repeat casual use rather than broad untargeted reach |
| Day and hour | Members were more active on weekdays and near commute hours; casual riders favored weekends and afternoons | Compare commuter and leisure messages |
| Seasonality | Usage increased in warmer months | Time campaigns around seasonal demand |
| Duration | Casual riders generally took longer rides | Test membership value for frequent longer trips |
| Location | Activity concentrated around central neighborhoods and busy stations | Pilot location-specific campaigns before expanding |

The original analysis also identified **Streeter Dr & Grand Ave** as the leading
station. These findings suggest experiments; they do not establish why riders
behaved differently or guarantee a campaign result.

## Dashboard

[![Tableau story showing rider mix and bike type](https://public.tableau.com/views/CaseStudyDivvy/Story1.png?:showVizHome=no)](https://public.tableau.com/app/profile/mark.cruz4539/viz/CaseStudyDivvy/Story1)

Open the image to explore the full Tableau story.

## Optional reproduction

Reproducing the analysis requires PostgreSQL and the twelve external monthly
trip files from August 2022 through July 2023. The source files are not included
in this repository.

The SQL runs in four stages:

```text
sql/01_profile_source.sql
sql/02_build_prepared_rides.sql
sql/03_analysis.sql
sql/04_validate_pipeline.sql
```

Create the database and import contract first:

```bash
createdb divvy_case_study
psql -d divvy_case_study -f sql/00_create_source_table.sql
```

Import each of the twelve monthly CSVs using the manifest-backed importer:

```bash
python3 scripts/import_divvy_month.py --database divvy_case_study \
  /absolute/path/to/202208-divvy-tripdata.csv
# Repeat for the remaining months, then run the pipeline:
psql -d divvy_case_study -f data_cleaning.sql
```

Success requires complete input receipts, nonempty data, and passing integrity
checks. An invalid run exits with an error. See the
[reproducibility guide](docs/reproducibility.md) for installation, CSV import,
expected schema, and troubleshooting.

## Limits and next steps

- Historical figures should not be presented as newly recomputed results.
- Anonymous trip records cannot safely establish repeat-rider identity.
- Observed patterns do not prove motivation or marketing effectiveness.
- A future version should rerun the refreshed pipeline on a versioned data
  snapshot and publish a validated results export.
- Campaign ideas should be tested with a defined success metric, appropriate
  comparison group, and approved privacy and consent rules.

## Project guide

- [Methodology](docs/methodology.md)
- [Reproducibility](docs/reproducibility.md)
- [Data dictionary](docs/data-dictionary.md)
- [Original exploratory SQL](archive/data_cleaning_original.sql)
- [Interactive Tableau story](https://public.tableau.com/app/profile/mark.cruz4539/viz/CaseStudyDivvy/Story1)

## Data and license

Trip data is available from the official
[Divvy Data page](https://divvybikes.com/system-data) and is governed by the
[Divvy Data License Agreement](https://divvybikes.com/data-license-agreement).
Consult the current agreement before downloading or using the data.

Repository code and documentation are available under the [MIT License](LICENSE).
That license does not cover the source trip data, third-party trademarks,
Tableau, Medium, or Google Slides content.
