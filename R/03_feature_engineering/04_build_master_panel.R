# 04_build_master_panel.R
# Join processed team-season feature files into a master analysis panel.

library(tidyverse)
library(here)

performance <- read_csv(
	here::here("data", "processed", "nhl_team_season_performance_clean.csv"),
	show_col_types = FALSE
) %>%
	mutate(
		season_year = as.integer(season_year),
		prior_season_year = as.integer(prior_season_year)
	)

mis_scores <- read_csv(
	here::here("data", "processed", "nhl_team_mis_scores.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		teamTriCode = signing_team,
		season_year = as.integer(season_year),
		total_mis,
		total_aav_spent,
		signing_count,
		signing_count_tier1,
		signing_count_tier2,
		signing_count_tier3,
		signing_count_tier4,
		has_goalie_signing,
		offseason_data_pending
	)

cap_variables <- read_csv(
	here::here("data", "processed", "nhl_team_cap_variables.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		teamTriCode = signing_team,
		season_year = as.integer(season_year),
		total_aav_committed,
		total_contract_value,
		signing_count_cap,
		cap_ceiling,
		cap_ceiling_change,
		cap_spending_pct,
		near_cap_floor,
		heavy_spender
	)

geography_variables <- read_csv(
	here::here("data", "processed", "nhl_team_geography_variables.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		teamTriCode = signing_team,
		season_year = as.integer(season_year),
		count_within_division,
		count_cross_division,
		count_cross_conference,
		total_signing_count,
		pct_cross_conference,
		any_cross_conference
	)

prior_points_lookup <- performance %>%
	transmute(
		teamTriCode,
		prior_season_year = season_year,
		prior_season_points_pct = points_percentage
	)

league_prior_points_lookup <- performance %>%
	group_by(season_year) %>%
	summarise(league_prior_season_points_pct = mean(points_percentage, na.rm = TRUE), .groups = "drop") %>%
	rename(prior_season_year = season_year)

master_panel <- performance %>%
	mutate(
		# Franchise continuity bridge for Utah relocation rows.
		prior_points_team_code = case_when(
			teamTriCode == "UTA" ~ "ARI",
			TRUE ~ teamTriCode
		)
	) %>%
	left_join(
		mis_scores,
		by = c("teamTriCode", "season_year")
	) %>%
	left_join(
		cap_variables,
		by = c("teamTriCode", "season_year")
	) %>%
	left_join(
		geography_variables,
		by = c("teamTriCode", "season_year")
	) %>%
	left_join(
		prior_points_lookup,
		by = c("prior_points_team_code" = "teamTriCode", "prior_season_year")
	) %>%
	left_join(
		league_prior_points_lookup,
		by = "prior_season_year"
	) %>%
	mutate(
		# Expansion teams with no prior franchise season use prior-year league mean.
		prior_season_points_pct = coalesce(prior_season_points_pct, league_prior_season_points_pct)
	) %>%
	filter(season_year >= 2018L, season_year <= 2026L) %>%
	group_by(season_year) %>%
	mutate(
		season_mis_min = min(total_mis, na.rm = TRUE),
		season_mis_max = max(total_mis, na.rm = TRUE),
		mis_index = case_when(
			is.na(total_mis) ~ NA_real_,
			season_mis_max > season_mis_min ~ ((total_mis - season_mis_min) / (season_mis_max - season_mis_min)) * 100,
			TRUE ~ 0
		),
		mis_index = round(mis_index, 1)
	) %>%
	ungroup() %>%
	select(-prior_points_team_code, -league_prior_season_points_pct) %>%
	select(-season_mis_min, -season_mis_max) %>%
	arrange(season_year, teamTriCode)

key_analysis_columns <- c(
	"points_percentage",
	"prior_season_points_pct",
	"total_mis",
	"total_aav_spent",
	"cap_spending_pct",
	"count_within_division",
	"count_cross_division",
	"count_cross_conference",
	"pct_cross_conference"
)

key_na_counts <- master_panel %>%
	summarise(across(all_of(key_analysis_columns), ~ sum(is.na(.x)))) %>%
	pivot_longer(cols = everything(), names_to = "column", values_to = "na_count")

write_csv(
	master_panel,
	here::here("data", "processed", "nhl_master_analysis_panel.csv")
)

cat("===== MASTER PANEL QA CHECKS =====\n")
cat("Row count:", nrow(master_panel), "(expected 284)\n")
cat("Column count:", ncol(master_panel), "\n")

if (all(key_na_counts$na_count == 0)) {
	cat("Key analysis columns NA check: PASS (zero NAs in all key analysis columns)\n")
} else {
	cat("Key analysis columns NA check: FAIL (non-zero NAs detected)\n")
	print(key_na_counts %>% filter(na_count > 0))
}

cat("Master panel build complete. Rows written:", nrow(master_panel), "\n")