# 02_clean_performance.R
# Clean and standardize nhlscraper team performance pulls into a team-season
# panel dataset for feature engineering.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
})

expected_total_rows <- 314L
expected_season_counts <- c(
	`2017` = 30L,
	`2018` = 31L,
	`2019` = 31L,
	`2020` = 31L,
	`2021` = 31L,
	`2022` = 32L,
	`2023` = 32L,
	`2024` = 32L,
	`2025` = 32L,
	`2026` = 32L
)
expected_divisions <- c("M", "A", "C", "P", "NTH", "EST", "WST", "CEN")

input_path <- here::here("data", "raw", "nhlscraper", "nhl_team_season_performance_raw.csv")
output_path <- here::here("data", "processed", "nhl_team_season_performance_clean.csv")

raw_df <- readr::read_csv(input_path, show_col_types = FALSE)
input_rows <- nrow(raw_df)

validation_warnings <- character()

add_warning <- function(msg) {
	validation_warnings <<- c(validation_warnings, msg)
	cat(sprintf("WARNING: %s\n", msg))
}

check_integer_column <- function(df, col_name) {
	vals <- df[[col_name]]
	non_whole <- sum(!is.na(vals) & vals != floor(vals))
	if (non_whole > 0) {
		add_warning(sprintf("%s has %s non-integer values.", col_name, non_whole))
	}
}

# Drop pointPctg because it is identical to points_percentage, which is the
# standardized field retained for analysis.
clean_df <- raw_df |>
	select(-pointPctg) |>
	mutate(
		season_year = as.integer(season_year),
		teamTriCode = teamTriCode |>
			stringr::str_squish() |>
			stringr::str_to_upper(),
		teamCommonName = teamCommonName |>
			stringr::str_squish() |>
			stringr::str_to_title(),
		conferenceAbbrev = conferenceAbbrev |>
			stringr::str_squish() |>
			stringr::str_to_upper(),
		divisionAbbrev = divisionAbbrev |>
			stringr::str_squish() |>
			stringr::str_to_upper(),
		gamesPlayed = as.integer(gamesPlayed),
		wins = as.integer(wins),
		losses = as.integer(losses),
		otLosses = as.integer(otLosses),
		points = as.integer(points),
		goalFor = as.integer(goalFor),
		goalAgainst = as.integer(goalAgainst),
		goalDifferential = as.integer(goalDifferential),
		points_percentage = as.numeric(points_percentage)
	) |>
	mutate(
		# These flags support sensitivity checks that exclude COVID-affected seasons.
		season_type = dplyr::case_when(
			season_year == 2020L ~ "covid_shortened",
			season_year == 2021L ~ "covid_bubble",
			TRUE ~ "standard"
		),
		prior_season_year = season_year - 1L
	)

check_integer_column(raw_df, "season_year")
check_integer_column(raw_df, "gamesPlayed")
check_integer_column(raw_df, "wins")
check_integer_column(raw_df, "losses")
check_integer_column(raw_df, "otLosses")
check_integer_column(raw_df, "points")
check_integer_column(raw_df, "goalFor")
check_integer_column(raw_df, "goalAgainst")
check_integer_column(raw_df, "goalDifferential")

unexpected_conference <- clean_df |>
	filter(!conferenceAbbrev %in% c("E", "W")) |>
	count(conferenceAbbrev, sort = TRUE, name = "rows")

if (nrow(unexpected_conference) > 0) {
	add_warning("conferenceAbbrev contains values outside E/W.")
	print(unexpected_conference)
}

# NTH/EST/WST/CEN appear only in 2021 due to the COVID-era temporary division
# structure used by the league.
unexpected_division <- clean_df |>
	filter(!divisionAbbrev %in% expected_divisions) |>
	count(divisionAbbrev, sort = TRUE, name = "rows")

if (nrow(unexpected_division) > 0) {
	add_warning("divisionAbbrev contains unexpected values.")
	print(unexpected_division)
}

games_out_of_range <- clean_df |>
	filter(gamesPlayed < 48L | gamesPlayed > 82L)
if (nrow(games_out_of_range) > 0) {
	add_warning(sprintf("gamesPlayed has %s rows outside [48, 82].", nrow(games_out_of_range)))
}

negative_wins_losses_ot <- clean_df |>
	filter(wins < 0L | losses < 0L | otLosses < 0L)
if (nrow(negative_wins_losses_ot) > 0) {
	add_warning(sprintf("wins/losses/otLosses has %s rows with negative values.", nrow(negative_wins_losses_ot)))
}

points_mismatch <- clean_df |>
	filter(points != (wins * 2L + otLosses))
if (nrow(points_mismatch) > 0) {
	add_warning(sprintf("Points formula mismatch detected in %s rows.", nrow(points_mismatch)))
}

goals_out_of_range <- clean_df |>
	filter(goalFor < 100L | goalFor > 350L | goalAgainst < 100L | goalAgainst > 350L)
if (nrow(goals_out_of_range) > 0) {
	add_warning(sprintf("goalFor/goalAgainst has %s rows outside [100, 350].", nrow(goals_out_of_range)))
}

goal_diff_mismatch <- clean_df |>
	filter(goalDifferential != (goalFor - goalAgainst))
if (nrow(goal_diff_mismatch) > 0) {
	add_warning(sprintf("Goal differential mismatch detected in %s rows.", nrow(goal_diff_mismatch)))
}

points_percentage_out_of_range <- clean_df |>
	filter(points_percentage < 0 | points_percentage > 1)
if (nrow(points_percentage_out_of_range) > 0) {
	add_warning(sprintf("points_percentage has %s rows outside [0, 1].", nrow(points_percentage_out_of_range)))
}

season_counts <- clean_df |>
	count(season_year, name = "rows") |>
	arrange(season_year)

expected_season_df <- tibble(
	season_year = as.integer(names(expected_season_counts)),
	expected_rows = as.integer(unname(expected_season_counts))
)

season_count_check <- expected_season_df |>
	left_join(season_counts, by = "season_year") |>
	mutate(rows = replace_na(rows, 0L), matches_expected = rows == expected_rows)

if (!all(season_count_check$matches_expected)) {
	add_warning("Season row counts do not match expected historical totals.")
}

na_count_total <- clean_df |>
	summarise(across(everything(), ~ sum(is.na(.x)))) |>
	unlist(use.names = FALSE) |>
	sum()

conference_distribution <- clean_df |>
	count(season_year, conferenceAbbrev, name = "rows") |>
	arrange(season_year, conferenceAbbrev)

points_formula_invalid_n <- nrow(points_mismatch)
goal_diff_invalid_n <- nrow(goal_diff_mismatch)
points_percentage_min <- min(clean_df$points_percentage, na.rm = TRUE)
points_percentage_max <- max(clean_df$points_percentage, na.rm = TRUE)

season_type_distribution <- clean_df |>
	count(season_type, name = "rows") |>
	arrange(season_type)

cat("\n=== Team Performance Clean QA ===\n")
cat(sprintf("Total rows: %s (expected: %s)\n", nrow(clean_df), expected_total_rows))

cat("\nRow count by season_year (with expected):\n")
print(season_count_check)

cat(sprintf("\nTotal NA values across all columns: %s\n", na_count_total))

cat("\nConference distribution by season_year:\n")
print(conference_distribution)

# In extraction, 2021 conferenceAbbrev values were proxy-mapped from temporary
# COVID-era division codes to E/W.
conference_2021_non_ew <- clean_df |>
	filter(season_year == 2021L, !conferenceAbbrev %in% c("E", "W")) |>
	nrow()

if (conference_2021_non_ew > 0) {
	add_warning(sprintf("2021 conferenceAbbrev includes %s non E/W values despite proxy mapping.", conference_2021_non_ew))
}

cat(sprintf(
	"\nPoints formula validation (points != wins*2 + otLosses): %s\n",
	points_formula_invalid_n
))
cat(sprintf(
	"Goal differential validation (goalDifferential != goalFor - goalAgainst): %s\n",
	goal_diff_invalid_n
))
cat(sprintf(
	"points_percentage range: min=%.6f max=%.6f\n",
	points_percentage_min,
	points_percentage_max
))

cat("\nSeason type distribution:\n")
print(season_type_distribution)

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(clean_df, output_path)

cat("\n=== Cleaning Complete ===\n")
cat(sprintf("Input rows (expected: %s): %s\n", expected_total_rows, input_rows))
cat(sprintf("Output rows written (expected: %s): %s\n", expected_total_rows, nrow(clean_df)))
cat("Season type distribution:\n")
print(season_type_distribution)

if (length(validation_warnings) == 0) {
	cat("Any validation warnings encountered: none\n")
} else {
	cat("Any validation warnings encountered:\n")
	for (warn_msg in unique(validation_warnings)) {
		cat(sprintf("- %s\n", warn_msg))
	}
}

# Version 1 analysis-window note:
# Effective season-over-season outcome window is 2018 to 2026 because 2016
# baseline performance is out of scope. This yields 9 outcome seasons total.
# As a result, 2017 Spotrac signings are excluded from regression models that
# require a prior-season baseline.
