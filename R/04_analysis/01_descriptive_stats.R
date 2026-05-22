# 01_descriptive_stats.R
# Build quartile-based mean reversion summary tables and recent team examples.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
})

panel_path <- here::here("data", "processed", "nhl_master_analysis_panel.csv")
quartile_summary_path <- here::here("output", "tables", "quartile_summary.csv")
quartile_examples_path <- here::here("output", "tables", "quartile_examples.csv")

panel <- readr::read_csv(panel_path, show_col_types = FALSE) %>%
	mutate(
		points_pct_change = if ("points_pct_change" %in% names(.)) {
			points_pct_change
		} else {
			points_percentage - prior_season_points_pct
		}
	) %>%
	filter(
		!is.na(prior_season_points_pct),
		!is.na(points_pct_change),
		!is.na(season_year)
	) %>%
	mutate(
		quartile = ntile(prior_season_points_pct, 4),
		quartile_label = case_when(
			quartile == 1 ~ "Q1 Bottom 25%",
			quartile == 2 ~ "Q2 Lower mid",
			quartile == 3 ~ "Q3 Upper mid",
			quartile == 4 ~ "Q4 Top 25%",
			TRUE ~ "Unknown"
		)
	)

quartile_summary <- panel %>%
	group_by(quartile, quartile_label) %>%
	summarise(
		points_pct_min = min(prior_season_points_pct, na.rm = TRUE),
		points_pct_max = max(prior_season_points_pct, na.rm = TRUE),
		mean_change = mean(points_pct_change, na.rm = TRUE),
		sd_change = sd(points_pct_change, na.rm = TRUE),
		team_count = n(),
		moved_predicted_direction_pct = 100 * mean(
			case_when(
				quartile == 4 ~ points_pct_change < 0,
				quartile == 1 ~ points_pct_change > 0,
				quartile %in% c(2, 3) ~ abs(points_pct_change) <= 0.01,
				TRUE ~ FALSE
			),
			na.rm = TRUE
		),
		.groups = "drop"
	) %>%
	arrange(quartile)

# Use recent seasons for examples so readers recognize teams more easily.
recent_panel <- panel %>%
	filter(season_year >= 2022, season_year <= 2025)

q4_examples <- recent_panel %>%
	filter(quartile == 4) %>%
	arrange(points_pct_change) %>%
	slice_head(n = 3)

q1_examples <- recent_panel %>%
	filter(quartile == 1) %>%
	arrange(desc(points_pct_change)) %>%
	slice_head(n = 3)

q2_examples <- recent_panel %>%
	filter(quartile == 2) %>%
	mutate(abs_change = abs(points_pct_change)) %>%
	arrange(abs_change, desc(season_year), teamCommonName) %>%
	slice_head(n = 3) %>%
	select(-abs_change)

q3_examples <- recent_panel %>%
	filter(quartile == 3) %>%
	mutate(abs_change = abs(points_pct_change)) %>%
	arrange(abs_change, desc(season_year), teamCommonName) %>%
	slice_head(n = 3) %>%
	select(-abs_change)

quartile_examples <- bind_rows(q1_examples, q2_examples, q3_examples, q4_examples) %>%
	group_by(quartile, quartile_label) %>%
	arrange(
		case_when(
			quartile == 4 ~ points_pct_change,
			quartile == 1 ~ -points_pct_change,
			TRUE ~ abs(points_pct_change)
		),
		.by_group = TRUE
	) %>%
	mutate(example_rank = row_number()) %>%
	ungroup() %>%
	transmute(
		quartile,
		quartile_label,
		example_rank,
		teamCommonName,
		teamTriCode,
		season_year,
		prior_season_points_pct = round(prior_season_points_pct, 3),
		points_percentage = round(points_percentage, 3),
		points_pct_change = round(points_pct_change, 3)
	) %>%
	arrange(desc(quartile), example_rank)

readr::write_csv(quartile_summary, quartile_summary_path)
readr::write_csv(quartile_examples, quartile_examples_path)

cat("\nQuartile summary (mean change by quartile):\n")
quartile_summary %>%
	select(quartile, quartile_label, mean_change, sd_change, team_count) %>%
	print(n = Inf)

worst_q4_fall <- quartile_examples %>%
	filter(quartile == 4) %>%
	slice_min(points_pct_change, n = 1, with_ties = FALSE)

best_q1_bounce <- quartile_examples %>%
	filter(quartile == 1) %>%
	slice_max(points_pct_change, n = 1, with_ties = FALSE)

cat("\nMost extreme Q4 fall (team, season, change):\n")
worst_q4_fall %>%
	select(teamCommonName, season_year, points_pct_change) %>%
	print(n = Inf)

cat("\nMost extreme Q1 bounce (team, season, change):\n")
best_q1_bounce %>%
	select(teamCommonName, season_year, points_pct_change) %>%
	print(n = Inf)

cat("\nProportion moving in predicted direction by quartile (%):\n")
quartile_summary %>%
	select(quartile, quartile_label, moved_predicted_direction_pct) %>%
	print(n = Inf)

cat("\nWrote files:\n")
cat(" - ", quartile_summary_path, "\n", sep = "")
cat(" - ", quartile_examples_path, "\n", sep = "")
