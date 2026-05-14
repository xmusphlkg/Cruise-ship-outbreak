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

palette <- c(
  "Viral gastroenteritis" = "#425A8C",
  "GI bacterial/protozoal" = "#E64B35",
  "Respiratory viral" = "#00A087",
  "Legionella spp." = "#8B6D4F",
  "Vaccine-preventable" = "#F39B7F",
  "Zoonotic" = "#4DBBD5",
  "Unknown aetiology" = "#8D8D8D"
)

source_levels <- c(
  "CDC VSP public outbreak logs",
  "Peer-reviewed academic publications",
  "Grey literature/other reports"
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
    pathogen_label = factor(recode(pathogen_category, !!!cat_map), levels = names(palette)),
    source_label = factor(
      case_when(
        data_source_category == "official_public_health" ~ "CDC VSP public outbreak logs",
        data_source_category == "academic" ~ "Peer-reviewed academic publications",
        TRUE ~ "Grey literature/other reports"
      ),
      levels = source_levels
    )
  )

save_plot <- function(plot, stem, width, height) {
  ggsave(file.path(output_dir, paste0(stem, ".pdf")), plot, width = width, height = height, device = cairo_pdf)
  ggsave(file.path(output_dir, paste0(stem, ".png")), plot, width = width, height = height, dpi = 320)
}

non_missing <- function(x) {
  !is.na(x) & x != "NR" & x != ""
}

plot_s1 <- ggplot(df, aes(x = outbreak_year, fill = pathogen_label)) +
  annotate("rect", xmin = 2020, xmax = 2022.99, ymin = -Inf, ymax = Inf, fill = "grey90", alpha = 0.6) +
  geom_bar(width = 0.82, position = "stack") +
  annotate("text", x = 2021.4, y = max(table(df$outbreak_year)) * 0.96, label = "COVID-19\nperiod", size = 4.5, fontface = "italic") +
  scale_fill_manual(values = palette, drop = FALSE) +
  scale_x_continuous(breaks = seq(1994, 2026, by = 4), limits = c(1992.5, 2026.5)) +
  labs(x = "Year", y = "Number of outbreak events", fill = "Pathogen category") +
  theme_minimal(base_size = 16) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

plot_s2 <- ggplot() +
  xlim(0, 10) + ylim(0, 10) +
  theme_void(base_size = 16) +
  annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 7.8, ymax = 9.0, fill = "white", colour = "grey60", linewidth = 0.8) +
  annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 5.7, ymax = 6.9, fill = "white", colour = "grey60", linewidth = 0.8) +
  annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 3.6, ymax = 4.8, fill = "white", colour = "grey60", linewidth = 0.8) +
  annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 1.5, ymax = 2.7, fill = "white", colour = "grey60", linewidth = 0.8) +
  annotate("rect", xmin = 5.3, xmax = 9.1, ymin = 5.7, ymax = 6.9, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
  annotate("rect", xmin = 5.3, xmax = 9.1, ymin = 3.6, ymax = 4.8, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
  annotate("rect", xmin = 5.3, xmax = 9.1, ymin = 1.5, ymax = 2.7, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
  annotate("rect", xmin = 1.0, xmax = 5.3, ymin = 0.3, ymax = 1.3, fill = "#E9F4E5", colour = "#2F8F2F", linewidth = 0.8) +
  annotate("text", x = 3.15, y = 8.35, label = "Records identified\n(n = 364)", size = 5.2) +
  annotate("text", x = 3.15, y = 6.25, label = "After deduplication\n(n = 364)", size = 5.2) +
  annotate("text", x = 3.15, y = 4.15, label = "Records screened\n(n = 364)", size = 5.2) +
  annotate("text", x = 3.15, y = 2.05, label = "Full-text assessed\n(n = 364)", size = 5.2) +
  annotate("text", x = 3.15, y = 0.82, label = "Infectious outbreak events included\n(n = 363)", size = 5.1, fontface = "bold") +
  annotate("text", x = 7.2, y = 6.25, label = "Duplicates removed\n(n = 0)", size = 4.8) +
  annotate("text", x = 7.2, y = 4.15, label = "Excluded at title/abstract\n(n = 0)", size = 4.8) +
  annotate("text", x = 7.2, y = 2.05, label = "Excluded at full-text\n(n = 1)", size = 4.8) +
  annotate("segment", x = 3.15, xend = 3.15, y = 7.8, yend = 6.9, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
  annotate("segment", x = 3.15, xend = 3.15, y = 5.7, yend = 4.8, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
  annotate("segment", x = 3.15, xend = 3.15, y = 3.6, yend = 2.7, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
  annotate("segment", x = 3.15, xend = 3.15, y = 1.5, yend = 1.3, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
  annotate("segment", x = 5.3, xend = 5.0, y = 6.3, yend = 6.3, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
  annotate("segment", x = 5.3, xend = 5.0, y = 4.2, yend = 4.2, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1) +
  annotate("segment", x = 5.3, xend = 5.0, y = 2.1, yend = 2.1, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 1)

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
  geom_col(fill = "#425A8C", width = 0.9) +
  geom_vline(xintercept = median(rep(score_df$score, score_df$n)), colour = "#E64B35", linetype = "dashed", linewidth = 1) +
  annotate(
    "text",
    x = 7.25,
    y = max(score_df$n) * 0.98,
    label = paste0("Median = ", median(rep(score_df$score, score_df$n))),
    colour = "#E64B35",
    fontface = "italic",
    size = 5.5,
    hjust = 1
  ) +
  scale_x_continuous(breaks = 0:7, limits = c(0, 7.6)) +
  labs(x = "Reporting completeness score (0-7)", y = "Number of events") +
  theme_minimal(base_size = 16) +
  theme(panel.grid.minor = element_blank())

source_summary <- df %>%
  count(source_label, pathogen_label, name = "n") %>%
  group_by(source_label) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  complete(source_label, pathogen_label, fill = list(n = 0, prop = 0))

plot_s4 <- ggplot(source_summary, aes(x = source_label, y = pathogen_label, fill = prop * 100)) +
  geom_tile(colour = "white", linewidth = 0.7) +
  geom_text(aes(label = ifelse(n == 0, "—", sprintf("%.1f%%\n(%d)", prop * 100, n))), size = 4.7) +
  scale_fill_gradient(low = "#FFF7A7", high = "#C40024", limits = c(0, 80), name = "Proportion (%)") +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = 16) +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_text(size = 15),
    axis.text.y = element_text(size = 15),
    legend.position = "right"
  )

field_counts <- tibble::tibble(
  field = c("Outbreak year", "Transmission route", "Public health response", "Deaths", "Duration (days)", "Pathogen identified", "Cases (passengers)", "Cases (crew)", "Hospitalisations"),
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

plot_s5 <- ggplot(field_counts, aes(x = pct, y = field)) +
  geom_segment(aes(x = 0, xend = pct, yend = field), colour = "#B3B3B3", linewidth = 1.1) +
  geom_point(aes(colour = pct >= 80), size = 5.5) +
  geom_text(aes(label = sprintf("%.1f%%", pct)), hjust = -0.08, size = 4.2) +
  geom_vline(xintercept = 80, linetype = "dashed", colour = "grey55") +
  scale_colour_manual(values = c(`TRUE` = "#425A8C", `FALSE` = "#E64B35"), guide = "none") +
  scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 20), expand = expansion(mult = c(0, 0.05))) +
  labs(x = "Completeness (%)", y = NULL) +
  theme_minimal(base_size = 16) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 16)
  )

save_plot(plot_s1, "figure_s1_annual_distribution", 13.5, 7.5)
save_plot(plot_s2, "figure_s2_prisma_flow", 9.5, 11)
save_plot(plot_s3, "figure_s3_quality_distribution", 11.5, 7.5)
save_plot(plot_s4, "figure_s4_source_bias_heatmap", 13, 8.2)
save_plot(plot_s5, "figure_s5_field_completeness", 11.5, 7.5)
