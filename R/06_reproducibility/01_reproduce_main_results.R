# 01_reproduce_main_results.R
# Re-runs the core Version 1 pipeline from cleaned raw inputs through regression outputs.

suppressPackageStartupMessages({
  library(here)
})

pipeline_scripts <- c(
  here::here("R", "02_data_cleaning", "01_clean_spotrac.R"),
  here::here("R", "02_data_cleaning", "02_clean_performance.R"),
  here::here("R", "03_feature_engineering", "01_build_MIS.R"),
  here::here("R", "03_feature_engineering", "02_build_cap_variables.R"),
  here::here("R", "03_feature_engineering", "03_build_geography.R"),
  here::here("R", "03_feature_engineering", "05_build_net_aav.R"),
  here::here("R", "03_feature_engineering", "06_build_contract_length.R"),
  here::here("R", "03_feature_engineering", "07_build_retention.R"),
  here::here("R", "03_feature_engineering", "04_build_master_panel.R"),
  here::here("R", "04_analysis", "01_descriptive_stats.R"),
  here::here("R", "04_analysis", "02_regression_models.R"),
  here::here("R", "04_analysis", "03_geographic_analysis.R"),
  here::here("R", "05_visualization", "01_plots.R")
)

cat("Starting reproducible pipeline run...\n")

for (script_path in pipeline_scripts) {
  if (!file.exists(script_path)) {
    stop(paste("Missing pipeline script:", script_path))
  }

  cat("Running:", script_path, "\n")
  source(script_path, chdir = FALSE)
}

cat("\nPipeline complete. Key refreshed outputs include:\n")
cat("- data/processed/nhl_master_analysis_panel.csv\n")
cat("- output/tables/model_a_full_coefficients.csv\n")
cat("- output/tables/model_b_full_coefficients.csv\n")
cat("- output/tables/model_a_restricted_coefficients.csv\n")
cat("- output/tables/model_b_restricted_coefficients.csv\n")
cat("- output/tables/model_c_full_coefficients.csv\n")
cat("- output/tables/model_c_restricted_coefficients.csv\n")
cat("- output/tables/model_d_full_coefficients.csv\n")
cat("- output/tables/model_d_restricted_coefficients.csv\n")
cat("- output/tables/model_e_full_coefficients.csv\n")
cat("- output/tables/model_e_restricted_coefficients.csv\n")
cat("- output/tables/model_f_full_coefficients.csv\n")
cat("- output/tables/model_f_restricted_coefficients.csv\n")
cat("- output/tables/model_comparison_summary.csv\n")
