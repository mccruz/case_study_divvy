# Chicago Bike-Share Rider Analysis

A reproducible PostgreSQL case study comparing member and casual rider behavior in Chicago bike-share trip data. The project turns a one-file exploratory query into an auditable workflow for data profiling, quality controls, customer segmentation, and conversion-focused marketing recommendations.

> Portfolio note: this independent analysis is not affiliated with or endorsed by Lyft, Divvy, or the City of Chicago. The Divvy name is used only to identify the public data source.

## Review this project in 3 minutes (no setup required)

You do **not** need PostgreSQL, the source files, or any command-line experience to evaluate this project.

1. Read the [business question](#business-question) and the historical [published findings](#published-findings).
2. Open the [interactive Tableau story](https://public.tableau.com/app/profile/mark.cruz4539/viz/CaseStudyDivvy/Story1) to explore the original visual analysis.
3. Review the [methodology](docs/methodology.md) for the assumptions and quality rules behind the refreshed pipeline.
4. Skim the final [validation checks](sql/04_validate_pipeline.sql) to see how the workflow tests its own output.

The hands-on database setup later in this README is optional and intended for technical reviewers who want to reproduce the SQL workflow.

## Business question

How do annual members and casual riders use the bike-share service differently, and which observable patterns could inform campaigns that encourage eligible casual riders to consider membership?

This project demonstrates:

- staged PostgreSQL transformations instead of a single opaque query;
- explicit data-quality flags and validation checks;
- corrected duration logic for rides that cross midnight;
- preservation of raw and normalized station names for auditability; and
- a clear path from behavioral findings to testable marketing actions.

## Analysis workflow

```mermaid
flowchart LR
    A["12 monthly CSV files<br>Aug 2022-Jul 2023"] --> B["raw_divvy_rides"]
    B --> C["Profile source quality"]
    C --> D["prepared_rides<br>normalized + flagged"]
    D --> E["analysis_rides<br>documented eligibility rules"]
    E --> F["Rider mix, time, duration,<br>bike type, and station queries"]
    E --> G["Post-build validation"]
```

## Published findings

The original 2023 analysis reported the following patterns. These are historical results from the linked Tableau and Medium work—not newly computed claims from the refreshed SQL branch.

| Observation | Reported pattern | Marketing implication |
| --- | --- | --- |
| Rider mix | Members accounted for 64.8% of analyzed trips. | Focus conversion work on identifiable, repeat casual riders rather than broad untargeted reach. |
| Day and hour | Members were more active on weekdays and around commute hours; casual riders skewed toward weekends and afternoons. | Separate commuter-oriented and leisure-oriented campaign tests. |
| Seasonality | Usage was higher in warmer months. | Time conversion messaging before and during peak seasonal demand. |
| Duration | Casual riders generally took longer rides than members. | Test membership value messages against frequent, longer-duration casual use. |
| Location | Activity concentrated around central Chicago neighborhoods and high-volume stations. | Pilot location-specific campaigns before expanding citywide. |

The original analysis also identified **Streeter Dr & Grand Ave** as the leading station and suggested commuter, weekend, summer, and location-based campaign concepts. These observations are hypotheses for targeting and experimentation—not proof of why riders behave as they do.

## Dashboard preview

[![Tableau story showing rider mix and bike type](https://public.tableau.com/views/CaseStudyDivvy/Story1.png?:showVizHome=no)](https://public.tableau.com/app/profile/mark.cruz4539/viz/CaseStudyDivvy/Story1)

*Live preview from the original Tableau story. Open the image to explore all story points.*

## Optional: reproduce the analysis locally

This is the technical review path. It requires PostgreSQL and the 12 external Divvy monthly trip files from August 2022 through July 2023. If you only want to assess the work, use the no-setup review above.

### 1. Download the repository

Install [Git](https://git-scm.com/downloads) if needed, then confirm `git --version` works.

```bash
git clone https://github.com/mccruz/case_study_divvy.git
cd case_study_divvy
```

Run every remaining command from this directory. Your terminal prompt should show `case_study_divvy` rather than only `~`; otherwise relative paths such as `sql/00_create_source_table.sql` will not be found.

### 2. Install and start PostgreSQL

On a Mac with [Homebrew](https://brew.sh/):

```bash
brew install postgresql@18
brew services start postgresql@18
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
psql --version
pg_isready
```

The last command should report that PostgreSQL is accepting connections. Windows and Linux users can use the [official PostgreSQL download instructions](https://www.postgresql.org/download/).

### 3. Create the database and source table

```bash
createdb divvy_case_study
psql -d divvy_case_study -f sql/00_create_source_table.sql
```

If `createdb` says the database already exists, continue with the `psql` command. A successful table setup prints `CREATE TABLE` or reports that the existing table was retained.

### 4. Import the data and run the pipeline

Import each CSV into `raw_divvy_rides` using the [full reproducibility guide](docs/reproducibility.md), then run:

```bash
psql -d divvy_case_study -f data_cleaning.sql
```

The compatibility entry point runs profiling, preparation, analysis, and validation in order. Success means every integrity check in the final result reports `PASS`.

### Common setup problems

| Message | What it means | What to do |
| --- | --- | --- |
| `command not found: createdb` or `psql` | PostgreSQL is not installed or its tools are not on the current shell path. | Run the PostgreSQL installation and `export PATH=...` commands above. |
| `connection ... failed` | The local PostgreSQL service is not running. | Run `brew services start postgresql@18`, then `pg_isready`. |
| `sql/00_create_source_table.sql: No such file` | The terminal is not in the cloned repository. | Run `cd case_study_divvy`, then retry. |
| `database "divvy_case_study" already exists` | The database was created during an earlier attempt. | Skip `createdb` and continue with the next command. |

See the [full reproducibility guide](docs/reproducibility.md) for CSV import examples, the expected source schema, and an option for migrating the original combined table.

## Repository structure

| Path | Purpose |
| --- | --- |
| [`sql/00_create_source_table.sql`](sql/00_create_source_table.sql) | Defines the raw import contract. |
| [`sql/01_profile_source.sql`](sql/01_profile_source.sql) | Measures duplicates, nulls, category values, endpoint gaps, and duration anomalies. |
| [`sql/02_build_prepared_rides.sql`](sql/02_build_prepared_rides.sql) | Normalizes station labels, fixes duration math, adds quality flags, and creates the analysis view. |
| [`sql/03_analysis.sql`](sql/03_analysis.sql) | Produces rider mix, temporal, duration, bike-type, and station summaries. |
| [`sql/04_validate_pipeline.sql`](sql/04_validate_pipeline.sql) | Checks the analysis view for duplicate IDs, missing required fields, and invalid records. |
| [`docs/methodology.md`](docs/methodology.md) | Documents decisions, assumptions, limitations, and changes from the original query. |
| [`docs/data-dictionary.md`](docs/data-dictionary.md) | Describes the raw, prepared, and analysis fields. |
| [`archive/data_cleaning_original.sql`](archive/data_cleaning_original.sql) | Preserves the original 2023 exploratory SQL for provenance. |

Raw trip files are deliberately excluded from this repository.

## Recommended next experiments

1. Define “frequent casual rider” using a privacy-safe, approved aggregation rather than assuming identity from anonymous trip records.
2. Test commute-value messaging against leisure-oriented messaging with a predeclared primary conversion metric.
3. Pilot geo-targeted campaigns near high-volume stations and compare lift with matched control locations.
4. Join app, web, and email engagement only when consent, governance, and identity-resolution rules allow it.
5. Re-run the refreshed SQL on the historical snapshot and publish a versioned results export before comparing exact figures with the 2023 analysis.

## Data source and usage

Historical trip data is available from the official [Divvy Data page](https://divvybikes.com/system-data) and is governed by the [Divvy Data License Agreement](https://divvybikes.com/data-license-agreement). The source files are not redistributed here. Consult the current agreement before downloading or using the data.

The SQL and repository documentation are available under the [MIT License](LICENSE). That license does **not** apply to the underlying trip data, third-party trademarks, Tableau, Medium, or Google Slides content.

## Related work

- [Background and cleaning write-up](https://medium.com/@markcastillocruz/data-analysis-case-study-divvy-bikes-chicago-e5e54b5873f3)
- [Visualizations and recommendations write-up](https://medium.com/@markcastillocruz/data-analysis-case-study-divvy-2-2-687856d3a9e8)
- [Presentation deck](https://docs.google.com/presentation/d/1iyvfBZdN74AFRKZwt4K4MEXvGuOVVgMo2P-02dOjIxw/edit?usp=sharing)
- [Interactive Tableau story](https://public.tableau.com/app/profile/mark.cruz4539/viz/CaseStudyDivvy/Story1)
- [LinkedIn profile](https://www.linkedin.com/in/markcastillocruz/)
