# 00_spotrac_raw_qa.R
# Quality assurance checks for Spotrac NHL signed free agent raw extract.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
})

expected_rows <- 2493
expected_year_min <- 2017
expected_year_max <- 2025
expected_years <- expected_year_min:expected_year_max

expected_ufa <- 1878
expected_rfa <- 615

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
	warning(
		sprintf(
			"Missing required columns (continuing with available columns): %s",
			paste(missing_required, collapse = ", ")
		)
	)
}

safe_vec <- function(data, field) {
	if (field %in% names(data)) {
		data[[field]]
	} else {
		rep(NA_character_, nrow(data))
	}
}

missing_count <- function(x) {
	sum(is.na(x) | stringr::str_squish(as.character(x)) == "")
}

qa_status <- tibble(
	check = character(),
	status = character(),
	details = character()
)

add_status <- function(check, pass, details) {
	status <- ifelse(pass, "PASS", "WARN")
	qa_status <<- bind_rows(
		qa_status,
		tibble(check = check, status = status, details = details)
	)
}

total_rows <- nrow(spotrac_raw)
total_cols <- ncol(spotrac_raw)
spotrac_year_numeric <- suppressWarnings(as.integer(safe_vec(spotrac_raw, "spotrac_year")))
year_min <- suppressWarnings(min(spotrac_year_numeric, na.rm = TRUE))
year_max <- suppressWarnings(max(spotrac_year_numeric, na.rm = TRUE))

if (all(is.infinite(c(year_min, year_max)))) {
	year_min <- NA_integer_
	year_max <- NA_integer_
}

cat("\n=== Spotrac Raw QA Headline Summary ===\n")
cat(sprintf("Total rows evaluated: %s (expected: %s)\n", total_rows, expected_rows))
cat(sprintf("Total columns present: %s\n", total_cols))
cat(sprintf("Year range covered: %s to %s (expected: %s to %s)\n", year_min, year_max, expected_year_min, expected_year_max))

add_status(
	"Headline row count",
	!is.na(total_rows) && total_rows == expected_rows,
	sprintf("rows=%s, expected=%s", total_rows, expected_rows)
)
add_status(
	"Headline year range",
	!is.na(year_min) && !is.na(year_max) && year_min == expected_year_min && year_max == expected_year_max,
	sprintf("year_min=%s, year_max=%s, expected=%s-%s", year_min, year_max, expected_year_min, expected_year_max)
)

key_fields <- c(
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

missing_field_counts <- tibble(field = key_fields) |>
	mutate(
		missing_rows = map_int(field, function(fld) {
			missing_count(safe_vec(spotrac_raw, fld))
		}),
		missing_pct = round((missing_rows / total_rows) * 100, 2)
	)

readr::write_csv(
	missing_field_counts,
	file.path(output_dir, "spotrac_raw_qa_missing_field_counts.csv")
)

cat("\nMissing field counts (key columns):\n")
print(missing_field_counts)

add_status(
	"Missing key fields",
	all(missing_field_counts$missing_rows == 0),
	sprintf("fields_with_missing=%s", sum(missing_field_counts$missing_rows > 0))
)

ufa_rfa_norm <- safe_vec(spotrac_raw, "ufa_rfa_type") |>
	as.character() |>
	stringr::str_trim() |>
	stringr::str_to_upper()

ufa_count <- sum(ufa_rfa_norm == "UFA", na.rm = TRUE)
rfa_count <- sum(ufa_rfa_norm == "RFA", na.rm = TRUE)
other_or_missing_count <- sum(is.na(ufa_rfa_norm) | ufa_rfa_norm == "" | !ufa_rfa_norm %in% c("UFA", "RFA"))

ufa_rfa_distribution <- tibble(
	category = c("UFA", "RFA", "OTHER_OR_MISSING"),
	rows = c(ufa_count, rfa_count, other_or_missing_count),
	expected_rows = c(expected_ufa, expected_rfa, 0)
)

readr::write_csv(
	ufa_rfa_distribution,
	file.path(output_dir, "spotrac_raw_qa_ufa_rfa_distribution.csv")
)

cat("\nUFA/RFA distribution:\n")
print(ufa_rfa_distribution)

add_status(
	"UFA/RFA distribution",
	ufa_count == expected_ufa &&
		rfa_count == expected_rfa &&
		other_or_missing_count == 0,
	sprintf("UFA=%s/%s, RFA=%s/%s, other_or_missing=%s", ufa_count, expected_ufa, rfa_count, expected_rfa, other_or_missing_count)
)

year_totals <- tibble(spotrac_year = expected_years) |>
	left_join(
		spotrac_raw |>
			mutate(
				spotrac_year = suppressWarnings(as.integer(spotrac_year)),
				ufa_rfa_type_norm = stringr::str_to_upper(stringr::str_trim(as.character(ufa_rfa_type)))
			) |>
			group_by(spotrac_year) |>
			summarise(
				total_signings = n(),
				ufa_count = sum(ufa_rfa_type_norm == "UFA", na.rm = TRUE),
				rfa_count = sum(ufa_rfa_type_norm == "RFA", na.rm = TRUE),
				.groups = "drop"
			),
		by = "spotrac_year"
	) |>
	mutate(
		across(c(total_signings, ufa_count, rfa_count), ~ replace_na(.x, 0L)),
		zero_row_warning = total_signings == 0
	)

readr::write_csv(
	year_totals,
	file.path(output_dir, "spotrac_raw_qa_year_totals.csv")
)

cat("\nYear totals:\n")
print(year_totals)

add_status(
	"Year totals nonzero",
	!any(year_totals$zero_row_warning),
	sprintf("zero_years=%s", sum(year_totals$zero_row_warning))
)

year_position_totals <- spotrac_raw |>
	mutate(
		spotrac_year = suppressWarnings(as.integer(spotrac_year)),
		position_filter = as.character(position_filter)
	) |>
	count(spotrac_year, position_filter, name = "rows") |>
	arrange(spotrac_year, position_filter)

readr::write_csv(
	year_position_totals,
	file.path(output_dir, "spotrac_raw_qa_year_position_totals.csv")
)

key_dup_cols <- c("player_name", "signing_team", "spotrac_year", "position")

key_duplicates <- spotrac_raw |>
	mutate(
		across(
			all_of(key_dup_cols),
			~ stringr::str_squish(as.character(.x))
		)
	) |>
	group_by(across(all_of(key_dup_cols))) |>
	filter(n() > 1) |>
	arrange(spotrac_year, signing_team, player_name, position) |>
	ungroup()

key_duplicate_count <- nrow(key_duplicates)
key_dup_path <- file.path(output_dir, "spotrac_raw_qa_key_duplicates.csv")
cat(sprintf("\nKey duplicate rows: %s\n", key_duplicate_count))

if (key_duplicate_count > 0) {
	readr::write_csv(
		key_duplicates,
		key_dup_path
	)
} else if (file.exists(key_dup_path)) {
	file.remove(key_dup_path)
}

add_status(
	"Key duplicates",
	key_duplicate_count == 0,
	sprintf("duplicate_rows=%s", key_duplicate_count)
)

exact_duplicates <- spotrac_raw |>
	group_by(across(everything())) |>
	filter(n() > 1) |>
	ungroup()

exact_duplicate_count <- nrow(exact_duplicates)
exact_dup_path <- file.path(output_dir, "spotrac_raw_qa_exact_duplicates.csv")
cat(sprintf("Exact full-row duplicates: %s\n", exact_duplicate_count))

if (exact_duplicate_count > 0) {
	readr::write_csv(
		exact_duplicates,
		exact_dup_path
	)
} else if (file.exists(exact_dup_path)) {
	file.remove(exact_dup_path)
}

add_status(
	"Exact duplicates",
	exact_duplicate_count == 0,
	sprintf("duplicate_rows=%s", exact_duplicate_count)
)

aav_numeric <- suppressWarnings(as.numeric(safe_vec(spotrac_raw, "aav")))
aav_min <- suppressWarnings(min(aav_numeric, na.rm = TRUE))
aav_max <- suppressWarnings(max(aav_numeric, na.rm = TRUE))
aav_na_count <- sum(is.na(aav_numeric))

if (all(is.infinite(c(aav_min, aav_max)))) {
	aav_min <- NA_real_
	aav_max <- NA_real_
}

aav_summary <- tibble(
	min_aav = aav_min,
	max_aav = aav_max,
	aav_na_count = aav_na_count,
	flag_min_below_750k = ifelse(is.na(aav_min), TRUE, aav_min < 750000),
	flag_max_above_15m = ifelse(is.na(aav_max), TRUE, aav_max > 15000000)
)

readr::write_csv(
	aav_summary,
	file.path(output_dir, "spotrac_raw_qa_aav_summary.csv")
)

cat("\nAAV summary:\n")
print(aav_summary)

add_status(
	"AAV checks",
	!aav_summary$flag_min_below_750k &&
		!aav_summary$flag_max_above_15m &&
		aav_na_count == 0,
	sprintf("min=%s, max=%s, na_count=%s", aav_min, aav_max, aav_na_count)
)

contract_years_numeric <- suppressWarnings(as.numeric(safe_vec(spotrac_raw, "contract_years")))
contract_years_na_count <- sum(is.na(contract_years_numeric))
contract_years_non_positive_count <- sum(contract_years_numeric <= 0, na.rm = TRUE)

contract_years_distribution <- tibble(contract_years = contract_years_numeric) |>
	filter(!is.na(contract_years)) |>
	count(contract_years, name = "rows") |>
	arrange(contract_years) |>
	mutate(
		contract_years_na_count = contract_years_na_count,
		non_positive_count = contract_years_non_positive_count,
		has_non_positive = contract_years_non_positive_count > 0
	)

readr::write_csv(
	contract_years_distribution,
	file.path(output_dir, "spotrac_raw_qa_contract_years_distribution.csv")
)

cat("\nContract years distribution:\n")
print(contract_years_distribution)

add_status(
	"Contract years checks",
	contract_years_na_count == 0 && contract_years_non_positive_count == 0,
	sprintf("na_count=%s, non_positive_count=%s", contract_years_na_count, contract_years_non_positive_count)
)

add_status(
	"Required columns present",
	length(missing_required) == 0,
	ifelse(length(missing_required) == 0, "all required columns found", paste(missing_required, collapse = ", "))
)

cat("\n=== Spotrac Raw QA Final Summary ===\n")
print(qa_status)

if (any(qa_status$status == "WARN")) {
	cat("Overall QA result: WARN (one or more checks flagged)\n")
} else {
	cat("Overall QA result: PASS\n")
}