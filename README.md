# Cruise Ship Outbreak

This repository contains the code, source data, and analysis outputs for the cruise-ship outbreak project.

## Contents

- `data/`: input data used for the analysis
- `script/`: Python and R scripts for rebuilding tables and figures
- `output/`: generated tables, figures, and summary artifacts

## Reproducibility

The EID manuscript figures can be regenerated from the current EID figure script.

- `Rscript script/generate_eid_figure.R`

Legacy general-manuscript and supplementary-figure scripts remain in `script/` for provenance, but their outputs are not part of the current EID package.

## Manuscript Packages

- `manuscript/eid_perspective/`: local EID Perspective draft package, including main manuscript, technical appendix, cover letter, and submission checklist.
- `output/Figure_1_public_visibility.tif`: EID-oriented main-text Figure 1 composite, with separate 1A/1B panel files.
- `output/Figure_2_temporal_visibility.tif`: EID-oriented main-text Figure 2 composite, with separate 2A/2B panel files.
- `output/Figure_3_reporting_completeness.tif`: EID-oriented main-text Figure 3 composite, with separate 3A/3B/3C panel files.

## Notes

- The `manuscript/` directory is intentionally excluded from version control.
