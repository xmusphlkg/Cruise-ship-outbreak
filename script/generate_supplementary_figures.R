#!/usr/bin/env Rscript

suppressPackageStartupMessages({
     library(dplyr)
     library(ggplot2)
     library(readr)
     library(scales)
     library(tidyr)
     library(grid)
})

repo_root <- normalizePath(".", mustWork = TRUE)
data_path <- file.path(repo_root, "output", "table_s_full_dataset.csv")
output_dir <- file.path(repo_root, "output")

cat_map <- c(
     gastrointestinal_viral = "Viral gastroenteritis",
     foodborne_waterborne_bacterial = "GI bacterial/protozoal",
     respiratory_viral = "Respiratory viral",
     legionella = "Legionella spp.",
     vaccine_preventable = "Vaccine-preventable",
     zoonotic = "Zoonotic",
     unknown = "Unknown aetiology"
)

pathogen_levels <- c(
     "Viral gastroenteritis",
     "GI bacterial/protozoal",
     "Respiratory viral",
     "Legionella spp.",
     "Vaccine-preventable",
     "Zoonotic",
     "Unknown aetiology"
)

palette <- c(
     "Viral gastroenteritis" = "#425A8C",
     "GI bacterial/protozoal" = "#E64B35",
     "Respiratory viral" = "#00A087",
     "Legionella spp." = "#8B6D4F",
     "Vaccine-preventable" = "#F39B7F",
     "Zoonotic" = "#4DBBD5",
     "Unknown aetiology" = "#8D8D8D"
)

field_labels <- c(
     outbreak_year = "Outbreak year",
     transmission_route = "Transmission route",
     public_health_response = "Public health response",
     deaths = "Deaths",
     outbreak_duration_days = "Duration (days)",
     pathogen_identified = "Pathogen identified",
     cases_passengers = "Cases (passengers)",
     cases_crew = "Cases (crew)",
     hospitalisations = "Hospitalisations"
)

df <- read_csv(data_path, show_col_types = FALSE) %>%
     mutate(
          outbreak_year = as.integer(outbreak_year),
          pathogen_label = factor(recode(pathogen_category, !!!cat_map), levels = pathogen_levels)
     )

save_plot <- function(plot, stem, width, height) {
     ggsave(file.path(output_dir, paste0(stem, ".pdf")), plot, width = width, height = height, device = cairo_pdf)
     ggsave(file.path(output_dir, paste0(stem, ".png")), plot, width = width, height = height, dpi = 300)
}

non_missing <- function(x) {
     !is.na(x) & x != "NR" & x != ""
}

# Figure S1: Annual distribution ------------------------------------------

plot_s1 <- ggplot(df, aes(x = outbreak_year, fill = pathogen_label)) +
     annotate("rect", xmin = 2020, xmax = 2022.99, ymin = -Inf, ymax = Inf, fill = "grey90", alpha = 0.6) +
     geom_bar(width = 0.82, position = "stack", colour = "white", linewidth = 0.3) +
     annotate("text", x = 2021.4, y = max(table(df$outbreak_year)) * 0.96,
              label = "COVID-19\nperiod", size = 3.6, fontface = "italic") +
     scale_fill_manual(values = palette, breaks = pathogen_levels, drop = FALSE) +
     scale_x_continuous(breaks = seq(1994, 2026, by = 4), limits = c(1992.5, 2026.5)) +
     scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
     labs(x = "Year", y = "Number of outbreak events", fill = "Pathogen category") +
     theme_bw() +
     theme(
          legend.position = "bottom",
          axis.text.x = element_text(angle = 45, hjust = 1)
     ) +
     guides(fill = guide_legend(ncol = 3, byrow = TRUE, title.position = "top"))

# Figure S2: PRISMA flow --------------------------------------------------

plot_s2 <- ggplot() +
     xlim(0, 10) + ylim(0, 10) +
     theme_void() +
     annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 7.8, ymax = 9.0, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 5.7, ymax = 6.9, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 3.6, ymax = 4.8, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 1.5, ymax = 2.7, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("rect", xmin = 5.3, xmax = 9.1, ymin = 5.7, ymax = 6.9, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
     annotate("rect", xmin = 5.3, xmax = 9.1, ymin = 3.6, ymax = 4.8, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
     annotate("rect", xmin = 5.3, xmax = 9.1, ymin = 1.5, ymax = 2.7, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
     annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 0.3, ymax = 1.3, fill = "#E9F4E5", colour = "#2F8F2F", linewidth = 0.8) +
     annotate("text", x = 3.15, y = 8.35, label = "Records identified\n(n = 357)", size = 4.2) +
     annotate("text", x = 3.15, y = 6.25, label = "After deduplication\n(n = 357)", size = 4.2) +
     annotate("text", x = 3.15, y = 4.15, label = "Records screened\n(n = 357)", size = 4.2) +
     annotate("text", x = 3.15, y = 2.05, label = "Full-text assessed\n(n = 191)", size = 4.2) +
     annotate("text", x = 3.15, y = 0.82, label = "Unique outbreak events captured\n(n = 43)", size = 4.0, fontface = "bold") +
     annotate("text", x = 7.2, y = 6.25, label = "Duplicates removed\n(n = 0)", size = 3.8) +
     annotate("text", x = 7.2, y = 4.15, label = "Excluded at title/abstract\n(n = 166)", size = 3.8) +
     annotate("text", x = 7.2, y = 2.05, label = "Deduplicated against\nVSP/grey sources (n = 148)", size = 3.8) +
     annotate("segment", x = 3.15, xend = 3.15, y = 7.8, yend = 6.9, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
     annotate("segment", x = 3.15, xend = 3.15, y = 5.7, yend = 4.8, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
     annotate("segment", x = 3.15, xend = 3.15, y = 3.6, yend = 2.7, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
     annotate("segment", x = 3.15, xend = 3.15, y = 1.5, yend = 1.3, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
     annotate("segment", x = 5.3, xend = 5.0, y = 6.3, yend = 6.3, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
     annotate("segment", x = 5.3, xend = 5.0, y = 4.2, yend = 4.2, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
     annotate("segment", x = 5.3, xend = 5.0, y = 2.1, yend = 2.1, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1)

# Figure S3: Quality distribution -----------------------------------------

score_df <- df %>%
     mutate(
          score = rowSums(
               across(
                    c(pathogen_identified, cases_passengers, cases_crew, outbreak_duration_days, transmission_route, hospitalisations, public_health_response),
                    ~ non_missing(.x)
               )
          )
     ) %>%
     count(score, name = "n") %>%
     complete(score = 0:7, fill = list(n = 0))

plot_s3 <- ggplot(score_df, aes(x = score, y = n)) +
     geom_col(fill = "#425A8C", width = 0.82, colour = "white", linewidth = 0.3) +
     geom_vline(xintercept = median(rep(score_df$score, score_df$n)), colour = "#E64B35", linetype = "dashed", linewidth = 0.8) +
     annotate(
          "text",
          x = 7.25,
          y = max(score_df$n) * 0.98,
          label = paste0("Median = ", median(rep(score_df$score, score_df$n))),
          colour = "#E64B35",
          fontface = "italic",
          size = 3.6,
          hjust = 1
     ) +
     scale_x_continuous(breaks = 0:7, limits = c(-0.5, 7.6)) +
     scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
     labs(x = "Reporting completeness score (0\u20137)", y = "Number of events") +
     theme_bw() +
     theme(panel.grid.minor = element_blank())

# Figure S4: Field completeness -------------------------------------------

field_counts <- tibble::tibble(
     field = c("Outbreak year", "Transmission route", "Public health response", "Deaths",
               "Duration (days)", "Pathogen identified", "Cases (passengers)", "Cases (crew)",
               "Hospitalisations"),
     pct = c(
          mean(!is.na(df$outbreak_year)) * 100,
          mean(non_missing(df$transmission_route)) * 100,
          mean(non_missing(df$public_health_response)) * 100,
          mean(non_missing(df$deaths)) * 100,
          mean(non_missing(df$outbreak_duration_days)) * 100,
          mean(non_missing(df$pathogen_identified)) * 100,
          mean(non_missing(df$cases_passengers)) * 100,
          mean(non_missing(df$cases_crew)) * 100,
          mean(non_missing(df$hospitalisations)) * 100
     )
)

field_counts$field <- factor(field_counts$field, levels = field_counts$field[order(field_counts$pct, decreasing = TRUE)])

plot_s4 <- ggplot(field_counts, aes(x = pct, y = field)) +
     geom_segment(aes(x = 0, xend = pct, yend = field), colour = "#B3B3B3", linewidth = 0.8) +
     geom_point(aes(colour = pct >= 80), size = 4.5) +
     geom_text(aes(label = sprintf("%.1f%%", pct)), hjust = -0.08, size = 3.4) +
     geom_vline(xintercept = 80, linetype = "dashed", colour = "grey55") +
     scale_colour_manual(values = c(`TRUE` = "#425A8C", `FALSE` = "#E64B35"), guide = "none") +
     scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 20), expand = expansion(mult = c(0, 0.05))) +
     labs(x = "Completeness (%)", y = NULL) +
     theme_bw() +
     theme(
          panel.grid.major.y = element_blank(),
          panel.grid.minor = element_blank()
     )

save_plot(plot_s1, "figure_s1_annual_distribution", 10, 6.8)
save_plot(plot_s2, "figure_s2_prisma_flow", 9.5, 11)
save_plot(plot_s3, "figure_s3_quality_distribution", 10, 6.8)
save_plot(plot_s4, "figure_s4_field_completeness", 10, 6.8)
