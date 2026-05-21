# 02_regression_models.R
# Runs core regression analysis for the NHL free agency research project.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
	library(broom)
})

input_path <- here::here("data", "processed", "nhl_master_analysis_panel.csv")
output_dir <- here::here("output", "tables")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

panel_raw <- read_csv(input_path, show_col_types = FALSE)
season_type_levels <- panel_raw %>%
	distinct(season_type) %>%
	pull(season_type) %>%
	as.character() %>%
	sort()

panel <- panel_raw %>%
	mutate(
		season_type = factor(season_type, levels = season_type_levels),
		# Season-over-season performance change at the team level:
		# positive values indicate improvement, negative values indicate decline.
		points_pct_change = points_percentage - prior_season_points_pct
	)

# Full analysis sample: all rows in the master panel (expected 252 rows),
# covering seasons 2018 through 2025.
panel_full <- panel

# COVID-restricted sensitivity sample: excludes covid_shortened and covid_bubble
# seasons (2020 and 2021). Expected row count is 190 rows: 8 seasons minus 2
# COVID seasons times historically accurate team counts per remaining season.
panel_restricted <- panel %>%
	filter(!season_type %in% c("covid_shortened", "covid_bubble"))

# Model A Full tests whether raw offseason spending (total_aav_spent), controlling
# for baseline team strength and macro context, explains next-season change.
model_a_full <- lm(
	points_pct_change ~ total_aav_spent + prior_season_points_pct + season_type + cap_ceiling_change,
	data = panel_full
)

# Model B Full tests whether weighted Movement Impact Score (total_mis), controlling
# for the same covariates, provides stronger explanatory power than raw spending.
model_b_full <- lm(
	points_pct_change ~ total_mis + prior_season_points_pct + season_type + cap_ceiling_change,
	data = panel_full
)

# Model A Restricted repeats the raw spending specification excluding COVID-affected seasons.
# If season_type has no variation after exclusion, it cannot be estimated and is
# dropped only for restricted-sample feasibility.
restricted_has_season_type_variation <- n_distinct(panel_restricted$season_type) > 1

if (restricted_has_season_type_variation) {
	model_a_restricted <- lm(
		points_pct_change ~ total_aav_spent + prior_season_points_pct + season_type + cap_ceiling_change,
		data = panel_restricted
	)
} else {
	cat("\nNOTE: panel_restricted has one season_type level; dropping season_type from restricted models.\n")
	model_a_restricted <- lm(
		points_pct_change ~ total_aav_spent + prior_season_points_pct + cap_ceiling_change,
		data = panel_restricted
	)
}

# Model B Restricted repeats the weighted MIS specification excluding COVID-affected seasons.
# If season_type has no variation after exclusion, it cannot be estimated and is
# dropped only for restricted-sample feasibility.
if (restricted_has_season_type_variation) {
	model_b_restricted <- lm(
		points_pct_change ~ total_mis + prior_season_points_pct + season_type + cap_ceiling_change,
		data = panel_restricted
	)
} else {
	model_b_restricted <- lm(
		points_pct_change ~ total_mis + prior_season_points_pct + cap_ceiling_change,
		data = panel_restricted
	)
}

model_objects <- list(
	"Model A Full" = model_a_full,
	"Model B Full" = model_b_full,
	"Model A Restricted" = model_a_restricted,
	"Model B Restricted" = model_b_restricted
)

tidy_outputs <- imap(model_objects, ~ tidy(.x) %>% mutate(model_name = .y))
glance_outputs <- imap_dfr(model_objects, ~ glance(.x) %>% mutate(model_name = .y), .id = NULL)

# Persist coefficient tables and model-comparison summary table.
write_csv(tidy_outputs[["Model A Full"]], file.path(output_dir, "model_a_full_coefficients.csv"))
write_csv(tidy_outputs[["Model B Full"]], file.path(output_dir, "model_b_full_coefficients.csv"))
write_csv(tidy_outputs[["Model A Restricted"]], file.path(output_dir, "model_a_restricted_coefficients.csv"))
write_csv(tidy_outputs[["Model B Restricted"]], file.path(output_dir, "model_b_restricted_coefficients.csv"))

comparison_summary <- glance_outputs %>%
	select(model_name, r.squared, adj.r.squared, AIC, BIC, nobs)

write_csv(comparison_summary, file.path(output_dir, "model_comparison_summary.csv"))

extract_primary_significance <- function(tidy_df) {
	primary_row <- tidy_df %>%
		filter(term %in% c("total_mis", "total_aav_spent")) %>%
		slice_head(n = 1)

	if (nrow(primary_row) == 0) {
		return(list(term = NA_character_, p_value = NA_real_, sig_005 = "No", sig_010 = "No"))
	}

	p_val <- primary_row$p.value[[1]]
	list(
		term = primary_row$term[[1]],
		p_value = p_val,
		sig_005 = ifelse(!is.na(p_val) && p_val < 0.05, "Yes", "No"),
		sig_010 = ifelse(!is.na(p_val) && p_val < 0.10, "Yes", "No")
	)
}

primary_sig <- imap_dfr(tidy_outputs, function(tbl, name) {
	sig <- extract_primary_significance(tbl)
	tibble(
		model_name = name,
		primary_variable = sig$term,
		primary_p_value = sig$p_value,
		primary_sig_p_lt_0_05 = sig$sig_005,
		primary_sig_p_lt_0_10 = sig$sig_010
	)
})

comparison_console <- comparison_summary %>%
	left_join(primary_sig, by = "model_name") %>%
	arrange(match(model_name, names(model_objects)))

cat("\n=== Model Comparison Summary ===\n")
print(comparison_console, n = Inf)

significance_stars <- function(p_value) {
	case_when(
		is.na(p_value) ~ "",
		p_value < 0.001 ~ "***",
		p_value < 0.01 ~ "**",
		p_value < 0.05 ~ "*",
		p_value < 0.10 ~ ".",
		TRUE ~ ""
	)
}

format_coefs_for_console <- function(tidy_df) {
	tidy_df %>%
		mutate(
			sig = significance_stars(p.value),
			estimate = round(estimate, 6),
			std.error = round(std.error, 6),
			statistic = round(statistic, 3),
			p.value = round(p.value, 6)
		) %>%
		select(term, estimate, std.error, statistic, p.value, sig)
}

cat("\n=== Coefficient Tables (with significance stars) ===\n")
cat("Significance: *** p < 0.001, ** p < 0.01, * p < 0.05, . p < 0.10\n")

for (model_name in names(tidy_outputs)) {
	cat("\n---", model_name, "---\n")
	print(format_coefs_for_console(tidy_outputs[[model_name]]), n = Inf)
}

# Inline QA checks for dependent variable behavior and expected sample sizes.
dp_mean <- mean(panel$points_pct_change, na.rm = TRUE)
dp_min <- suppressWarnings(min(panel$points_pct_change, na.rm = TRUE))
dp_max <- suppressWarnings(max(panel$points_pct_change, na.rm = TRUE))

dp_has_non_finite <- any(!is.finite(panel$points_pct_change))
dp_has_nan <- any(is.nan(panel$points_pct_change))

expected_full_n <- 252L
expected_restricted_n <- 190L
actual_full_n <- nrow(panel_full)
actual_restricted_n <- nrow(panel_restricted)

cat("\n=== QA Checks ===\n")
cat("Mean(points_pct_change):", round(dp_mean, 6), "(should be close to 0)\n")

if (abs(dp_mean) <= 0.01) {
	cat("QA PASS: Mean is close to zero.\n")
} else {
	cat("QA FLAG: Mean is not close to zero (>|0.01|).\n")
}

cat("Range(points_pct_change):", round(dp_min, 6), "to", round(dp_max, 6), "\n")
if (dp_min < -0.30 || dp_max > 0.30) {
	cat("QA FLAG: Range exceeds plausible bounds of -0.30 to 0.30.\n")
} else {
	cat("QA PASS: Range is within plausible bounds (-0.30 to 0.30).\n")
}

cat("panel_full rows:", actual_full_n, "(expected", expected_full_n, ")\n")
cat("panel_restricted rows:", actual_restricted_n, "(expected", expected_restricted_n, ")\n")

if (actual_full_n == expected_full_n) {
	cat("QA PASS: panel_full row count matches expected.\n")
} else {
	cat("QA FLAG: panel_full row count does not match expected.\n")
}

if (actual_restricted_n == expected_restricted_n) {
	cat("QA PASS: panel_restricted row count matches expected.\n")
} else {
	cat("QA FLAG: panel_restricted row count does not match expected.\n")
}

if (dp_has_non_finite || dp_has_nan) {
	cat("QA FLAG: points_pct_change contains infinite or NaN values.\n")
} else {
	cat("QA PASS: No infinite or NaN values in points_pct_change.\n")
}

completion_summary <- comparison_console %>%
	transmute(
		model_name,
		adj_r_squared = round(adj.r.squared, 6),
		primary_variable,
		significance = case_when(
			primary_sig_p_lt_0_05 == "Yes" ~ "p < 0.05",
			primary_sig_p_lt_0_10 == "Yes" ~ "p < 0.10",
			TRUE ~ "not significant at p < 0.10"
		)
	)

cat("\n=== Completion Summary ===\n")
for (i in seq_len(nrow(completion_summary))) {
	row <- completion_summary[i, ]
	cat(
		row$model_name,
		"| adj. R^2 =", row$adj_r_squared,
		"|", row$primary_variable,
		"significance:", row$significance,
		"\n"
	)
}
