# 00_spotrac_raw_qa.R
# Quick QA checks for Spotrac NHL signed free agent raw extract.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
})

input_path <- here::here("data", "raw", "spotrac", "nhl_signed_free_agents_raw.csv")
output_dir <- here::here("output", "tables")

if (!file.exists(input_path)) {
	stop(sprintf("Input file not found: %s", input_path))
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

spotrac_raw <- readr::read_csv(input_path, show_col_types = FALSE)

required_cols <- c(
	"player_name",
	"position",
	"signing_team",
	"previous_team",
	"contract_value",
	"aav",
	"contract_years",
	"ufa_rfa_type",
	"spotrac_year",
	"position_filter"
)

missing_required <- setdiff(required_cols, names(spotrac_raw))
if (length(missing_required) > 0) {
	stop(
		sprintf(
			"Missing required columns: %s",
			paste(missing_required, collapse = ", ")
		)
	)
}

key_fields <- c(
	"player_name",
	"position",
	"signing_team",
	"contract_value",
	"contract_years",
	"spotrac_year",
	"position_filter"
)

missing_field_counts <- tibble(field = key_fields) |>
	mutate(
		missing_rows = map_int(field, function(fld) {
			sum(is.na(spotrac_raw[[fld]]) | stringr::str_squish(as.character(spotrac_raw[[fld]])) == "")
		}),
		missing_pct = round((missing_rows / nrow(spotrac_raw)) * 100, 2)
	)

all_row_duplicates <- spotrac_raw |>
	group_by(across(everything())) |>
	mutate(duplicate_count = n()) |>
	ungroup() |>
	filter(duplicate_count > 1)

key_duplicates <- spotrac_raw |>
	mutate(across(all_of(key_fields), ~ stringr::str_squish(as.character(.x)))) |>
	group_by(across(all_of(key_fields))) |>
	summarise(duplicate_count = n(), .groups = "drop") |>
	filter(duplicate_count > 1) |>
	arrange(desc(duplicate_count), spotrac_year, position_filter, player_name)

year_totals <- spotrac_raw |>
	count(spotrac_year, name = "rows") |>
	arrange(spotrac_year)

year_position_totals <- spotrac_raw |>
	count(spotrac_year, position_filter, name = "rows") |>
	arrange(spotrac_year, position_filter)

readr::write_csv(missing_field_counts, file.path(output_dir, "spotrac_raw_qa_missing_field_counts.csv"))
readr::write_csv(year_totals, file.path(output_dir, "spotrac_raw_qa_year_totals.csv"))
readr::write_csv(year_position_totals, file.path(output_dir, "spotrac_raw_qa_year_position_totals.csv"))
readr::write_csv(key_duplicates, file.path(output_dir, "spotrac_raw_qa_key_duplicates.csv"))
readr::write_csv(all_row_duplicates, file.path(output_dir, "spotrac_raw_qa_exact_duplicates.csv"))

message("Spotrac raw QA complete.")
message(sprintf("Rows evaluated: %s", nrow(spotrac_raw)))
message(sprintf("Missing key-field checks written: %s", file.path(output_dir, "spotrac_raw_qa_missing_field_counts.csv")))
message(sprintf("Year totals written: %s", file.path(output_dir, "spotrac_raw_qa_year_totals.csv")))
message(sprintf("Year-position totals written: %s", file.path(output_dir, "spotrac_raw_qa_year_position_totals.csv")))
message(sprintf("Key duplicates found: %s", nrow(key_duplicates)))
message(sprintf("Exact full-row duplicates found: %s", nrow(all_row_duplicates)))

if (any(missing_field_counts$missing_rows > 0)) {
	warning("One or more key fields have missing values. Review missing-field QA output.")
}

if (nrow(key_duplicates) > 0 || nrow(all_row_duplicates) > 0) {
	warning("Duplicate rows detected. Review duplicate QA output files.")
}