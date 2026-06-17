# Cruise Ship Outbreak Visibility Mapping

This repository contains the frozen analytic dataset, source-provenance files, code, and generated outputs for the manuscript:

Public visibility of infectious disease outbreak records on ocean and expedition cruise ships, 1993-2026

## Analytic Scope

- Analytic dataset freeze date: 2026-05-14.
- MV Hondius contextual source check: through 2026-06-17, using official ECDC, WHO, and CDC public updates for background only; these updates were not used to change the frozen comparative analyses.
- Unit of analysis: publicly visible infectious disease outbreak event-records on ocean and expedition cruise ships.
- Intended inference: public visibility and reporting architecture, not incidence, risk, burden, or cruise-ship safety.

## Repository Contents

- `data/outbreak_events.csv`: frozen curated event-level analytic dataset.
- `data/search_records.csv`: source-provenance records from CDC VSP, PubMed, and grey-literature screening.
- `data/pubmed_screening.csv`: PubMed screening file.
- `data/screening_decisions.csv`: record-level screening and exclusion decisions.
- `data/screening_decisions.md`: human-readable screening-decision table.
- `DATA_DICTIONARY.md`: definitions for analytic fields and source-provenance files.
- `manuscript/journal_of_travel_medicine_research_letter/`: current Journal of Travel Medicine Research Letter manuscript and cover letter.
- `script/generate_supplementary_tables.py`: regenerates the full analytic dataset export and supplementary descriptive tables.
- `script/generate_public_visibility_figure.R`: regenerates the compact public-visibility figure and panel files.
- `output/table_s_full_dataset.csv`: generated export of the full event-level dataset.
- `output/supplementary_tables/`: generated supplementary descriptive tables, including sensitivity analyses and source-type indicators.
- `output/Figure_1_public_visibility.*`: current multi-panel public-visibility figure files at 300 dpi, with PDF and PNG versions also retained.
- `output/Figure_1[A-D]_*.{pdf,png,tif}`: individual panel exports for editing or submission production.

The local `manuscript/` directory contains working draft files and is intentionally excluded from version control.

## Reproducibility

Run commands from the repository root.

```bash
python3 script/validate_eid_dataset.py
python3 script/generate_supplementary_tables.py
Rscript script/generate_public_visibility_figure.R
```

The validation command checks row count, duplicate event identifiers, duplicate vessel/route/year/pathogen combinations, year ranges, source identifiers, source-category labels, pathogen-category labels, and selected cross-field discordance. The supplementary-table command reads `data/outbreak_events.csv` and writes:

- `output/table_s_full_dataset.csv`
- `output/supplementary_tables/table_s1_source_bias.csv`
- `output/supplementary_tables/table_s2_pathogen_summary.csv`
- `output/supplementary_tables/table_s3_temporal_distribution.csv`
- `output/supplementary_tables/table_s4_field_completeness.csv`
- `output/supplementary_tables/table_s5_deaths_by_pathogen.csv`
- `output/supplementary_tables/table_s6_sensitivity_analyses.csv`
- `output/supplementary_tables/table_s8_source_contribution_indicators.csv`

The public-visibility figure script reads `output/table_s_full_dataset.csv`; regenerate the supplementary tables first if the input dataset changes.

For dynamic CDC VSP webpages, event inclusion and extraction should be checked against the frozen curated dataset and source-provenance files in this repository rather than against later live-page content.

## Software

The descriptive tables use Python standard-library modules only. The figure scripts were tested with:

- Python 3.12.3
- R 4.6.0
- R packages: `ggplot2` 4.0.3, `dplyr` 1.2.1, `tidyr` 1.3.2, `readr` 2.2.0, `scales` 1.4.0, `patchwork` 1.3.2

The legacy full-pipeline script in `script/00_run_full_pipeline.py` uses `beautifulsoup4` for HTML parsing and is retained for provenance; the current reproducibility path starts from the frozen curated CSV.

## Source Provenance

The public-source strategy used three entry-source tiers:

- CDC Vessel Sanitation Program current and archived public outbreak records.
- Non-VSP official public health reports, including WHO, ECDC, UKHSA, CDC/MMWR, and other named public health authority materials.
- Peer-reviewed academic publications identified through PubMed.

ProMED, media reports, operator communications, port-health bulletins, and local-language reports were not systematically searched. When such records cited or linked to a named public health authority, they were used only for source tracing or field completion.

For dynamic web sources, especially current CDC VSP outbreak pages, the frozen source-provenance files document the records used for this analysis as of the analytic freeze.

## Notes

- Generated event counts describe the composition of publicly retrievable event-records under this source strategy.
- Absence from the dataset should not be interpreted as absence of passenger-ship-associated disease.
- Legacy visualization outputs and scripts from previous manuscript formats, including the superseded two-panel Journal of Infection draft figure, have been moved to the hidden archive directory `.archive/legacy_visualizations_2026-06-01/`.
- The GitHub release or tag used for journal submission should preserve the analytic freeze date and generated outputs.
