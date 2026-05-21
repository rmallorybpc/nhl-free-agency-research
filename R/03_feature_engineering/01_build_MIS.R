# 01_build_MIS.R
# Build weighted Movement Impact Score (MIS) by team-season from cleaned UFA signings.

library(tidyverse)
library(here)

# Position tier weights are prior assumptions in Version 1 and will be calibrated
# in the analysis phase as part of model sensitivity checks.
tier_weights <- c(
	"Tier 1" = 0.35,  # G
	"Tier 2" = 0.25,  # D
	"Tier 3" = 0.20,  # C
	"Tier 4" = 0.15,  # LW/RW
	"Tier 5" = 0.05   # unmatched positions
)

# Tier 2 defenseman weight is applied uniformly in Version 1.
# Planned Version 2 enhancement: split top pairing vs bottom pairing defensemen
# using ice time and/or RAPM-informed role indicators.

signed_free_agents <- read_csv(
	here::here("data", "processed", "nhl_signed_free_agents_clean.csv"),
	show_col_types = FALSE
)

# Exclude same-team re-signings to keep only genuine movement events.
# This leaves 1648 rows representing actual player movement between teams.
movement_events <- signed_free_agents %>%
	filter(!same_team_resign)

# Exclude the 9 flagged rows with missing/zero AAV because AAV is required for MIS.
mis_input <- movement_events %>%
	filter(is.na(data_quality_note))

mis_by_team_season <- mis_input %>%
	mutate(
		position_std = str_to_upper(str_trim(position)),
		position_tier = case_when(
			position_std == "G" ~ "Tier 1",
			position_std == "D" ~ "Tier 2",
			position_std == "C" ~ "Tier 3",
			position_std %in% c("LW", "RW") ~ "Tier 4",
			TRUE ~ "Tier 5"
		),
		tier_weight = case_when(
			position_tier == "Tier 1" ~ tier_weights[["Tier 1"]],
			position_tier == "Tier 2" ~ tier_weights[["Tier 2"]],
			position_tier == "Tier 3" ~ tier_weights[["Tier 3"]],
			position_tier == "Tier 4" ~ tier_weights[["Tier 4"]],
			TRUE ~ tier_weights[["Tier 5"]]
		),
		weighted_aav = aav * tier_weight
	) %>%
	group_by(signing_team, spotrac_year) %>%
	summarise(
		total_mis = sum(weighted_aav, na.rm = TRUE),
		total_aav_spent = sum(aav, na.rm = TRUE),
		signing_count = n(),
		signing_count_tier1 = sum(position_tier == "Tier 1"),
		signing_count_tier2 = sum(position_tier == "Tier 2"),
		signing_count_tier3 = sum(position_tier == "Tier 3"),
		signing_count_tier4 = sum(position_tier == "Tier 4"),
		has_goalie_signing = any(position_tier == "Tier 1"),
		.groups = "drop"
	) %>%
	# Rename year key for alignment with performance data join key.
	rename(season_year = spotrac_year)

team_season_panel <- read_csv(
	here::here("data", "processed", "nhl_team_season_performance_clean.csv"),
	show_col_types = FALSE
) %>%
	transmute(
		signing_team = teamTriCode,
		season_year = as.integer(season_year)
	) %>%
	distinct()

mis_output <- team_season_panel %>%
	left_join(
		mis_by_team_season %>% mutate(season_year = as.integer(season_year)),
		by = c("signing_team", "season_year")
	) %>%
	# Zero MIS rows are meaningful: teams made no qualifying UFA acquisitions.
	mutate(
		total_mis = coalesce(total_mis, 0),
		total_aav_spent = coalesce(total_aav_spent, 0),
		signing_count = coalesce(signing_count, 0L),
		signing_count_tier1 = coalesce(signing_count_tier1, 0L),
		signing_count_tier2 = coalesce(signing_count_tier2, 0L),
		signing_count_tier3 = coalesce(signing_count_tier3, 0L),
		signing_count_tier4 = coalesce(signing_count_tier4, 0L),
		has_goalie_signing = coalesce(has_goalie_signing, FALSE)
	) %>%
	arrange(season_year, signing_team)

# Inline QA checks
total_rows <- nrow(mis_output)
zero_mis_count <- sum(mis_output$total_mis == 0)
goalie_team_season_count <- sum(mis_output$has_goalie_signing)
non_zero_mis_count <- sum(mis_output$total_mis > 0)

mis_stats <- mis_output %>%
	summarise(
		min_total_mis = min(total_mis, na.rm = TRUE),
		max_total_mis = max(total_mis, na.rm = TRUE),
		mean_total_mis = mean(total_mis, na.rm = TRUE)
	)

aav_stats <- mis_output %>%
	summarise(
		min_total_aav_spent = min(total_aav_spent, na.rm = TRUE),
		max_total_aav_spent = max(total_aav_spent, na.rm = TRUE),
		mean_total_aav_spent = mean(total_aav_spent, na.rm = TRUE)
	)

signing_count_distribution <- mis_output %>%
	mutate(
		signing_count_bucket = case_when(
			signing_count >= 3 ~ "3+",
			TRUE ~ as.character(signing_count)
		)
	) %>%
	count(signing_count_bucket, name = "team_seasons") %>%
	mutate(
		signing_count_bucket = factor(
			signing_count_bucket,
			levels = c("0", "1", "2", "3+")
		)
	) %>%
	arrange(signing_count_bucket)

cat("===== MIS QA CHECKS =====\n")
cat("Total team-season rows in output:", total_rows, "(expected 282)\n")
cat("Team-seasons with zero total_mis:", zero_mis_count, "\n")
cat("Team-seasons with at least one goalie signing:", goalie_team_season_count, "\n")
cat(
	"total_mis min/max/mean:",
	mis_stats$min_total_mis,
	"/",
	mis_stats$max_total_mis,
	"/",
	round(mis_stats$mean_total_mis, 2),
	"\n"
)
cat(
	"total_aav_spent min/max/mean:",
	aav_stats$min_total_aav_spent,
	"/",
	aav_stats$max_total_aav_spent,
	"/",
	round(aav_stats$mean_total_aav_spent, 2),
	"\n"
)
cat("Distribution of signing_count (0,1,2,3+):\n")
print(signing_count_distribution)

write_csv(
	mis_output,
	here::here("data", "processed", "nhl_team_mis_scores.csv")
)

cat(
	"MIS build complete. Rows written:",
	total_rows,
	"| Team-seasons with non-zero MIS:",
	non_zero_mis_count,
	"\n"
)
