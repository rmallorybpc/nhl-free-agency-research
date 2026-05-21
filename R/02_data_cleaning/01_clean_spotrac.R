# 01_clean_spotrac.R
# Clean and standardize Spotrac NHL signing data into a flat transaction table
# for downstream feature engineering.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
})

expected_input_rows <- 2493
expected_ufa_rows <- 1878
expected_years <- 2017:2025

input_path <- here::here("data", "raw", "spotrac", "nhl_signed_free_agents_raw.csv")
output_path <- here::here("data", "processed", "nhl_signed_free_agents_clean.csv")

raw_df <- readr::read_csv(input_path, show_col_types = FALSE)
input_rows <- nrow(raw_df)

normalize_ufa_rfa <- function(x) {
	x_chr <- x |>
		as.character() |>
		stringr::str_squish() |>
		stringr::str_to_upper()

	dplyr::case_when(
		x_chr %in% c("UFA", "UNRESTRICTED FREE AGENT", "UNRESTRICTED") ~ "UFA",
		x_chr %in% c("RFA", "RESTRICTED FREE AGENT", "RESTRICTED") ~ "RFA",
		x_chr %in% c("1", "TRUE", "T") ~ "UFA",
		x_chr %in% c("0", "FALSE", "F") ~ "RFA",
		x_chr %in% c("", "NA", "N/A", "NULL") ~ NA_character_,
		TRUE ~ x_chr
	)
}

to_numeric_currency <- function(x) {
	x |>
		as.character() |>
		stringr::str_replace_all("[^0-9.]", "") |>
		na_if("") |>
		as.numeric()
}

clean_df <- raw_df |>
	mutate(
		ufa_rfa_type = normalize_ufa_rfa(ufa_rfa_type)
	) |>
	# Deliberate scope decision: exclude RFAs because qualifying-offer rules constrain
	# market choice and make them analytically different from UFAs. RFA rows remain
	# in the raw extract for transparency; this is documented in README and scope docs.
	filter(ufa_rfa_type == "UFA") |>
	# Reserved for future integration with trade transactions (transaction_type = "trade").
	mutate(
		transaction_type = "UFA_signing",
		player_name = player_name |>
			stringr::str_squish() |>
			stringr::str_to_title(),
		signing_team = signing_team |>
			stringr::str_squish() |>
			stringr::str_to_upper(),
		previous_team = previous_team |>
			stringr::str_squish() |>
			stringr::str_to_upper() |>
			replace_na("UNKNOWN") |>
			na_if("") |>
			replace_na("UNKNOWN"),
		position = position |>
			stringr::str_squish() |>
			stringr::str_to_upper(),
		position = dplyr::case_when(
			position %in% c("G", "GOALIE", "GOALTENDER") ~ "G",
			position %in% c("D", "DEFENSE", "DEFENCEMAN", "DEFENSEMAN") ~ "D",
			position %in% c("C", "CENTER", "CENTRE") ~ "C",
			position %in% c("LW", "LEFT WING") ~ "LW",
			position %in% c("RW", "RIGHT WING") ~ "RW",
			TRUE ~ position
		),
		contract_value = to_numeric_currency(contract_value),
		aav = to_numeric_currency(aav),
		contract_years = contract_years |>
			as.character() |>
			stringr::str_replace_all("[^0-9.-]", "") |>
			na_if("") |>
			as.integer(),
		spotrac_year = as.integer(spotrac_year),
		same_team_resign = signing_team == previous_team,
		# Placeholder fields are populated in R/03_feature_engineering/03_build_geography.R.
		division_change = NA,
		conference_change = NA
	)

rows_after_ufa <- nrow(clean_df)

year_counts <- tibble(spotrac_year = expected_years) |>
	left_join(
		clean_df |>
			count(spotrac_year, name = "rows"),
		by = "spotrac_year"
	) |>
	mutate(rows = replace_na(rows, 0L)) |>
	arrange(spotrac_year)

year_zero_check <- year_counts |>
	filter(rows == 0)

same_team_counts <- clean_df |>
	count(same_team_resign, name = "rows")

same_team_true <- same_team_counts |>
	filter(same_team_resign) |>
	pull(rows)
if (length(same_team_true) == 0) same_team_true <- 0

movement_false <- same_team_counts |>
	filter(!same_team_resign) |>
	pull(rows)
if (length(movement_false) == 0) movement_false <- 0

na_counts <- clean_df |>
	summarise(
		na_player_name = sum(is.na(player_name) | player_name == ""),
		na_signing_team = sum(is.na(signing_team) | signing_team == ""),
		na_aav = sum(is.na(aav)),
		na_contract_years = sum(is.na(contract_years))
	)

aav_min <- suppressWarnings(min(clean_df$aav, na.rm = TRUE))
aav_max <- suppressWarnings(max(clean_df$aav, na.rm = TRUE))
contract_years_non_positive <- sum(clean_df$contract_years <= 0, na.rm = TRUE)

if (!is.finite(aav_min)) {
	aav_min <- NA_real_
}
if (!is.finite(aav_max)) {
	aav_max <- NA_real_
}

cat("\n=== Spotrac Clean QA ===\n")
cat(sprintf("Total rows after UFA filter: %s (expected: %s)\n", rows_after_ufa, expected_ufa_rows))

cat("\nRow count by spotrac_year:\n")
print(year_counts)

if (nrow(year_zero_check) > 0) {
	cat("WARNING: One or more years have zero rows after UFA filter.\n")
	print(year_zero_check)
} else {
	cat("No zero-row years detected for 2017 to 2025.\n")
}

cat("\nCount of same_team_resign TRUE/FALSE:\n")
print(same_team_counts)

cat("\nRemaining NA/blank counts for required fields:\n")
print(na_counts)

cat("\nAAV sanity check:\n")
cat(sprintf("Min AAV: %s\n", format(aav_min, big.mark = ",", scientific = FALSE)))
cat(sprintf("Max AAV: %s\n", format(aav_max, big.mark = ",", scientific = FALSE)))

if (!is.na(aav_min) && aav_min < 750000) {
	cat("WARNING: Min AAV below 750000. Check parsing or source anomalies.\n")
}
if (!is.na(aav_max) && aav_max > 15000000) {
	cat("WARNING: Max AAV above 15000000. Check parsing or source anomalies.\n")
}

if (contract_years_non_positive > 0) {
	cat(sprintf("WARNING: contract_years has %s non-positive values (<= 0).\n", contract_years_non_positive))
}

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(clean_df, output_path)

cat("\n=== Cleaning Complete ===\n")
cat(sprintf("Input rows: %s (expected: %s)\n", input_rows, expected_input_rows))
cat(sprintf("Rows after UFA filter: %s (expected: %s)\n", rows_after_ufa, expected_ufa_rows))
cat(sprintf("Same-team re-signs: %s | Genuine movement events: %s\n", same_team_true, movement_false))
cat(sprintf("Output rows written: %s (expected: %s)\n", nrow(clean_df), expected_ufa_rows))
cat(sprintf("Output file: %s\n", output_path))
