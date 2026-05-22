# NHL Free Agency Research

This academic research project examines whether NHL offseason free agency signings and trades produce a measurable team-level performance reset effect, grounded in behavioral economics research by Hengchen Dai et al. The study evaluates whether offseason movement activity — measured through a weighted Movement Impact Score (MIS) by position tier — correlates with changes in team performance across consecutive seasons.

This is an offseason-only study covering UFAs and trades. Trade deadline activity, AHL transactions, and ELC signings are explicitly out of scope for this version.

## Primary Data Sources

- **Spotrac**: Contract and movement event data, accessed via browser page source
- **nhlscraper (CRAN v0.6.0)**: Team performance, play-by-play, and xGoals data

## Dependencies

- R
- tidyverse
- nhlscraper
- rvest

## Data Handling Note

Data is not committed to this repository and must be extracted separately using the scripts in `R/01_data_extraction`.

## UX Audit Checklist

- Non-data user browser audit checklist: [docs/audit/non-data-user-audit-checklist.md](docs/audit/non-data-user-audit-checklist.md)

## Automated Site Audit

- A repository-level audit runner now lives at `scripts/run_audit.js` and writes results to `output/tables/audit_report.json`.
- GitHub Actions runs the audit on push to `main`, on weekly schedule (Sunday 06:00 UTC), and on manual dispatch via `.github/workflows/audit.yml`.
- The dashboard audit page is available at `dashboard/src/audit.html` and can both render the latest automated report and run a live in-browser recheck.
