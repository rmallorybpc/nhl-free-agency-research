# NHL Free Agency Research

An applied sports analytics project built around one front-office question:

**Does spending in NHL unrestricted free agency (UFA) predict team improvement the next season?**

Live dashboard: https://rmallorybpc.github.io/nhl-free-agency-research/

## Start here (choose your path)

- If you want the non-technical summary: jump to **For general readers**.
- If you want methods, code, and reproducibility: jump to **For technical and data users**.

## Executive summary (plain English)

- Teams that perform very well one year often decline the next year.
- Teams that struggle one year often improve the next year.
- This bounce-back pattern (mean reversion) is the strongest and most consistent signal in the data.
- UFA spending, by itself, is not a reliable stand-alone predictor of next-season improvement in this model setup.

Bottom line: **starting team quality is usually more predictive than total UFA spending.**

## Why this project exists

Offseason narratives often focus on who spent the most and who "won July." This project tests whether those narratives hold up when evaluated across multiple seasons and all teams.

The framing is informed by behavioral economics research on "fresh start" effects (including Hengchen Dai's work), adapted here to team-level NHL performance.

## For general readers

### What this study means in practice

Spending still matters at the player level. But at the team level, this project suggests spending is often over-credited compared with baseline team strength and natural year-to-year correction.

### How to use the dashboard (no setup required)

1. Open the live dashboard.
2. Read **Welcome** for the short story.
3. Read **Key Findings** for direct answers.
4. Use **Overview** to compare teams by season.
5. Use **Team Detail** and **All Signings** to inspect specific teams and contracts.

### Dashboard pages at a glance

- **Welcome**: short, non-technical project overview.
- **Key Findings**: headline results in plain language.
- **Overview**: season-by-season team ranking view.
- **Team Detail**: team and season deep-dive.
- **All Signings**: filterable movement table.
- **Audit**: readability and site quality checks.

Dashboard source lives in `dashboard/src`.

## For technical and data users

### Scope and boundaries

- Focus: UFA movement and team-level outcomes.
- Outcome: year-over-year team performance change.
- Controls: prior-season performance plus selected season context variables.
- Sensitivity check: restricted sample excluding COVID-affected seasons.

Out of scope in Version 1:

- Draft pipeline effects.
- Prospect development effects.
- Non-UFA roster channels (for example, most trade and call-up dynamics).

### Data and workflow overview

Pipeline stages:

1. Extract source data.
2. Clean and standardize records.
3. Engineer features (MIS, cap variables, geography variables).
4. Build the master team-season panel.
5. Run descriptive and regression models.
6. Export tables/figures used by the dashboard.

Top-level workflow folders:

- `R/01_data_extraction`
- `R/02_data_cleaning`
- `R/03_feature_engineering`
- `R/04_analysis`
- `R/05_visualization`
- `R/06_reproducibility`

### Reproduce core results

From repository root:

```bash
Rscript R/06_reproducibility/01_reproduce_main_results.R
```

Primary generated outputs include:

- `data/processed/nhl_master_analysis_panel.csv`
- `output/tables/model_a_full_coefficients.csv`
- `output/tables/model_b_full_coefficients.csv`
- `output/tables/model_a_restricted_coefficients.csv`
- `output/tables/model_b_restricted_coefficients.csv`
- `output/tables/model_comparison_summary.csv`

### Run dashboard audit tooling

```bash
npm run audit
```

Audit output is written to `output/tables/audit_report.json`.

### Repository structure

- `dashboard/src`: static pages and shared audit core.
- `data/raw`: source extracts.
- `data/processed`: cleaned, analysis-ready tables.
- `output/tables`: model outputs, QA exports, and audits.
- `output/figures`: generated plots.
- `scripts/run_audit.js`: Node-based audit runner.
- `docs`: scope, methodology, and audit docs.

### Data handling note

Raw and processed data are expected to be regenerated as the pipeline evolves. See `data/README.md` and relevant extraction/cleaning scripts for the current flow.

## Key definitions

- **UFA**: unrestricted free agent.
- **MIS (Movement Impact Score)**: a position-weighted summary of offseason UFA spending.
- **Mean reversion**: teams far above or below average often move back toward average the following season.

## Documentation

- Scope definition: `docs/scope/scope_definition.md`
- Methods appendix: `METHODS.md`
- Methodology notes: `docs/methodology/methodology_notes.md`
- Non-data user audit checklist: `docs/audit/non-data-user-audit-checklist.md`
- Security policy: `SECURITY.md`

## Project status

Active and evolving. Analysis, dashboard content, and QA checks are updated as new offseason data becomes available.
