# 01_spotrac_pull.R
# Extract NHL signed free agent data from Spotrac page source HTML by year and position.

suppressPackageStartupMessages({
	library(rvest)
	library(httr)
	library(tidyverse)
	library(here)
})

# Browser-mimicking user agent is required so Spotrac returns full page-source HTML.
spotrac_ua <- httr::user_agent(
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

# Keep 2017:2025 until 2026 offseason data is published on Spotrac.
# Add 2026 after July 2026 when UFA signing pages open for that cycle.
years <- 2017:2025
positions <- c("g", "d", "c", "lw", "rw")

clean_colnames <- function(x) {
	x |>
		stringr::str_to_lower() |>
		stringr::str_replace_all("[^a-z0-9]+", "_") |>
		stringr::str_replace_all("^_+|_+$", "")
}

pick_col <- function(tbl, patterns) {
	nms <- names(tbl)
	hits <- nms[stringr::str_detect(nms, stringr::regex(patterns, ignore_case = TRUE))]
	if (length(hits) == 0) {
		return(NA_character_)
	}
	hits[[1]]
}

master_tbl <- tibble()
breakdown <- tibble(
	spotrac_year = integer(),
	position_filter = character(),
	rows_extracted = integer()
)

for (yr in years) {
	for (pos in positions) {
		target_url <- sprintf(
			"https://www.spotrac.com/nhl/free-agents/signed/_/year/%s/position/%s",
			yr,
			pos
		)

		message(sprintf("Requesting year=%s, position=%s", yr, pos))

		# Request stage error handling
		resp <- tryCatch(
			{
				httr::GET(url = target_url, spotrac_ua)
			},
			error = function(e) {
				warning(sprintf(
					"GET failed for year=%s, position=%s. Error: %s",
					yr,
					pos,
					conditionMessage(e)
				))
				NULL
			}
		)

		if (is.null(resp)) {
			next
		}

		if (httr::status_code(resp) != 200) {
			warning(sprintf(
				"Non-200 response for year=%s, position=%s. Status=%s",
				yr,
				pos,
				httr::status_code(resp)
			))
			next
		}

		# Parse stage error handling
		parsed_tbl <- tryCatch(
			{
				extract_type_map <- function(type_value) {
					type_url <- sprintf(
						"https://www.spotrac.com/nhl/free-agents/signed/_/year/%s/position/%s/type/%s",
						yr,
						pos,
						type_value
					)

					type_resp <- tryCatch(
						{
							httr::GET(url = type_url, spotrac_ua)
						},
						error = function(e) {
							warning(sprintf(
								"GET failed for type map year=%s, position=%s, type=%s. Error: %s",
								yr,
								pos,
								type_value,
								conditionMessage(e)
							))
							NULL
						}
					)

					if (is.null(type_resp) || httr::status_code(type_resp) != 200) {
						return(tibble(
							player_name = character(),
							signing_team = character(),
							previous_team = character(),
							ufa_rfa_type = character()
						))
					}

					type_page <- httr::content(type_resp, as = "text", encoding = "UTF-8") |>
						read_html()

					type_tables <- type_page |>
						html_elements("table") |>
						html_table(fill = TRUE)

					if (length(type_tables) == 0) {
						return(tibble(
							player_name = character(),
							signing_team = character(),
							previous_team = character(),
							ufa_rfa_type = character()
						))
					}

					type_idx <- which(map_lgl(type_tables, function(x) {
						nms <- names(x) |>
							stringr::str_to_lower() |>
							stringr::str_replace_all("[^a-z0-9]", "")

						has_player <- any(stringr::str_detect(nms, "player|name"))
						has_from <- any(stringr::str_detect(nms, "^from$"))
						has_to <- any(stringr::str_detect(nms, "^to$"))

						has_player && has_from && has_to
					}))

					if (length(type_idx) == 0) {
						return(tibble(
							player_name = character(),
							signing_team = character(),
							previous_team = character(),
							ufa_rfa_type = character()
						))
					}

					type_tbl <- type_tables[[type_idx[1]]]
					type_nms <- clean_colnames(names(type_tbl))
					type_blank_idx <- which(is.na(type_nms) | type_nms == "")
					if (length(type_blank_idx) > 0) {
						type_nms[type_blank_idx] <- paste0("col_", type_blank_idx)
					}
					names(type_tbl) <- make.unique(type_nms, sep = "_")

					player_type_col <- pick_col(type_tbl, "player|name")
					signing_type_col <- pick_col(type_tbl, "^to$")
					previous_type_col <- pick_col(type_tbl, "^from$")

					if (is.na(player_type_col) || is.na(signing_type_col) || is.na(previous_type_col)) {
						return(tibble(
							player_name = character(),
							signing_team = character(),
							previous_team = character(),
							ufa_rfa_type = character()
						))
					}

					tibble(
						player_name = type_tbl[[player_type_col]],
						signing_team = type_tbl[[signing_type_col]],
						previous_team = type_tbl[[previous_type_col]],
						ufa_rfa_type = stringr::str_to_upper(type_value)
					) |>
						mutate(across(everything(), ~ stringr::str_squish(as.character(.x)))) |>
						filter(!is.na(player_name), player_name != "")
				}

				page <- httr::content(resp, as = "text", encoding = "UTF-8") |>
					read_html()

				table_nodes <- page |>
					html_elements("table")

				tables <- table_nodes |>
					html_table(fill = TRUE)

				if (length(tables) == 0) {
					warning(sprintf(
						"No tables found for year=%s, position=%s.",
						yr,
						pos
					))
					return(NULL)
				}

				# Keep tables likely to be the signing data table by expected column semantics.
				table_idx <- which(map_lgl(tables, function(x) {
					nms <- names(x) |>
						stringr::str_to_lower() |>
						stringr::str_replace_all("[^a-z0-9]", "")

					has_player <- any(stringr::str_detect(nms, "player|name"))
					has_position <- any(stringr::str_detect(nms, "position|pos"))
					has_team <- sum(stringr::str_detect(nms, "team|from|to|signed")) >= 1
					has_contract <- sum(stringr::str_detect(nms, "contract|aav|avg|year|term|value")) >= 1

					has_player && has_position && has_team && has_contract
				}))

				if (length(table_idx) == 0) {
					warning(sprintf(
						"No matching signing table found for year=%s, position=%s.",
						yr,
						pos
					))
					return(NULL)
				}

				selected_idx <- table_idx[1]
				tbl <- tables[[selected_idx]]
				tbl_node <- table_nodes[[selected_idx]]
				nms <- clean_colnames(names(tbl))
				blank_idx <- which(is.na(nms) | nms == "")
				if (length(blank_idx) > 0) {
					nms[blank_idx] <- paste0("col_", blank_idx)
				}
				names(tbl) <- make.unique(nms, sep = "_")
				tbl <- tbl |>
					mutate(across(everything(), ~ stringr::str_squish(as.character(.x))))

				headers_clean <- tbl_node |>
					html_elements("thead th") |>
					html_text2() |>
					clean_colnames()

				row_nodes <- tbl_node |>
					html_elements("tbody tr")

				years_col_idx <- which(stringr::str_detect(headers_clean, "^yrs$|year|term"))
				aav_col_idx <- which(stringr::str_detect(headers_clean, "^aav"))

				years_from_data_sort <- rep(NA_character_, nrow(tbl))
				aav_from_data_sort <- rep(NA_character_, nrow(tbl))
				ufa_rfa_from_row_html <- rep(NA_character_, nrow(tbl))

				if (length(years_col_idx) > 0) {
					years_from_data_sort <- purrr::map_chr(row_nodes, function(rn) {
						tds <- rn |>
							html_elements("td")

						if (length(tds) < years_col_idx[1]) {
							return(NA_character_)
						}

						years_td <- tds[[years_col_idx[1]]]
						years_attr <- years_td |>
							html_attr("data-sort")
						years_text <- years_td |>
							html_text2() |>
							stringr::str_squish()

						if (!is.na(years_attr) && years_attr != "") {
							return(years_attr)
						}

						if (years_text == "") {
							return(NA_character_)
						}

						years_text
					})

					if (length(years_from_data_sort) != nrow(tbl)) {
						years_from_data_sort <- rep(NA_character_, nrow(tbl))
					}
				}

				if (length(aav_col_idx) > 0) {
					aav_from_data_sort <- purrr::map_chr(row_nodes, function(rn) {
						tds <- rn |>
							html_elements("td")

						if (length(tds) < aav_col_idx[1]) {
							return(NA_character_)
						}

						aav_td <- tds[[aav_col_idx[1]]]
						aav_attr <- aav_td |>
							html_attr("data-sort")
						aav_text <- aav_td |>
							html_text2() |>
							stringr::str_squish()

						if (!is.na(aav_attr) && aav_attr != "") {
							return(aav_attr)
						}

						if (aav_text == "") {
							return(NA_character_)
						}

						aav_text
					})

					if (length(aav_from_data_sort) != nrow(tbl)) {
						aav_from_data_sort <- rep(NA_character_, nrow(tbl))
					}
				}

				ufa_rfa_from_row_html <- purrr::map_chr(row_nodes, function(rn) {
					status_txt <- rn |>
						html_element("td.contract-free_agent_type .pill-start") |>
						html_text2()

					status_txt <- status_txt |>
						stringr::str_squish() |>
						stringr::str_to_upper()

					if (is.na(status_txt) || status_txt == "") {
						return(NA_character_)
					}

					status_txt
				})

				if (length(ufa_rfa_from_row_html) != nrow(tbl)) {
					ufa_rfa_from_row_html <- rep(NA_character_, nrow(tbl))
				}

				# Skip effectively empty pulls.
				if (nrow(tbl) == 0 || all(tbl == "" | is.na(tbl))) {
					warning(sprintf(
						"Empty table for year=%s, position=%s. Skipping.",
						yr,
						pos
					))
					return(NULL)
				}

				player_col <- pick_col(tbl, "player|name")
				position_col <- pick_col(tbl, "^pos$|position")
				signing_team_col <- pick_col(tbl, "signedwith|signingteam|newteam|to_team|to")
				previous_team_col <- pick_col(tbl, "previousteam|fromteam|formerteam|from")
				contract_value_col <- pick_col(tbl, "contractvalue|value")
				aav_col <- pick_col(tbl, "^aav$|averageannual|avgannual")
				contract_years_col <- pick_col(tbl, "contractyears|years|term|^yrs$")
				ufa_rfa_col <- pick_col(tbl, "ufarfa|ufa_rfa|status|type")

				out_tbl <- tibble(
					player_name = if (!is.na(player_col)) tbl[[player_col]] else NA_character_,
					position = if (!is.na(position_col)) tbl[[position_col]] else NA_character_,
					signing_team = if (!is.na(signing_team_col)) tbl[[signing_team_col]] else NA_character_,
					previous_team = if (!is.na(previous_team_col)) tbl[[previous_team_col]] else NA_character_,
					contract_value = if (!is.na(contract_value_col)) tbl[[contract_value_col]] else NA_character_,
					aav = if (any(!is.na(aav_from_data_sort) & aav_from_data_sort != "")) {
						aav_from_data_sort
					} else if (!is.na(aav_col)) {
						tbl[[aav_col]]
					} else {
						NA_character_
					},
					contract_years = if (any(!is.na(years_from_data_sort) & years_from_data_sort != "")) {
						years_from_data_sort
					} else if (!is.na(contract_years_col)) {
						tbl[[contract_years_col]]
					} else {
						NA_character_
					},
					ufa_rfa_type = if (any(!is.na(ufa_rfa_from_row_html) & ufa_rfa_from_row_html != "")) {
						ufa_rfa_from_row_html
					} else if (!is.na(ufa_rfa_col)) {
						tbl[[ufa_rfa_col]]
					} else {
						NA_character_
					}
				)

				type_map <- bind_rows(
					extract_type_map("ufa"),
					extract_type_map("rfa")
				) |>
					distinct(player_name, signing_team, previous_team, .keep_all = TRUE)

				if (nrow(type_map) > 0) {
					out_tbl <- out_tbl |>
						mutate(
							player_name_key = stringr::str_to_upper(stringr::str_squish(player_name)),
							signing_team_key = stringr::str_to_upper(stringr::str_squish(signing_team)),
							previous_team_key = stringr::str_to_upper(stringr::str_squish(previous_team))
						) |>
						left_join(
							type_map |>
								mutate(
									player_name_key = stringr::str_to_upper(stringr::str_squish(player_name)),
									signing_team_key = stringr::str_to_upper(stringr::str_squish(signing_team)),
									previous_team_key = stringr::str_to_upper(stringr::str_squish(previous_team))
								) |>
								select(player_name_key, signing_team_key, previous_team_key, ufa_rfa_type_join = ufa_rfa_type),
							by = c("player_name_key", "signing_team_key", "previous_team_key")
						) |>
						mutate(ufa_rfa_type = coalesce(ufa_rfa_type_join, ufa_rfa_type)) |>
						select(-player_name_key, -signing_team_key, -previous_team_key, -ufa_rfa_type_join)
				}

				if (nrow(out_tbl) == 0 || all(out_tbl$player_name == "" | is.na(out_tbl$player_name))) {
					warning(sprintf(
						"Extracted table has no signing rows for year=%s, position=%s. Skipping.",
						yr,
						pos
					))
					return(NULL)
				}

				out_tbl |>
					filter(!is.na(player_name), player_name != "") |>
					mutate(
						spotrac_year = as.integer(yr),
						position_filter = as.character(pos)
					)
			},
			error = function(e) {
				warning(sprintf(
					"Parse failed for year=%s, position=%s. Error: %s",
					yr,
					pos,
					conditionMessage(e)
				))
				NULL
			}
		)

		if (is.null(parsed_tbl)) {
			next
		}

		master_tbl <- bind_rows(master_tbl, parsed_tbl)

		breakdown <- bind_rows(
			breakdown,
			tibble(
				spotrac_year = as.integer(yr),
				position_filter = as.character(pos),
				rows_extracted = nrow(parsed_tbl)
			)
		)
	}
}

rows_before_dedup <- nrow(master_tbl)
master_tbl <- master_tbl |>
	add_count(player_name, signing_team, spotrac_year, position_filter, name = "key_row_count") |>
	filter(key_row_count == 1) |>
	select(-key_row_count)
rows_after_dedup <- nrow(master_tbl)

output_path <- here::here("data", "raw", "spotrac", "nhl_signed_free_agents_raw.csv")
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(master_tbl, output_path)

message(sprintf("Completed Spotrac pull. Total rows extracted: %s", nrow(master_tbl)))
message(sprintf("Dedup step removed %s rows based on player_name/signing_team/spotrac_year/position_filter.", rows_before_dedup - rows_after_dedup))

if (nrow(breakdown) > 0) {
	message("Year and position breakdown:")
	print(breakdown |> arrange(spotrac_year, position_filter))
} else {
	message("No rows were extracted for any year/position combination.")
}
