# 07_build_retention.R
# Build team-season UFA retention features from cleaned UFA signings.

library(tidyverse)
library(here)

signed_free_agents <- read_csv(
	here::here("data", "processed", "nhl_signed_free_agents_clean.csv"),
	show_col_types = FALSE
)

retention_input <- signed_free_agents %>%
	filter(is.na(data_quality_note)) %>%
	mutate(
		signing_team = recode(signing_team, "WAS" = "WSH", .default = signing_team),
		spotrac_year = as.integer(spotrac_year),
		aav = as.numeric(aav)
	)

retention_by_team <- retention_input %>%
	group_by(signing_team, spotrac_year) %>%
	summarise(
		total_ufa_decisions = n(),
		count_re_signed = sum(same_team_resign, na.rm = TRUE),
		count_new_signings = sum(!same_team_resign, na.rm = TRUE),
		pct_retained = if_else(total_ufa_decisions > 0, count_re_signed / total_ufa_decisions, NA_real_),
		aav_retained = sum(if_else(same_team_resign, aav, 0), na.rm = TRUE),
		aav_new = sum(if_else(!same_team_resign, aav, 0), na.rm = TRUE),
		pct_aav_retained = if_else((aav_retained + aav_new) > 0, aav_retained / (aav_retained + aav_new), NA_real_),
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

retention_output <- team_season_panel %>%
	left_join(
		retention_by_team %>% rename(season_year = spotrac_year),
		by = c("signing_team", "season_year")
	) %>%
	mutate(
		total_ufa_decisions = coalesce(total_ufa_decisions, 0L),
		count_re_signed = coalesce(count_re_signed, 0L),
		count_new_signings = coalesce(count_new_signings, 0L),
		aav_retained = coalesce(aav_retained, 0),
		aav_new = coalesce(aav_new, 0),
		no_ufa_activity = total_ufa_decisions == 0L,
		pct_retained = if_else(no_ufa_activity, NA_real_, pct_retained),
		pct_aav_retained = if_else(no_ufa_activity, NA_real_, pct_aav_retained)
	) %>%
	arrange(season_year, signing_team)

pct_stats <- retention_output %>%
	filter(!no_ufa_activity) %>%
	summarise(
		min_pct_retained = min(pct_retained, na.rm = TRUE),
		max_pct_retained = max(pct_retained, na.rm = TRUE),
		mean_pct_retained = mean(pct_retained, na.rm = TRUE),
		median_pct_retained = median(pct_retained, na.rm = TRUE)
	)

no_activity_count <- sum(retention_output$no_ufa_activity, na.rm = TRUE)
max_pct_retained <- max(retention_output$pct_retained, na.rm = TRUE)

write_csv(
	retention_output,
	here::here("data", "processed", "nhl_team_retention.csv")
)

cat("===== RETENTION QA CHECKS =====\n")
cat("Row count:", nrow(retention_output), "(expected 282)\n")
cat(
	"pct_retained min/max/mean/median (active teams only):",
	round(pct_stats$min_pct_retained, 3),
	"/",
	round(pct_stats$max_pct_retained, 3),
	"/",
	round(pct_stats$mean_pct_retained, 3),
	"/",
	round(pct_stats$median_pct_retained, 3),
	"\n"
)
cat("Team-seasons with no UFA activity:", no_activity_count, "\n")
cat("Maximum pct_retained:", round(max_pct_retained, 3), "(sanity: <= 1.0)\n")
cat("Retention build complete. Rows written:", nrow(retention_output), "\n")
