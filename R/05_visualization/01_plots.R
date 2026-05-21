# 01_plots.R
# Produces publication-quality figures for the NHL free agency research project.

suppressPackageStartupMessages({
	library(tidyverse)
	library(here)
	library(ggplot2)
})

input_panel_path <- here::here("data", "processed", "nhl_master_analysis_panel.csv")
model_summary_path <- here::here("output", "tables", "model_comparison_summary.csv")
figure_dir <- here::here("output", "figures")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

panel <- read_csv(input_panel_path, show_col_types = FALSE) %>%
	mutate(
		# Keep this definition aligned with regression scripts for consistency.
		points_pct_change = points_percentage - prior_season_points_pct,
		season_type = factor(
			season_type,
			levels = c("standard", "covid_shortened", "covid_bubble")
		),
		any_cross_conference = as.logical(any_cross_conference),
		cross_conf_label = if_else(any_cross_conference, "Cross-conference signings", "No cross-conference signings")
	)

model_comparison <- read_csv(model_summary_path, show_col_types = FALSE)

plot_n <- nrow(panel)

# All charts in this script use the same base theme for visual consistency.
theme_set(
	theme_minimal(base_size = 12) +
		theme(
			plot.title = element_text(face = "bold"),
			plot.subtitle = element_text(color = "grey40"),
			plot.caption = element_text(color = "grey40"),
			legend.position = "bottom"
		)
)

fig_01 <- here::here("output", "figures", "01_mean_reversion_scatter.png")
fig_02 <- here::here("output", "figures", "02_spending_null_scatter.png")
fig_03 <- here::here("output", "figures", "03_model_comparison.png")
fig_04 <- here::here("output", "figures", "04_mis_distribution_by_season.png")
fig_05 <- here::here("output", "figures", "05_mean_reversion_quartiles.png")

# Chart 1 - Mean Reversion Scatter
plot_1 <- panel %>%
	ggplot(aes(x = prior_season_points_pct, y = points_pct_change, color = season_type)) +
	geom_hline(yintercept = 0, color = "grey70", linetype = "dashed", linewidth = 0.5) +
	geom_point(alpha = 0.8, size = 2.2) +
	geom_smooth(
		aes(group = 1),
		method = "lm",
		se = TRUE,
		color = "grey20",
		fill = "grey65",
		alpha = 0.2,
		linewidth = 0.9
	) +
	annotate(
		"text",
		x = min(panel$prior_season_points_pct, na.rm = TRUE) + 0.01,
		y = max(panel$points_pct_change, na.rm = TRUE) - 0.01,
		label = "Mean reversion slope: -0.42 (p < 0.001)",
		hjust = 0,
		vjust = 1,
		size = 3.7,
		color = "grey20"
	) +
	scale_color_manual(
		values = c(
			"standard" = "#1f77b4",
			"covid_shortened" = "#e67e22",
			"covid_bubble" = "#2ca02c"
		),
		drop = FALSE
	) +
	labs(
		title = "NHL Teams Revert to the Mean After Strong and Weak Seasons",
		subtitle = "Prior season performance strongly predicts performance decline or improvement regardless of offseason spending",
		x = "Prior Season Points Percentage",
		y = "Season-over-Season Change in Points Percentage",
		color = "Season Type",
		caption = "Source: NHL API via nhlscraper, Spotrac. N=252 team-seasons, 2018-2025. COVID seasons shown separately."
	)

ggsave(filename = fig_01, plot = plot_1, width = 11, height = 7, dpi = 320)

# Chart 2 - Spending Null Result Scatter
plot_2 <- panel %>%
	ggplot(aes(x = total_mis, y = points_pct_change, color = cross_conf_label)) +
	geom_hline(yintercept = 0, color = "grey70", linetype = "dashed", linewidth = 0.5) +
	geom_point(alpha = 0.8, size = 2.2) +
	geom_smooth(
		aes(group = 1),
		method = "lm",
		se = TRUE,
		color = "grey20",
		fill = "grey65",
		alpha = 0.2,
		linewidth = 0.9
	) +
	annotate(
		"text",
		x = min(panel$total_mis, na.rm = TRUE),
		y = max(panel$points_pct_change, na.rm = TRUE) - 0.01,
		label = "MIS coefficient: not significant (p = 0.82)",
		hjust = 0,
		vjust = 1,
		size = 3.7,
		color = "grey20"
	) +
	scale_color_manual(
		values = c(
			"No cross-conference signings" = "#1f77b4",
			"Cross-conference signings" = "#d62728"
		)
	) +
	labs(
		title = "Offseason UFA Spending Does Not Predict Team Performance Change",
		subtitle = "Movement Impact Score shows no significant relationship with season-over-season points percentage change",
		x = "Movement Impact Score (Weighted Offseason AAV)",
		y = "Season-over-Season Change in Points Percentage",
		color = "Conference Change Presence",
		caption = "Source: NHL API via nhlscraper, Spotrac. N=252 team-seasons, 2018-2025."
	)

ggsave(filename = fig_02, plot = plot_2, width = 11, height = 7, dpi = 320)

# Chart 3 - Model Comparison Bar Chart
model_order <- c("Model A Full", "Model B Full", "Model A Restricted", "Model B Restricted")

plot_3_data <- model_comparison %>%
	mutate(
		model_name = factor(model_name, levels = model_order),
		model_family = if_else(str_detect(model_name, "Model A"), "Model A", "Model B")
	)

plot_3 <- plot_3_data %>%
	ggplot(aes(x = model_name, y = adj.r.squared, fill = model_family)) +
	geom_hline(yintercept = 0, color = "grey70", linetype = "dashed", linewidth = 0.5) +
	geom_col(width = 0.68) +
	geom_text(
		aes(label = sprintf("%.3f", adj.r.squared)),
		vjust = -0.4,
		size = 3.8,
		color = "grey20"
	) +
	scale_fill_manual(values = c("Model A" = "#1f77b4", "Model B" = "#ff7f0e")) +
	coord_cartesian(ylim = c(0, max(plot_3_data$adj.r.squared, na.rm = TRUE) + 0.04)) +
	labs(
		title = "Positional Weighting Does Not Improve Model Fit Over Raw Spending",
		subtitle = "Adjusted R-squared comparison across model specifications and samples",
		x = "Model Specification",
		y = "Adjusted R-squared",
		fill = "Model Family",
		caption = "Model A uses total AAV spent. Model B uses weighted Movement Impact Score. Higher adjusted R-squared indicates better fit."
	)

ggsave(filename = fig_03, plot = plot_3, width = 10.5, height = 7, dpi = 320)

# Chart 4 - MIS Distribution by Season
overall_mis_mean <- mean(panel$total_mis, na.rm = TRUE)

plot_4_data <- panel %>%
	mutate(
		season_year = as.factor(season_year),
		covid_flag = if_else(season_year %in% c("2020", "2021"), "COVID Season", "Other Season")
	)

plot_4 <- plot_4_data %>%
	ggplot(aes(x = season_year, y = total_mis)) +
	geom_boxplot(aes(fill = covid_flag), width = 0.65, outlier.shape = NA, alpha = 0.85) +
	geom_jitter(width = 0.18, alpha = 0.55, size = 1.5, color = "grey65") +
	geom_hline(yintercept = overall_mis_mean, color = "grey30", linetype = "dashed", linewidth = 0.7) +
	annotate(
		"text",
		x = Inf,
		y = overall_mis_mean,
		label = sprintf("Overall mean = %.0f", overall_mis_mean),
		hjust = 1.05,
		vjust = -0.5,
		color = "grey30",
		size = 3.5
	) +
	scale_fill_manual(values = c("Other Season" = "#4e79a7", "COVID Season" = "#e15759")) +
	labs(
		title = "Distribution of Team Movement Impact Scores by Season",
		subtitle = "Higher MIS reflects greater offseason investment weighted by positional value",
		x = "season_year",
		y = "total_mis",
		fill = "Season Group",
		caption = "Source: Spotrac. N=252 team-seasons, 2018-2025. COVID seasons highlighted."
	)

ggsave(filename = fig_04, plot = plot_4, width = 11, height = 7, dpi = 320)

# Chart 5 - Mean Reversion by Prior Performance Quartile
quartile_labels <- c("Q1 Bottom", "Q2", "Q3", "Q4 Top")

quartile_summary <- panel %>%
	mutate(
		prior_performance_quartile = ntile(prior_season_points_pct, 4),
		prior_performance_quartile = factor(prior_performance_quartile, levels = 1:4, labels = quartile_labels)
	) %>%
	group_by(prior_performance_quartile) %>%
	summarise(mean_points_pct_change = mean(points_pct_change, na.rm = TRUE), .groups = "drop") %>%
	mutate(direction = if_else(mean_points_pct_change >= 0, "Improvement", "Decline"))

plot_5 <- quartile_summary %>%
	ggplot(aes(x = prior_performance_quartile, y = mean_points_pct_change, fill = direction)) +
	geom_hline(yintercept = 0, color = "grey70", linetype = "dashed", linewidth = 0.5) +
	geom_col(width = 0.72) +
	geom_text(
		aes(label = sprintf("%.3f", mean_points_pct_change)),
		vjust = if_else(quartile_summary$mean_points_pct_change >= 0, -0.4, 1.2),
		size = 4,
		color = "grey20"
	) +
	scale_fill_manual(values = c("Improvement" = "#2ca02c", "Decline" = "#d62728")) +
	labs(
		title = "Top Teams Decline, Bottom Teams Improve - Mean Reversion Across Performance Quartiles",
		subtitle = "Teams in the top quartile of prior season performance decline on average the following season",
		x = "Prior Season Performance Quartile",
		y = "Mean Season-over-Season Change in Points Percentage",
		fill = "Direction",
		caption = "Source: NHL API via nhlscraper, Spotrac. N=252 team-seasons, 2018-2025."
	)

ggsave(filename = fig_05, plot = plot_5, width = 11, height = 7.2, dpi = 320)

output_files <- c(
	"01_mean_reversion_scatter.png",
	"02_spending_null_scatter.png",
	"03_model_comparison.png",
	"04_mis_distribution_by_season.png",
	"05_mean_reversion_quartiles.png"
)

cat("\n=== Plot Generation Complete ===\n")
cat("The following files were written to output/figures/:\n")
for (fname in output_files) {
	cat("-", fname, "\n")
}

cat("\n=== QA Check: Output File Existence ===\n")
for (fname in output_files) {
	full_path <- here::here("output", "figures", fname)
	status <- if (file.exists(full_path)) "PASS" else "FAIL"
	cat(status, "-", fname, "\n")
}
