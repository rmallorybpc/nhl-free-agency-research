# 05_build_net_aav.R
# Build team-season net AAV (acquired minus departed) from cleaned UFA signings.

library(tidyverse)
library(here)

signed_free_agents <- read_csv(
	here::here("data", "processed", "nhl_signed_free_agents_clean.csv"),
	show_col_types = FALSE
)

# V1.1 scope note:
# - Retirements are not captured (no destination signing row exists).
# - Players still unsigned at summer close are not captured.
# - Trade losses are not captured.
# These are accepted methodological limits for the UFA-only offseason design.
movement_input <- signed_free_agents %>%
	filter(!same_team_resign, is.na(data_quality_note)) %>%
	mutate(
		signing_team = recode(signing_team, "WAS" = "WSH", .default = signing_team),
		previous_team = recode(previous_team, "WAS" = "WSH", .default = previous_team),
		spotrac_year = as.integer(spotrac_year)
	)

acquired_by_team <- movement_input %>%
	group_by(signing_team, spotrac_year) %>%
	summarise(total_aav_committed = sum(aav, na.rm = TRUE), .groups = "drop")

departed_by_team <- movement_input %>%
	filter(!is.na(previous_team), previous_team != "", previous_team != "UNKNOWN") %>%
	group_by(previous_team, spotrac_year) %>%
	summarise(total_aav_lost = sum(aav, na.rm = TRUE), .groups = "drop") %>%
	rename(signing_team = previous_team)

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

net_aav_output <- team_season_panel %>%
	left_join(
		acquired_by_team %>% rename(season_year = spotrac_year),
		by = c("signing_team", "season_year")
	) %>%
	left_join(
		departed_by_team %>% rename(season_year = spotrac_year),
		by = c("signing_team", "season_year")
	) %>%
	mutate(
		total_aav_committed = coalesce(total_aav_committed, 0),
		total_aav_lost = coalesce(total_aav_lost, 0),
		net_aav = total_aav_committed - total_aav_lost
	) %>%
	arrange(season_year, signing_team)

net_stats <- net_aav_output %>%
	summarise(
		min_net_aav = min(net_aav, na.rm = TRUE),
		max_net_aav = max(net_aav, na.rm = TRUE),
		mean_net_aav = mean(net_aav, na.rm = TRUE),
		median_net_aav = median(net_aav, na.rm = TRUE)
	)

negative_count <- sum(net_aav_output$net_aav < 0, na.rm = TRUE)
positive_count <- sum(net_aav_output$net_aav > 0, na.rm = TRUE)

write_csv(
	net_aav_output,
	here::here("data", "processed", "nhl_team_net_aav.csv")
)

cat("===== NET AAV QA CHECKS =====\n")
cat("Row count:", nrow(net_aav_output), "(expected 282)\n")
cat(
	"net_aav min/max/mean/median:",
	round(net_stats$min_net_aav, 2),
	"/",
	round(net_stats$max_net_aav, 2),
	"/",
	round(net_stats$mean_net_aav, 2),
	"/",
	round(net_stats$median_net_aav, 2),
	"\n"
)
cat("Team-seasons with net_aav < 0:", negative_count, "\n")
cat("Team-seasons with net_aav > 0:", positive_count, "\n")
cat("Net AAV build complete. Rows written:", nrow(net_aav_output), "\n")
