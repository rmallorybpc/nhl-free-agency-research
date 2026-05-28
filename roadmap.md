# Roadmap

This project (V1) is complete. The research questions it set out to answer
have been answered, the site is built and self-auditing, and a team
forecast feature is live. This document captures where the work could go
next, for anyone interested in building on it, and as a record for future
contributors.

If you want to extend this project, the items below are organized by type
and tagged with a rough effort estimate. The data pipeline, cleaning
scripts, and feature engineering are all in the repo and reusable, so most
extensions build on an existing foundation rather than starting from
scratch.

Issues and pull requests are welcome. If you pick up one of these, opening
an issue first to discuss the approach is appreciated.

---

## What V1 covers (so you know the baseline)

The current project analyzes NHL unrestricted free agent (UFA) signings
from 2017 to 2025 and tests whether offseason activity predicts team
performance change the following season.

Key findings:
- Mean reversion is the dominant predictor of season-over-season change
  (coefficient -0.42, p < 0.001)
- Offseason UFA spending does not reliably predict team improvement,
  whether measured in raw dollars or a position-weighted Movement Impact
  Score
- Movement geography (within division, cross conference) does not reliably
  predict improvement either
- Findings hold when the COVID-affected 2020 and 2021 seasons are excluded

Deliberately out of scope in V1: trade deadline activity, restricted free
agents, AHL call-ups, entry-level signings, playoff performance, and
expected goals as a metric. These exclusions were scope decisions, not
oversights, and several appear below as future directions.

Data sources: Spotrac (contract and transaction data via page source
extraction), NHL API via the nhlscraper R package (team performance data).

---

## Research extensions

These add new analysis or new data to the research itself.

| Idea | Effort | Notes |
|---|---|---|
| Trade deadline analysis (rentals vs term acquisitions) | Large | The most natural next study. Requires a new movement-event taxonomy, mid-season data, and retained-salary tracking. The March deadline creates a clean before/after window |
| RFA signings analysis | Small | Restricted free agent data is already extracted in the raw file. Unfilter and flag it to compare RFA vs UFA outcomes. Good entry point for a contributor |
| Contract length vs team outcome | Small | Existing data has contract_years. A descriptive analysis of whether longer deals correlate with team change. Another good entry point |
| ELC / top prospect signings | Medium | The high-impact rookie class (e.g., a franchise prospect signing). Define a prospect threshold and flag separately |
| Age + contract length efficiency | Large | Requires extracting player age (Spotrac pages or nhlscraper bios) and defining a contract-efficiency outcome. Connects to aging-curve literature. Arguably its own study rather than an extension |
| Individual player reset effect | Large | The original behavioral economics framing (Hengchen Dai) applied at the player level rather than the team level. Needs per-player performance before and after a move |
| xGoals as performance metric | Large | Replace points percentage with expected goals. Requires aggregating play-by-play data across all games. nhlscraper has the calculation helpers but not a prebuilt team-season table |
| Empirical MIS weight calibration | Medium | The position tier weights (0.35/0.25/0.20/0.15/0.05) are prior assumptions. Derive them from the data instead |
| Top vs bottom pairing defenceman distinction | Medium | MIS currently treats all defencemen the same (Tier 2). Use ice time or RAPM to distinguish pairings |
| Playoff performance as outcome | Large | Add playoff data. Now cleaner to model because the 2025-26 LTIR rule change closed the playoff roster loophole that confounded prior seasons |
| Goalie starter-status tracking | Medium | Flag whether a goalie signing is a starter or backup acquisition, since the performance impact differs sharply |

---

## Site features

These improve the site without changing the research.

| Idea | Effort | Notes |
|---|---|---|
| Common Questions / FAQ page | Small | Curated answers to natural questions. No backend, no hallucination risk |
| Team comparison tool | Medium | Side-by-side view of two teams. Solves the "compare X to Y" use case |
| Internal search | Medium | Static search across pages using something like Lunr.js. No backend |
| Pre-computed insight cards | Small | Build-time "did you know" cards surfacing interesting data points |
| Methodology chatbot (RAG, methodology only) | Large | A retrieval-augmented chatbot scoped to the methodology and findings text, NOT the data values. Avoids hallucinating numbers. Requires a backend |
| Scenario sandbox (what-if signings) | Large | The NFL companion site has this. Lets users adjust inputs and see projected outcomes. Likely needs a backend and a live model |
| 2026 offseason data | Small | After July 1, 2026, extract the 2026 UFA signings from Spotrac and add 2026 to the analysis. The performance data extraction already supports dynamic season dates |

---

## Infrastructure and tooling

These were noted as out of scope when the automated audit feature was built.

| Idea | Effort | Notes |
|---|---|---|
| Headless browser visual regression testing | Medium | Catch layout breaks automatically across viewports |
| Lighthouse accessibility scoring | Small | Automated accessibility checks in CI |
| Audit failure notifications | Small | Alert when the scheduled audit fails |
| Historical audit trend tracking | Medium | Track quality over time rather than only the latest run |

---

## How the pieces fit together

If you are picking this up, the dependency order matters:

- Most research extensions build on the existing data pipeline in
  `R/01_data_extraction` through `R/03_feature_engineering`. The cleaned
  and feature-engineered files in `data/processed/` are the join points.
- Adding a new data dimension (age, individual player stats, playoff data)
  usually means a new extraction script plus a new feature-engineering
  step, then a re-join into the master analysis panel.
- The site reads everything from the CSV files in `data/processed/` and
  `output/tables/` via client-side fetch. New analysis outputs that follow
  the same CSV pattern can be surfaced on the site without backend work.
- Anything requiring per-request computation (the methodology chatbot, the
  scenario sandbox) breaks the static architecture and needs a backend.
  Everything else can stay static on GitHub Pages.

---

## Good entry points for contributors

If you want to contribute and are looking for a manageable first piece:

1. **RFA signings analysis** — the data is already extracted, you just
   need to unfilter and analyze the restricted free agents
2. **Contract length vs team outcome** — a descriptive analysis using
   columns that already exist
3. **Common Questions page** — a static page that improves usability with
   no backend

Each of these is roughly an afternoon and does not require new data
sources.

---

*Roadmap maintained as of the V1 project close, May 2026. The research
methodology and scope decisions are documented in METHODS.md.*
