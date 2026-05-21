# 02_nhlscraper_pull.R
# Pull team-level season performance data via nhlscraper::standings for 2017-2025.

suppressPackageStartupMessages({
	library(nhlscraper)
	library(tidyverse)
	library(here)
})

season_end_dates <- tibble(
	season_year = 2017:2025,
	end_date = as.Date(c(
		"2017-04-09",
		"2018-04-08",
		"2019-04-06",
		"2020-03-11",
		"2021-05-19",
		"2022-05-01",
		"2023-04-14",
		"2024-04-18",
		"2025-04-15"
	))
)

expected_team_counts <- c(
	`2017` = 30,
	`2018` = 31,
	`2019` = 31,
	`2020` = 31,
	`2021` = 31,
	`2022` = 32,
	`2023` = 32,
	`2024` = 32,
	`2025` = 32
)

expected_total_rows <- sum(unname(expected_team_counts))

required_columns <- c(
	"seasonId",
	"teamTriCode",
	"teamCommonName",
	"conferenceAbbrev",
	"divisionAbbrev",
	"gamesPlayed",
	"wins",
	"losses",
	"otLosses",
	"points",
	"pointPctg",
	"goalFor",
	"goalAgainst",
	"goalDifferential"
)

master_df <- tibble()

for (i in seq_len(nrow(season_end_dates))) {
	season_year_i <- season_end_dates$season_year[[i]]
	end_date_i <- season_end_dates$end_date[[i]]

	message(sprintf("Pulling standings for season_year=%s at date=%s", season_year_i, end_date_i))

	season_df <- tryCatch(
		{
			standings(date = end_date_i)
		},
		error = function(e) {
			warning(sprintf(
				"Failed standings pull for season_year=%s. Error: %s",
				season_year_i,
				conditionMessage(e)
			))
			NULL
		}
	)

	if (is.null(season_df)) {
		next
	}

	season_df <- as_tibble(season_df)
	season_rows <- nrow(season_df)
	expected_rows <- unname(expected_team_counts[as.character(season_year_i)])

	if (!is.na(expected_rows) && season_rows != expected_rows) {
		warning(sprintf(
			"Row count warning for season_year=%s. Returned rows=%s (expected %s).",
			season_year_i,
			season_rows,
			expected_rows
		))
	}

	if (season_rows < 30) {
		warning(sprintf(
			"Treating season_year=%s as failed pull because rows=%s (<30). Excluding from master dataframe.",
			season_year_i,
			season_rows
		))
		next
	}

	missing_cols <- setdiff(required_columns, names(season_df))
	if (length(missing_cols) > 0) {
		warning(sprintf(
			"Missing required columns for season_year=%s: %s. Filling with NA.",
			season_year_i,
			paste(missing_cols, collapse = ", ")
		))
		for (col_name in missing_cols) {
			season_df[[col_name]] <- NA
		}
	}

	season_selected <- season_df |>
		select(all_of(required_columns)) |>
		mutate(season_year = as.integer(season_year_i))

	master_df <- bind_rows(master_df, season_selected)
}

if (nrow(master_df) != expected_total_rows) {
	warning(sprintf(
		"Master dataframe row count warning. Returned rows=%s (expected %s).",
		nrow(master_df),
		expected_total_rows
	))
}

master_df <- master_df |>
	mutate(
		pointPctg_numeric = suppressWarnings(as.numeric(pointPctg)),
		points_percentage = case_when(
			!is.na(pointPctg_numeric) & pointPctg_numeric <= 1 ~ pointPctg_numeric,
			!is.na(pointPctg_numeric) & pointPctg_numeric > 1 ~ pointPctg_numeric / 100,
			TRUE ~ as.numeric(points) / (as.numeric(gamesPlayed) * 2)
		)
	) |>
	select(-pointPctg_numeric) |>
	select(
		season_year,
		teamTriCode,
		teamCommonName,
		conferenceAbbrev,
		divisionAbbrev,
		gamesPlayed,
		wins,
		losses,
		otLosses,
		points,
		pointPctg,
		goalFor,
		goalAgainst,
		goalDifferential,
		points_percentage
	)

output_path <- here::here("data", "raw", "nhlscraper", "nhl_team_season_performance_raw.csv")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(master_df, output_path)

if (nrow(master_df) > 0) {
	message(sprintf(
		"Completed nhlscraper pull. Rows=%s (validated target=%s) | Seasons=%s | points_percentage_min=%.4f | points_percentage_max=%.4f",
		nrow(master_df),
		expected_total_rows,
		paste(sort(unique(master_df$season_year)), collapse = ","),
		min(master_df$points_percentage, na.rm = TRUE),
		max(master_df$points_percentage, na.rm = TRUE)
	))
} else {
	message("Completed nhlscraper pull with 0 rows. Check warnings for failed season pulls.")
}
