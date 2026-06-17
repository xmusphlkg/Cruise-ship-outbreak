# Data Dictionary

This dictionary describes the frozen analytic dataset and source-provenance files for the passenger-ship outbreak visibility mapping project. Missing or unavailable values are generally encoded as `NR`.

## Analytic Dataset

Primary files:

- `data/outbreak_events.csv`
- `output/table_s_full_dataset.csv`

Both files use the same event-level schema.

| Field | Definition |
|---|---|
| `event_id` | Stable internal event-record identifier. |
| `ship_name` | Vessel name as reported in the public source or curated from the event record. |
| `ship_type` | Vessel type; eligible records are ocean or expedition cruise ships. |
| `voyage_route` | Reported itinerary, port, region, or route information visible in public sources. |
| `outbreak_year` | Calendar year assigned to the outbreak event-record. |
| `outbreak_duration_days` | Publicly reported or curated duration of the event in days, when available. |
| `pathogen_identified` | Laboratory-confirmed pathogen or reported syndrome if no pathogen was identified. |
| `pathogen_category` | Mutually exclusive analytic category: `gastrointestinal_viral`, `unknown`, `foodborne_waterborne_bacterial`, `respiratory_viral`, `legionella`, `vaccine_preventable`, or `zoonotic`. The `zoonotic` category was reserved for an event primarily framed in public records as a zoonotic spillover or zoonotic pathogen cluster, rather than as foodborne/waterborne gastrointestinal illness, respiratory viral infection, Legionella, or vaccine-preventable disease. |
| `secondary_pathogens` | Additional reported pathogens, if visible and not used as the primary category. |
| `clinical_syndrome` | Main clinical syndrome reported for the event. |
| `cases_passengers` | Passenger case count visible in the public event record. |
| `cases_crew` | Crew case count visible in the public event record. |
| `total_crew_onboard` | Crew denominator visible in the public event record, when available. |
| `attack_rate_percent` | Explicitly reported overall event-level attack rate visible in the public event record, when available. Passenger- and crew-specific illness proportions in VSP records were not counted as overall attack rates. |
| `hospitalisations` | Hospitalization count visible in the public event record. Numeric zero values were treated as reported only when explicitly recorded as zero in the source or curated event record. |
| `deaths` | Death count visible in the public event record. Numeric zero values were treated as reported only when explicitly recorded as zero in the source or curated event record. |
| `transmission_route` | Reported or inferred broad route category used for descriptive mapping. |
| `data_source_category` | Broad source category in the curated dataset, usually `official_public_health` or `academic`. |
| `data_source_reference` | Short citation or source label for the public record. |
| `source_url` | URL for the public source used for event extraction or confirmation, when available. |
| `public_health_response` | Public health or operational response actions visible in public sources. |
| `notes` | Curator notes, uncertainty notes, or source-specific details. |

## Source-Provenance Files

### `data/search_records.csv`

| Field | Definition |
|---|---|
| `record_id` | Stable internal source-record identifier. |
| `source_database` | Source pathway or database. |
| `source_category` | Broad source type, such as official public health or academic. |
| `title` | Source record title or public-source label. |
| `year` | Source publication or event year when available. |
| `ship_name` | Vessel name visible at source-identification stage, when available. |
| `pathogen` | Pathogen or syndrome visible at source-identification stage, when available. |
| `source_url` | Source URL, DOI, or other public link. |
| `retrieval_date` | Date on which the record was retrieved or generated. |
| `language` | Language code when available. |
| `screening_outcome` | Initial screening outcome or status. |

### `data/pubmed_screening.csv`

PubMed screening file containing retrieved bibliographic metadata, abstract text, screening decisions, and inclusion/exclusion annotations used for academic-source event identification.

### `data/screening_decisions.csv`

| Field | Definition |
|---|---|
| `record_id` | Stable internal source-record identifier. |
| `title` | Source record title. |
| `source_database` | Source pathway or database. |
| `source_category` | Broad source type. |
| `year` | Publication or event year when available. |
| `screening_stage` | Stage at which the source was screened. |
| `decision` | Inclusion or exclusion decision. |
| `exclusion_reason` | Reason for exclusion, when applicable. |
| `notes` | Screening notes. |

## Generated Supplementary Tables

| File | Contents |
|---|---|
| `output/supplementary_tables/table_s1_source_bias.csv` | Pathogen-category counts by mutually exclusive entry-source tier. |
| `output/supplementary_tables/table_s2_pathogen_summary.csv` | Overall pathogen-category composition, cumulative visible case counts, and deaths. |
| `output/supplementary_tables/table_s3_temporal_distribution.csv` | Pathogen-category counts across analytic time periods. |
| `output/supplementary_tables/table_s4_field_completeness.csv` | Overall field-completeness counts and percentages, including explicitly reported overall event-level attack rate. |
| `output/supplementary_tables/table_s5_deaths_by_pathogen.csv` | Reported death counts by pathogen category, separating events with zero deaths from events with death data missing. |
| `output/supplementary_tables/table_s6_sensitivity_analyses.csv` | Pathogen-category counts under source and period sensitivity analyses. |
| `output/supplementary_tables/table_s8_source_contribution_indicators.csv` | Event-level indicators for CDC VSP, non-VSP official public health, and academic source types visible in curated source fields. These indicators are not an exhaustive bibliographic network for every event. |

## Field-Completeness Rules

Completeness refers to information visible to an external public-record reviewer. Blank fields and `NR` were coded as missing. Numeric zero values, including explicit zero deaths or hospitalizations, were counted as reported only when recorded as zero in the source or curated event record. Attack-rate completeness required an explicitly reported overall event-level rate; passenger- and crew-specific illness proportions were not counted as overall attack rates. For the main completeness analysis, `not reported`, `not applicable`, and `not extractable` were all treated as not visible in the public event record; missing fields were not assumed to be zero.

## Source-Tier Rules

Event-records were assigned to mutually exclusive entry-source tiers for descriptive analyses: CDC VSP entries, non-VSP official public health reports, or peer-reviewed academic publications. Supplementary public records could complete event fields but did not change the entry-source tier.

For dynamic web sources, especially current CDC VSP outbreak pages, the frozen curated dataset and source-provenance files define the records used for the analysis; later live-page content was not used to alter the frozen event set.
