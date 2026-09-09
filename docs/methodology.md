# Methodology and assumptions

## Scope

The case study analyzes anonymized trip records from August 2022 through July 2023. The business objective is to compare observable usage patterns between `member` and `casual` rider categories and translate those patterns into marketing hypotheses.

The trip records do not establish rider intent, home location, identity, income, commute status, or willingness to subscribe. Recommendations therefore use careful language such as “test,” “hypothesis,” and “eligible segment.”

## Pipeline decisions

### Preserve raw values

`prepared_rides` retains raw start and end station names alongside normalized values. This makes consolidation rules reviewable and prevents cleaned labels from becoming the only available evidence.

### Require a complete, attributable import

Each required monthly file is imported through a staging table and paired with a
`source_imports` receipt containing its filename, SHA-256 checksum, row count,
and import time. Validation requires all twelve months from August 2022 through
July 2023, rejects out-of-scope months, and requires the raw and prepared row
counts to match. These checks establish pipeline completeness, not that the
external source itself is error-free.

### Normalize known station-label variants

The normalization step removes known `City Rack -` and `Public Rack -` prefixes plus temporary, directional, corner, and asterisk suffixes found during the original exploration. The raw label remains available for auditing.

This consolidation can merge physically distinct pickup points that share a base name. Station IDs and coordinates should be used when exact physical-location analysis matters.

### Treat missing station labels separately from missing endpoints

A null station name does not automatically make a trip unusable when a station ID or complete coordinate pair is available. The refreshed pipeline uses the neutral label `Unmapped Endpoint`; it does not assume that the ride occurred outside a station. A row is excluded only when neither a station name, station ID, nor a complete coordinate pair identifies an endpoint. Source station IDs remain unchanged, including null values.

### Correct duration across dates

The original query subtracted only hour, minute, and second components. That produces negative or incorrect values when a ride crosses midnight. The refreshed pipeline uses:

```sql
EXTRACT(EPOCH FROM (ended_at - started_at)) / 60.0
```

This calculates duration from the complete timestamps. Trips below 60 seconds are excluded from `analysis_rides`; the prepared table retains their quality flag.

### Make duplicate handling visible

The refreshed pipeline counts occurrences of every `ride_id` and retains one deterministic row in `analysis_rides`. Duplicate source rows remain present and flagged in `prepared_rides`.

### Flag operational-station records

Names containing vaccination, repair, or test-station markers are flagged and excluded from `analysis_rides` to retain the scope of ordinary customer-trip analysis. The decision is an analysis assumption, not a claim that the source records are erroneous.

### Retain docked-bike records

The original query removed `docked_bike` rows based on uncertainty about the category. The refreshed pipeline retains every non-null bike type. Unknown categories should be documented and analyzed—not silently treated as invalid.

## Changes from the original query

The archived 2023 SQL is preserved under `archive/` for provenance. It should not be used as the current implementation because:

- several missing commas make the CTE chain non-executable;
- diagnostic CTEs do not produce inspectable result sets;
- `SELECT *` exposes temporary cleaning columns in the final table;
- duration math does not account for date changes;
- null station names can be unintentionally removed by `NOT LIKE`; and
- business assumptions and technical quality rules are interleaved.

The numbered workflow separates source setup, profiling, preparation, analysis, and validation so each stage can be reviewed or rerun independently.

## Results boundary

The README summarizes findings reported in the author's original 2023 Medium and Tableau work. The refreshed SQL may produce different exact counts because it corrects duration handling, changes bike-type treatment, and makes endpoint and operational-station rules explicit.

Before claiming refreshed figures:

1. run the complete pipeline against the historical snapshot;
2. save the row-accounting output;
3. export versioned aggregate results, not raw trip data;
4. reconcile material differences with the original analysis; and
5. update the README with the run date and source commit.

## Data rights and independence

The source dataset is provided under the [Divvy Data License Agreement](https://divvybikes.com/data-license-agreement). No raw trip files are committed here. This project is an independent portfolio analysis and does not imply affiliation, approval, endorsement, or sponsorship by the data provider or the City of Chicago.
