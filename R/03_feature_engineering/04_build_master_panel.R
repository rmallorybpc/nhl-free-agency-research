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

net_aav_variables <- read_csv(
	here::here("data", "processed", "nhl_team_net_aav.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		teamTriCode = signing_team,
		season_year = as.integer(season_year),
		net_total_aav_committed = total_aav_committed,
		total_aav_lost,
		net_aav
	)

contract_length_variables <- read_csv(
	here::here("data", "processed", "nhl_team_contract_length.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		teamTriCode = signing_team,
		season_year = as.integer(season_year),
		mean_contract_years,
		max_contract_years,
		count_long_term,
		weighted_avg_years
	)

retention_variables <- read_csv(
	here::here("data", "processed", "nhl_team_retention.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		teamTriCode = signing_team,
		season_year = as.integer(season_year),
		total_ufa_decisions,
		count_re_signed,
		count_new_signings,
		pct_retained,
		aav_retained,
		aav_new,
		pct_aav_retained,
		no_ufa_activity
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
		net_aav_variables,
		by = c("teamTriCode", "season_year")
	) %>%
	left_join(
		contract_length_variables,
		by = c("teamTriCode", "season_year")
	) %>%
	left_join(
		retention_variables,
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
		prior_season_points_pct = coalesce(prior_season_points_pct, league_prior_season_points_pct),
		# The three V1.1 feature files provide full 2017-2025 coverage; fallback values
		# ensure deterministic behavior if future-season rows are present upstream.
		net_total_aav_committed = coalesce(net_total_aav_committed, 0),
		total_aav_lost = coalesce(total_aav_lost, 0),
		net_aav = coalesce(net_aav, 0),
		mean_contract_years = coalesce(mean_contract_years, 0),
		max_contract_years = coalesce(max_contract_years, 0),
		count_long_term = coalesce(count_long_term, 0L),
		weighted_avg_years = coalesce(weighted_avg_years, 0),
		total_ufa_decisions = coalesce(total_ufa_decisions, 0L),
		count_re_signed = coalesce(count_re_signed, 0L),
		count_new_signings = coalesce(count_new_signings, 0L),
		aav_retained = coalesce(aav_retained, 0),
		aav_new = coalesce(aav_new, 0),
		no_ufa_activity = coalesce(no_ufa_activity, total_ufa_decisions == 0L),
		pct_retained = if_else(no_ufa_activity, NA_real_, pct_retained),
		pct_aav_retained = if_else(no_ufa_activity, NA_real_, pct_aav_retained)
	) %>%
	filter(season_year >= 2018L, season_year <= 2025L) %>%
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
	"net_aav",
	"mean_contract_years",
	"count_long_term",
	"weighted_avg_years",
	"total_ufa_decisions",
	"count_re_signed",
	"count_new_signings",
	"aav_retained",
	"aav_new",
	"no_ufa_activity",
	"cap_spending_pct",
	"count_within_division",
	"count_cross_division",
	"count_cross_conference",
	"pct_cross_conference"
)

required_na_counts <- master_panel %>%
	summarise(across(all_of(key_analysis_columns), ~ sum(is.na(.x)))) %>%
	pivot_longer(cols = everything(), names_to = "column", values_to = "na_count")

pct_na_outside_no_activity <- master_panel %>%
	filter(!no_ufa_activity, is.na(pct_retained) | is.na(pct_aav_retained)) %>%
	nrow()

pct_non_na_with_no_activity <- master_panel %>%
	filter(no_ufa_activity, !is.na(pct_retained) | !is.na(pct_aav_retained)) %>%
	nrow()

write_csv(
	master_panel,
	here::here("data", "processed", "nhl_master_analysis_panel.csv")
)

cat("===== MASTER PANEL QA CHECKS =====\n")
cat("Row count:", nrow(master_panel), "(expected 252)\n")
cat("Column count:", ncol(master_panel), "\n")

if (all(required_na_counts$na_count == 0)) {
	cat("Key analysis columns NA check: PASS (zero NAs in all key analysis columns)\n")
} else {
	cat("Key analysis columns NA check: FAIL (non-zero NAs detected)\n")
	print(required_na_counts %>% filter(na_count > 0))
}

if (pct_na_outside_no_activity == 0 && pct_non_na_with_no_activity == 0) {
	cat("Retention percentage NA rule check: PASS (NA only when no_ufa_activity = TRUE)\n")
} else {
	cat("Retention percentage NA rule check: FAIL\n")
	cat("Rows with unexpected NA outside no_ufa_activity:", pct_na_outside_no_activity, "\n")
	cat("Rows with unexpected non-NA where no_ufa_activity = TRUE:", pct_non_na_with_no_activity, "\n")
}

cat(
	"Master panel build complete. Rows:", nrow(master_panel),
	"| Columns:", ncol(master_panel),
	"| Added V1.1 variables: net_aav, contract length metrics, retention metrics\n"
)