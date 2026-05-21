# 03_geographic_analysis.R
# Descriptive geography analysis for NHL UFA signings.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
	library(broom)
})

signings_path <- here::here("data", "processed", "nhl_signed_free_agents_clean.csv")
panel_path <- here::here("data", "processed", "nhl_master_analysis_panel.csv")
output_dir <- here::here("output", "tables")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

signings_raw <- read_csv(signings_path, show_col_types = FALSE)
panel_raw <- read_csv(panel_path, show_col_types = FALSE)

signings_filtered <- signings_raw %>%
	filter(
		!same_team_resign,
		is.na(data_quality_note),
		!is.na(movement_geography)
	) %>%
	rename(season_year = spotrac_year) %>%
	mutate(season_year = as.integer(season_year))

panel_for_join <- panel_raw %>%
	mutate(
		season_year = as.integer(season_year),
		# Team-level season-over-season performance change.
		points_pct_change = points_percentage - prior_season_points_pct
	) %>%
	select(teamTriCode, season_year, points_pct_change, pct_cross_conference, prior_season_points_pct)

signings_with_outcomes <- signings_filtered %>%
	# This attributes each signing to the signing team's full-season outcome,
	# matching the NFL-site methodology.
	left_join(
		panel_for_join %>% select(teamTriCode, season_year, points_pct_change),
		by = c("signing_team" = "teamTriCode", "season_year")
	) %>%
	filter(season_year >= 2018L, season_year <= 2025L)

geo_levels <- c("within_division", "cross_division_same_conference", "cross_conference")

overall_summary <- signings_with_outcomes %>%
	filter(movement_geography %in% geo_levels, !is.na(points_pct_change)) %>%
	group_by(movement_geography) %>%
	summarise(
		mean_change = mean(points_pct_change, na.rm = TRUE),
		sd_change = sd(points_pct_change, na.rm = TRUE),
		signing_count = n(),
		.groups = "drop"
	)

overall_spread <- overall_summary %>%
	summarise(spread = max(mean_change, na.rm = TRUE) - min(mean_change, na.rm = TRUE)) %>%
	pull(spread)

overall_summary <- overall_summary %>%
	mutate(high_low_mean_spread = overall_spread) %>%
	arrange(desc(mean_change))

write_csv(
	overall_summary,
	file.path(output_dir, "geography_overall_summary.csv")
)

season_long <- signings_with_outcomes %>%
	filter(movement_geography %in% geo_levels, !is.na(points_pct_change)) %>%
	group_by(season_year, movement_geography) %>%
	summarise(
		mean_change = mean(points_pct_change, na.rm = TRUE),
		signing_count = n(),
		.groups = "drop"
	)

season_totals <- signings_with_outcomes %>%
	filter(movement_geography %in% geo_levels, !is.na(points_pct_change)) %>%
	group_by(season_year) %>%
	summarise(signing_count_total = n(), .groups = "drop")

season_top <- season_long %>%
	group_by(season_year) %>%
	slice_max(order_by = mean_change, n = 1, with_ties = FALSE) %>%
	ungroup() %>%
	transmute(season_year, top_ranked_category = movement_geography)

season_wide <- season_long %>%
	select(season_year, movement_geography, mean_change) %>%
	pivot_wider(
		names_from = movement_geography,
		values_from = mean_change
	) %>%
	rename(
		within_division_mean = within_division,
		cross_division_mean = cross_division_same_conference,
		cross_conference_mean = cross_conference
	)

by_season_summary <- season_wide %>%
	left_join(season_totals, by = "season_year") %>%
	left_join(season_top, by = "season_year") %>%
	select(
		season_year,
		within_division_mean,
		cross_division_mean,
		cross_conference_mean,
		signing_count_total,
		top_ranked_category
	) %>%
	arrange(season_year)

write_csv(
	by_season_summary,
	file.path(output_dir, "geography_by_season.csv")
)

seasons_ranked_first <- season_top %>%
	count(top_ranked_category, name = "seasons_ranked_first") %>%
	rename(category = top_ranked_category) %>%
	right_join(tibble(category = geo_levels), by = "category") %>%
	mutate(
		seasons_ranked_first = coalesce(seasons_ranked_first, 0L),
		total_seasons = n_distinct(by_season_summary$season_year)
	)

write_csv(
	seasons_ranked_first,
	file.path(output_dir, "geography_seasons_ranked_first.csv")
)

# Supplementary test only: team-level association between cross-conference share
# and season-over-season performance change.
regression_data <- panel_for_join %>%
	filter(season_year >= 2018L, season_year <= 2025L) %>%
	filter(!is.na(points_pct_change), !is.na(pct_cross_conference), !is.na(prior_season_points_pct))

geo_model <- lm(
	points_pct_change ~ pct_cross_conference + prior_season_points_pct,
	data = regression_data
)

geo_regression <- tidy(geo_model, conf.int = TRUE) %>%
	transmute(
		term,
		estimate,
		std_error = std.error,
		statistic,
		p_value = p.value,
		conf_low = conf.low,
		conf_high = conf.high
	)

write_csv(
	geo_regression,
	file.path(output_dir, "geography_regression.csv")
)

qa_total_signings <- nrow(signings_with_outcomes %>% filter(!is.na(points_pct_change)))
qa_means <- overall_summary %>% select(movement_geography, mean_change)
qa_sds <- overall_summary %>% select(movement_geography, sd_change)
qa_spread <- overall_spread
qa_rank_counts <- seasons_ranked_first %>% select(category, seasons_ranked_first, total_seasons)

cat("\n=== Geography Analysis QA Checks ===\n")
cat("Total signings analyzed:", qa_total_signings, "\n")
cat("Mean points_pct_change by geography category:\n")
print(qa_means, n = Inf)
cat("Difference between highest and lowest mean:", round(qa_spread, 6), "\n")
cat("Within-group standard deviation by category:\n")
print(qa_sds, n = Inf)
cat("Number of seasons each category ranked highest:\n")
print(qa_rank_counts, n = Inf)

highest_row <- overall_summary %>% slice_max(mean_change, n = 1, with_ties = FALSE)
lowest_row <- overall_summary %>% slice_min(mean_change, n = 1, with_ties = FALSE)

if (qa_spread < 0.010) {
	cat(
		"\nFinding: no meaningful geography effect — categories cluster within 1 percentage point of each other.\n"
	)
} else {
	cat(
		"\nFinding: geography appears to matter —",
		highest_row$movement_geography[[1]],
		"shows mean points_pct_change of",
		sprintf("%.3f", highest_row$mean_change[[1]]),
		"vs",
		lowest_row$movement_geography[[1]],
		"at",
		sprintf("%.3f", lowest_row$mean_change[[1]]),
		"\n"
	)
}

cat("Geographic analysis complete. Outputs written to output/tables/.\n")
