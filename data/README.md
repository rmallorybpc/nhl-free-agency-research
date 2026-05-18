# Data Directory

This project uses a two-layer data structure.

- `raw/` holds unmodified source data exactly as extracted.
  - Spotrac HTML source files go in `raw/spotrac/`.
  - nhlscraper pull outputs go in `raw/nhlscraper/`.
- `processed/` holds cleaned and joined datasets ready for analysis.

All raw and processed data files are excluded from version control via `.gitignore` and must be regenerated locally using the extraction scripts.
