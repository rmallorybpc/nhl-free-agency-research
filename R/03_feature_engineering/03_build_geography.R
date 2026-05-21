# 03_build_geography.R
# Assign geographic movement variables to each UFA signing and aggregate
# movement geography to the team-season level.

library(tidyverse)
library(here)

signed_free_agents <- read_csv(
	here::here("data", "processed", "nhl_signed_free_agents_clean.csv"),
	show_col_types = FALSE
)

team_performance <- read_csv(
	here::here("data", "processed", "nhl_team_season_performance_clean.csv"),
	show_col_types = FALSE
)

# Division structure changed in 2021 due to COVID realignment.
# UTA replaced ARI starting in 2025.
# Standard conference mapping:
# - Metropolitan (M), Atlantic (A) -> E
# - Central (C), Pacific (P) -> W
# 2021 proxy conference mapping:
# - EST, CEN -> E
# - NTH, WST -> W
build_previous_team_lookup <- function() {
	build_standard_rows <- function(season_year) {
		metropolitan <- c("CAR", "CBJ", "NJD", "NYI", "NYR", "PHI", "PIT", "WSH")
		atlantic <- c("BOS", "BUF", "DET", "FLA", "MTL", "OTT", "TBL", "TOR")
		central <- c("CHI", "COL", "DAL", "MIN", "NSH", "STL", "WPG")
		pacific <- c("ANA", "CGY", "EDM", "LAK", "SJS", "VAN", "VGK")

		if (season_year <= 2024L) {
			central <- c(central, "ARI")
		}
		if (season_year >= 2022L) {
			pacific <- c(pacific, "SEA")
		}
		# Spotrac offseason coding can surface SEA in 2021 rows (2021-22 cycle).
		if (season_year == 2021L) {
			pacific <- c(pacific, "SEA")
		}
		if (season_year >= 2025L) {
			central <- c(central, "UTA")
		}
		# Spotrac offseason coding can surface UTA in 2024 rows (2024-25 cycle).
		if (season_year == 2024L) {
			central <- c(central, "UTA")
		}

		bind_rows(
			tibble(previous_team = metropolitan, season_year = season_year, previous_team_division = "M", previous_team_conference = "E"),
			tibble(previous_team = atlantic, season_year = season_year, previous_team_division = "A", previous_team_conference = "E"),
			tibble(previous_team = central, season_year = season_year, previous_team_division = "C", previous_team_conference = "W"),
			tibble(previous_team = pacific, season_year = season_year, previous_team_division = "P", previous_team_conference = "W")
		)
	}

	standard_years <- c(2017L, 2018L, 2019L, 2020L, 2022L, 2023L, 2024L, 2025L, 2026L)
	standard_lookup <- map_dfr(standard_years, build_standard_rows)

	covid_2021_lookup <- bind_rows(
		tibble(
			previous_team = c("CGY", "EDM", "MTL", "OTT", "TOR", "VAN", "WPG"),
			season_year = 2021L,
			previous_team_division = "NTH",
			previous_team_conference = "W"
		),
		tibble(
			previous_team = c("BOS", "BUF", "NJD", "NYI", "NYR", "PHI", "PIT", "WSH"),
			season_year = 2021L,
			previous_team_division = "EST",
			previous_team_conference = "E"
		),
		tibble(
			previous_team = c("CAR", "CBJ", "CHI", "COL", "DAL", "DET", "FLA", "MIN", "NSH", "STL", "TBL"),
			season_year = 2021L,
			previous_team_division = "CEN",
			previous_team_conference = "E"
		),
		tibble(
			previous_team = c("ANA", "ARI", "LAK", "SJS", "VGK"),
			season_year = 2021L,
			previous_team_division = "WST",
			previous_team_conference = "W"
		),
		tibble(
			previous_team = "SEA",
			season_year = 2021L,
			previous_team_division = "WST",
			previous_team_conference = "W"
		)
	)

	bind_rows(standard_lookup, covid_2021_lookup)
}

signing_team_lookup <- team_performance %>%
	transmute(
		signing_team = teamTriCode,
		season_year = as.integer(season_year),
		signing_team_division = divisionAbbrev,
		signing_team_conference = conferenceAbbrev
	) %>%
	distinct()

previous_team_lookup <- build_previous_team_lookup() %>%
	distinct(previous_team, season_year, .keep_all = TRUE)

signing_team_fallback_lookup <- previous_team_lookup %>%
	transmute(
		signing_team = previous_team,
		season_year,
		signing_team_division_fallback = previous_team_division,
		signing_team_conference_fallback = previous_team_conference
	)

signed_with_geography <- signed_free_agents %>%
	mutate(
		spotrac_year = as.integer(spotrac_year),
		signing_team_lookup_code = recode(signing_team, "WAS" = "WSH", .default = signing_team),
		previous_team_lookup_code = recode(previous_team, "WAS" = "WSH", .default = previous_team),
		unknown_previous_team = is.na(previous_team_lookup_code) | previous_team_lookup_code == "" | previous_team_lookup_code == "UNKNOWN"
	) %>%
	left_join(
		signing_team_lookup,
		by = c("signing_team_lookup_code" = "signing_team", "spotrac_year" = "season_year")
	) %>%
	left_join(
		signing_team_fallback_lookup,
		by = c("signing_team_lookup_code" = "signing_team", "spotrac_year" = "season_year")
	) %>%
	left_join(
		previous_team_lookup,
		by = c("previous_team_lookup_code" = "previous_team", "spotrac_year" = "season_year")
	) %>%
	mutate(
		signing_team_division = coalesce(signing_team_division, signing_team_division_fallback),
		signing_team_conference = coalesce(signing_team_conference, signing_team_conference_fallback),
		previous_team_division = if_else(unknown_previous_team, NA_character_, previous_team_division),
		previous_team_conference = if_else(unknown_previous_team, NA_character_, previous_team_conference),
		division_change = case_when(
			is.na(signing_team_division) | is.na(previous_team_division) ~ NA,
			TRUE ~ signing_team_division != previous_team_division
		),
		conference_change = case_when(
			is.na(signing_team_conference) | is.na(previous_team_conference) ~ NA,
			TRUE ~ signing_team_conference != previous_team_conference
		),
		movement_geography = case_when(
			same_team_resign ~ "same_team",
			is.na(division_change) | is.na(conference_change) ~ NA_character_,
			!division_change ~ "within_division",
			division_change & !conference_change ~ "cross_division_same_conference",
			conference_change ~ "cross_conference",
			TRUE ~ NA_character_
		)
	)

# Cross-conference moves are expected to show the strongest reset effect
# under the Dai moderation hypothesis.

updated_signed_free_agents <- signed_with_geography %>%
	select(
		-unknown_previous_team,
		-signing_team_lookup_code,
		-previous_team_lookup_code,
		-signing_team_division,
		-signing_team_conference,
		-signing_team_division_fallback,
		-signing_team_conference_fallback,
		-previous_team_division,
		-previous_team_conference
	)

# Preserve all original columns and only populate/add requested geography fields.
if (!("movement_geography" %in% names(signed_free_agents))) {
	updated_signed_free_agents <- updated_signed_free_agents %>%
		select(all_of(names(signed_free_agents)), movement_geography)
}

team_season_panel <- team_performance %>%
	transmute(
		signing_team = teamTriCode,
		season_year = as.integer(season_year)
	) %>%
	distinct()

geography_agg <- signed_with_geography %>%
	group_by(signing_team, spotrac_year) %>%
	summarise(
		count_within_division = sum(movement_geography == "within_division", na.rm = TRUE),
		count_cross_division = sum(movement_geography == "cross_division_same_conference", na.rm = TRUE),
		count_cross_conference = sum(movement_geography == "cross_conference", na.rm = TRUE),
		total_signing_count = n(),
		pct_cross_conference = if_else(total_signing_count > 0, count_cross_conference / total_signing_count, 0),
		any_cross_conference = count_cross_conference > 0,
		.groups = "drop"
	) %>%
	rename(season_year = spotrac_year)

team_geography_output <- team_season_panel %>%
	left_join(
		geography_agg,
		by = c("signing_team", "season_year")
	) %>%
	mutate(
		count_within_division = coalesce(count_within_division, 0L),
		count_cross_division = coalesce(count_cross_division, 0L),
		count_cross_conference = coalesce(count_cross_conference, 0L),
		total_signing_count = coalesce(total_signing_count, 0L),
		pct_cross_conference = coalesce(pct_cross_conference, 0),
		any_cross_conference = coalesce(any_cross_conference, FALSE)
	) %>%
	arrange(season_year, signing_team)

# Inline QA checks
output_rows <- nrow(team_geography_output)

movement_distribution_signings <- signed_with_geography %>%
	count(movement_geography, sort = TRUE)

unknown_previous_count <- signed_with_geography %>%
	filter(previous_team == "UNKNOWN", is.na(movement_geography)) %>%
	nrow()

cross_conference_by_season <- signed_with_geography %>%
	filter(movement_geography == "cross_conference") %>%
	count(spotrac_year, name = "cross_conference_signings") %>%
	arrange(spotrac_year)

unexpected_division_na <- signed_with_geography %>%
	filter(is.na(division_change), previous_team != "UNKNOWN") %>%
	nrow()

unexpected_conference_na <- signed_with_geography %>%
	filter(is.na(conference_change), previous_team != "UNKNOWN") %>%
	nrow()

team_season_movement_totals <- team_geography_output %>%
	summarise(
		total_within_division = sum(count_within_division),
		total_cross_division = sum(count_cross_division),
		total_cross_conference = sum(count_cross_conference),
		team_seasons_with_cross_conference = sum(any_cross_conference)
	)

cat("===== GEOGRAPHY QA CHECKS =====\n")
cat("Total rows in output:", output_rows, "(expected 282)\n")
cat("Movement geography distribution across all signing rows:\n")
print(movement_distribution_signings)
cat(
	"Count of signings where previous_team is UNKNOWN and geography could not be assigned:",
	unknown_previous_count,
	"\n"
)
cat("Count of cross_conference signings by season_year:\n")
print(cross_conference_by_season)
cat(
	"Unexpected NA values in division_change outside UNKNOWN previous_team rows:",
	unexpected_division_na,
	"\n"
)
cat(
	"Unexpected NA values in conference_change outside UNKNOWN previous_team rows:",
	unexpected_conference_na,
	"\n"
)

write_csv(
	updated_signed_free_agents,
	here::here("data", "processed", "nhl_signed_free_agents_clean.csv")
)

write_csv(
	team_geography_output,
	here::here("data", "processed", "nhl_team_geography_variables.csv")
)

cat(
	"Geography build complete. Rows written:",
	output_rows,
	"| Team-season movement distribution totals (within/cross-division/cross-conference):",
	team_season_movement_totals$total_within_division,
	"/",
	team_season_movement_totals$total_cross_division,
	"/",
	team_season_movement_totals$total_cross_conference,
	"| team-seasons with any cross-conference:",
	team_season_movement_totals$team_seasons_with_cross_conference,
	"\n"
)
