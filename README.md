# NHL Free Agency Research

An applied sports analytics project built around one front-office question:

**Does spending in NHL unrestricted free agency actually predict team improvement the next season?**

This repository combines data engineering, statistical analysis, and a public-facing dashboard to test that question across multiple NHL seasons.

Live site: https://rmallorybpc.github.io/nhl-free-agency-research/

## Why this project exists

Most offseason coverage focuses on who spent the most and who "won July." This project tests whether those narratives still hold up when you step back and look at league-wide results year over year.

The work is inspired by behavioral economics research on "fresh start" effects (including Hengchen Dai's work), adapted to team-level NHL performance.

## Executive summary (plain English)

- Teams that do very well one year often slide back the next.
- Teams that struggle one year often rebound.
- That mean-reversion pattern is the strongest signal in the data.
- Free-agent spending, whether measured as raw dollars or weighted by position importance, is not a reliable stand-alone predictor of improvement in this model setup.

In short: **where a team starts is usually more predictive than how much it spends in unrestricted free agency.**

## What this means

For fans, analysts, and decision-makers: offseason spending absolutely matters at the player level, but this project suggests it is often over-credited at the team level. The bigger story is still baseline team quality and natural performance correction.

## What you can explore on the site

The dashboard is designed so you do not need a technical background to use it.

- **Welcome**: the short version of the study and why it matters.
- **Key Findings**: the core research questions answered in plain language.
- **Overview**: league-wide team rankings by Movement Impact Score (MIS), season by season.
- **Team Detail**: one team and season at a time, with signing-level context.
- **All Signings**: a filterable table of individual movement events.
- **Audit**: quality checks for links, language clarity, and page health.

Dashboard pages live in `dashboard/src`.

## Scope and boundaries

This version is intentionally focused so the results stay interpretable.

- Primary focus is unrestricted free-agent movement and team-level outcomes.
- Team performance is evaluated year over year.
- Models include controls for prior-season performance and selected season context variables.
- COVID-affected seasons are tested in a restricted-sample sensitivity check.

Out of scope for this version are full roster-building effects from drafting, player development pipelines, and other non-UFA acquisition channels.

## Data and pipeline at a glance

The work runs as a reproducible pipeline:

1. Extract source data.
2. Clean and standardize records.
3. Engineer features (including MIS and cap/geography variables).
4. Build the team-season panel.
5. Run descriptive and regression analysis.
6. Publish tables and visuals that power the dashboard.

Top-level workflow folders:

- `R/01_data_extraction`
- `R/02_data_cleaning`
- `R/03_feature_engineering`
- `R/04_analysis`
- `R/05_visualization`

## Repository structure

- `dashboard/src`: static dashboard pages and shared audit core.
- `data/raw`: extracted source files.
- `data/processed`: cleaned, analysis-ready datasets.
- `output/tables`: model outputs, summaries, QA exports, and audit reports.
- `output/figures`: generated visuals.
- `scripts/run_audit.js`: Node-based automated site audit runner.
- `docs`: project scope, methodology notes, and audit checklist.

## For non-technical readers

If you were sent this from LinkedIn and want the quick version:

1. Start at the live site.
2. Read **Welcome** and **Key Findings** first.
3. Use **Overview** and **Team Detail** to check the teams you care about.

No local setup is required to use the dashboard.

## For technical reviewers and collaborators

### Core tools

- R (analysis pipeline)
- tidyverse ecosystem
- nhlscraper
- rvest
- Node.js (dashboard audit tooling)

### Run the dashboard audit

Use the repository script:

```bash
npm run audit
```

This writes the report to `output/tables/audit_report.json`.

### Data handling note

Source and processed datasets may be regenerated as the pipeline evolves. Review `data/README.md` plus the extraction and cleaning scripts for the current regeneration flow.

## Documentation

- Scope definition: `docs/scope/scope_definition.md`
- Methodology notes: `docs/methodology/methodology_notes.md`
- Non-data user audit checklist: `docs/audit/non-data-user-audit-checklist.md`
- Security policy: `SECURITY.md`

## Project status

Active and evolving. The analysis and dashboard continue to be refined as new offseason data, QA checks, and usability improvements are added.
