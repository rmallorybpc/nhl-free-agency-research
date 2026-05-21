# 02_build_cap_variables.R
# Build team-season cap spending variables from cleaned Spotrac and MIS outputs.

library(tidyverse)
library(here)

signed_free_agents <- read_csv(
	here::here("data", "processed", "nhl_signed_free_agents_clean.csv"),
	show_col_types = FALSE
)

mis_scores <- read_csv(
	here::here("data", "processed", "nhl_team_mis_scores.csv"),
	show_col_types = FALSE
)

# NHL salary cap ceilings in effect at the start of each regular season.
# The 2025 increase reflects the new CBA.
cap_lookup <- tibble(
	season_year = c(2017L, 2018L, 2019L, 2020L, 2021L, 2022L, 2023L, 2024L, 2025L),
	cap_ceiling = c(75000000, 79500000, 81500000, 81500000, 81500000, 82500000, 83500000, 88000000, 95500000)
)

# Match the same movement-event filter used in 01_build_MIS.R for consistency.
cap_input <- signed_free_agents %>%
	filter(!same_team_resign, is.na(data_quality_note))

cap_agg <- cap_input %>%
	group_by(signing_team, spotrac_year) %>%
	summarise(
		total_aav_committed = sum(aav, na.rm = TRUE),
		total_contract_value = sum(contract_value, na.rm = TRUE),
		signing_count_cap = n(),
		.groups = "drop"
	) %>%
	rename(season_year = spotrac_year) %>%
	mutate(season_year = as.integer(season_year))

cap_change_lookup <- cap_lookup %>%
	transmute(
		season_year,
		prior_season_year = season_year - 1L
	) %>%
	left_join(
		cap_lookup %>%
			transmute(prior_season_year = season_year, prior_cap_ceiling = cap_ceiling),
		by = "prior_season_year"
	) %>%
	left_join(cap_lookup, by = "season_year") %>%
	mutate(cap_ceiling_change = cap_ceiling - prior_cap_ceiling) %>%
	select(season_year, cap_ceiling, cap_ceiling_change)

cap_output <- mis_scores %>%
	mutate(season_year = as.integer(season_year)) %>%
	left_join(cap_agg, by = c("signing_team", "season_year")) %>%
	# Team-seasons with zero offseason signings are present from MIS and should carry zeros.
	mutate(
		total_aav_committed = coalesce(total_aav_committed, 0),
		total_contract_value = coalesce(total_contract_value, 0),
		signing_count_cap = coalesce(signing_count_cap, 0L)
	) %>%
	left_join(cap_change_lookup, by = "season_year") %>%
	# Use MIS total_aav_spent for cap_spending_pct to keep spending definitions consistent.
	mutate(
		cap_spending_pct = total_aav_spent / cap_ceiling,
		near_cap_floor = total_aav_spent < (0.05 * cap_ceiling),
		# Version 1 threshold prior assumption; review against empirical distribution.
		heavy_spender = cap_spending_pct > 0.15
	) %>%
	arrange(season_year, signing_team)

# Inline QA checks
total_rows <- nrow(cap_output)

cap_spending_stats <- cap_output %>%
	summarise(
		min_cap_spending_pct = min(cap_spending_pct, na.rm = TRUE),
		max_cap_spending_pct = max(cap_spending_pct, na.rm = TRUE),
		mean_cap_spending_pct = mean(cap_spending_pct, na.rm = TRUE)
	)

near_cap_floor_count <- sum(cap_output$near_cap_floor, na.rm = TRUE)
heavy_spender_count <- sum(cap_output$heavy_spender, na.rm = TRUE)

cap_change_by_season <- cap_output %>%
	distinct(season_year, cap_ceiling_change) %>%
	arrange(season_year)

cap_change_na_count <- sum(is.na(cap_output$cap_ceiling_change))
expected_cap_change_na_count <- sum(cap_output$season_year == 2017)
cap_change_2025 <- cap_change_by_season %>%
	filter(season_year == 2025) %>%
	pull(cap_ceiling_change)
cap_change_2025_label <- ifelse(
	length(cap_change_2025) == 1 && !is.na(cap_change_2025),
	paste0("$", format(cap_change_2025, big.mark = ",", scientific = FALSE)),
	"NA"
)

cat("===== CAP VARIABLES QA CHECKS =====\n")
cat("Total rows in output:", total_rows, "(expected 282)\n")
cat(
	"cap_spending_pct min/max/mean:",
	round(cap_spending_stats$min_cap_spending_pct, 4),
	"/",
	round(cap_spending_stats$max_cap_spending_pct, 4),
	"/",
	round(cap_spending_stats$mean_cap_spending_pct, 4),
	"\n"
)
cat("Count of near_cap_floor TRUE:", near_cap_floor_count, "\n")
cat("Count of heavy_spender TRUE:", heavy_spender_count, "\n")
cat(
	"cap_ceiling_change values by season_year (2025 jump computed as",
	cap_change_2025_label,
	"):\n"
)
print(cap_change_by_season)
cat(
	"Count of NA values in cap_ceiling_change:",
	cap_change_na_count,
	"(expected",
	expected_cap_change_na_count,
	"for 2017 rows)\n"
)

write_csv(
	cap_output,
	here::here("data", "processed", "nhl_team_cap_variables.csv")
)

cat(
	"Cap variable build complete. Rows written:",
	total_rows,
	"| heavy_spender TRUE:",
	heavy_spender_count,
	"| near_cap_floor TRUE:",
	near_cap_floor_count,
	"\n"
)
