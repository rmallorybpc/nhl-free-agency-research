# 06_build_contract_length.R
# Build team-season contract-length features from cleaned UFA signings.

library(tidyverse)
library(here)

signed_free_agents <- read_csv(
	here::here("data", "processed", "nhl_signed_free_agents_clean.csv"),
	show_col_types = FALSE
)

contract_input <- signed_free_agents %>%
	filter(!same_team_resign, is.na(data_quality_note)) %>%
	mutate(
		signing_team = recode(signing_team, "WAS" = "WSH", .default = signing_team),
		spotrac_year = as.integer(spotrac_year),
		contract_years = as.numeric(contract_years),
		aav = as.numeric(aav)
	)

contract_by_team <- contract_input %>%
	group_by(signing_team, spotrac_year) %>%
	summarise(
		mean_contract_years = mean(contract_years, na.rm = TRUE),
		max_contract_years = max(contract_years, na.rm = TRUE),
		count_long_term = sum(contract_years >= 5, na.rm = TRUE),
		weighted_avg_years = if_else(
			sum(aav, na.rm = TRUE) > 0,
			sum(contract_years * aav, na.rm = TRUE) / sum(aav, na.rm = TRUE),
			0
		),
		.groups = "drop"
	)

team_season_panel <- read_csv(
	here::here("data", "processed", "nhl_team_season_performance_clean.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		signing_team = recode(teamTriCode, "WAS" = "WSH", .default = teamTriCode),
		season_year = as.integer(season_year)
	) %>%
	filter(season_year >= 2017L, season_year <= 2025L) %>%
	distinct()

contract_output <- team_season_panel %>%
	left_join(
		contract_by_team %>% rename(season_year = spotrac_year),
		by = c("signing_team", "season_year")
	) %>%
	mutate(
		mean_contract_years = coalesce(mean_contract_years, 0),
		max_contract_years = coalesce(max_contract_years, 0),
		count_long_term = coalesce(count_long_term, 0L),
		weighted_avg_years = coalesce(weighted_avg_years, 0)
	) %>%
	arrange(season_year, signing_team)

mean_stats <- contract_output %>%
	summarise(
		min_mean_contract_years = min(mean_contract_years, na.rm = TRUE),
		max_mean_contract_years = max(mean_contract_years, na.rm = TRUE),
		mean_mean_contract_years = mean(mean_contract_years, na.rm = TRUE),
		median_mean_contract_years = median(mean_contract_years, na.rm = TRUE)
	)

team_seasons_with_long_term <- sum(contract_output$count_long_term > 0, na.rm = TRUE)
max_contract_term <- max(contract_output$max_contract_years, na.rm = TRUE)

write_csv(
	contract_output,
	here::here("data", "processed", "nhl_team_contract_length.csv")
)

cat("===== CONTRACT LENGTH QA CHECKS =====\n")
cat("Row count:", nrow(contract_output), "(expected 282)\n")
cat(
	"mean_contract_years min/max/mean/median:",
	round(mean_stats$min_mean_contract_years, 3),
	"/",
	round(mean_stats$max_mean_contract_years, 3),
	"/",
	round(mean_stats$mean_mean_contract_years, 3),
	"/",
	round(mean_stats$median_mean_contract_years, 3),
	"\n"
)
cat("Team-seasons with >=1 long-term signing (5+ years):", team_seasons_with_long_term, "\n")
cat("Maximum max_contract_years:", round(max_contract_term, 3), "(sanity: should be < 9)\n")
cat("Contract length build complete. Rows written:", nrow(contract_output), "\n")
