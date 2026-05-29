# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - 2026-05-29

### Added
- New team-season feature script [R/03_feature_engineering/05_build_net_aav.R](R/03_feature_engineering/05_build_net_aav.R) and output [data/processed/nhl_team_net_aav.csv](data/processed/nhl_team_net_aav.csv).
- New team-season feature script [R/03_feature_engineering/06_build_contract_length.R](R/03_feature_engineering/06_build_contract_length.R) and output [data/processed/nhl_team_contract_length.csv](data/processed/nhl_team_contract_length.csv).
- New team-season feature script [R/03_feature_engineering/07_build_retention.R](R/03_feature_engineering/07_build_retention.R) and output [data/processed/nhl_team_retention.csv](data/processed/nhl_team_retention.csv).
- Eight new model coefficient outputs for Models C-F (full and restricted):
  - [output/tables/model_c_full_coefficients.csv](output/tables/model_c_full_coefficients.csv)
  - [output/tables/model_c_restricted_coefficients.csv](output/tables/model_c_restricted_coefficients.csv)
  - [output/tables/model_d_full_coefficients.csv](output/tables/model_d_full_coefficients.csv)
  - [output/tables/model_d_restricted_coefficients.csv](output/tables/model_d_restricted_coefficients.csv)
  - [output/tables/model_e_full_coefficients.csv](output/tables/model_e_full_coefficients.csv)
  - [output/tables/model_e_restricted_coefficients.csv](output/tables/model_e_restricted_coefficients.csv)
  - [output/tables/model_f_full_coefficients.csv](output/tables/model_f_full_coefficients.csv)
  - [output/tables/model_f_restricted_coefficients.csv](output/tables/model_f_restricted_coefficients.csv)

### Changed
- Extended master panel build to join V1.1 variables in [R/03_feature_engineering/04_build_master_panel.R](R/03_feature_engineering/04_build_master_panel.R).
- Expanded model runner to 12 models and updated comparison summary in [R/04_analysis/02_regression_models.R](R/04_analysis/02_regression_models.R).
- Updated reproducibility runner to include new V1.1 scripts in [R/06_reproducibility/01_reproduce_main_results.R](R/06_reproducibility/01_reproduce_main_results.R).
- Added dynamic V1.1 verdict section to [dashboard/src/findings.html](dashboard/src/findings.html).
- Added V1.1 method notes and model specs to [dashboard/src/methods.html](dashboard/src/methods.html) and [METHODS.md](METHODS.md).

### Results snapshot
- Net spending (`net_aav`) is statistically meaningful in Model C and Model F (full and restricted samples).
- Contract term features are not statistically meaningful in the V1.1 model set.
- Retention rate is not statistically meaningful in full sample and suggestive in one restricted model.
