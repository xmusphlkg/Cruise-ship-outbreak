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
# This diagram shows the complete event identification flow from all sources,
# converging to the final 479-event dataset.

plot_s2 <- ggplot() +
     xlim(0, 12) + ylim(0, 14) +
     theme_void() +

     # ---- IDENTIFICATION (top row: two source streams) ----
     # Left stream: CDC VSP entries + non-VSP official public-health reports
     annotate("rect", xmin = 0.5, xmax = 4.5, ymin = 12.2, ymax = 13.5, fill = "#E8F0FE", colour = "#3366CC", linewidth = 0.8) +
     annotate("text", x = 2.5, y = 12.85, label = "CDC VSP entries +\nnon-VSP official\npublic-health reports\n(n = 436 events)", size = 3.3, lineheight = 0.9) +

     # Right stream: Academic databases + other sources
     annotate("rect", xmin = 5.5, xmax = 11.5, ymin = 12.2, ymax = 13.5, fill = "#E8F0FE", colour = "#3366CC", linewidth = 0.8) +
     annotate("text", x = 8.5, y = 12.85, label = "PubMed, WHO DON,\nECDC reports, grey literature\n(n = 357 records from PubMed)", size = 3.6, lineheight = 0.9) +

     # Section label: Identification
     annotate("text", x = 0.15, y = 12.85, label = "I\nD\nE\nN\nT\nI\nF\nI\nC\nA\nT\nI\nO\nN", size = 2.2, fontface = "bold", colour = "grey50", hjust = 0, lineheight = 0.6) +

     # ---- SCREENING (right stream only) ----
     # Screening box
     annotate("rect", xmin = 5.5, xmax = 11.5, ymin = 10.0, ymax = 11.3, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("text", x = 8.5, y = 10.65, label = "Title/abstract screening\n(n = 357)", size = 3.8, lineheight = 0.9) +

     # Excluded at screening
     annotate("rect", xmin = 5.5, xmax = 11.5, ymin = 8.5, ymax = 9.5, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
     annotate("text", x = 8.5, y = 9.0, label = "Excluded at title/abstract (n = 166)\nE1 Review/meta-analysis (16)  E2 Modelling (23)\nE3 Methodology (11)  E4 Editorial (16)\nE5 Non-cruise vessel (3)  E6 No outbreak (35)\nE7 Single case (8)  E8 Non-infectious (15)\nE9 Not relevant (39)", size = 2.8, lineheight = 0.85) +

     # Section label: Screening
     annotate("text", x = 0.15, y = 10.65, label = "S\nC\nR\nE\nE\nN\nI\nN\nG", size = 2.2, fontface = "bold", colour = "grey50", hjust = 0, lineheight = 0.6) +

     # ---- ELIGIBILITY ----
     # Full-text assessed
     annotate("rect", xmin = 5.5, xmax = 11.5, ymin = 6.8, ymax = 8.0, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("text", x = 8.5, y = 7.4, label = "Full-text articles assessed for eligibility\n(n = 191)", size = 3.8, lineheight = 0.9) +

     # Excluded at full-text / deduplicated
     annotate("rect", xmin = 5.5, xmax = 11.5, ymin = 5.3, ymax = 6.3, fill = "#FDF3E6", colour = "#F97306", linewidth = 0.8) +
     annotate("text", x = 8.5, y = 5.8, label = "Deduplicated against CDC VSP\nand other sources (n = 148)", size = 3.4, lineheight = 0.9) +

     # Section label: Eligibility
     annotate("text", x = 0.15, y = 7.4, label = "E\nL\nI\nG\nI\nB\nI\nL\nI\nT\nY", size = 2.2, fontface = "bold", colour = "grey50", hjust = 0, lineheight = 0.6) +

     # ---- Academic events result ----
     annotate("rect", xmin = 5.5, xmax = 11.5, ymin = 3.8, ymax = 4.8, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("text", x = 8.5, y = 4.3, label = "Unique events identified from peer-reviewed\nacademic publications\n(n = 43)", size = 3.4, lineheight = 0.9) +

     # ---- CDC VSP arrow down ----
     annotate("rect", xmin = 0.5, xmax = 4.5, ymin = 3.8, ymax = 4.8, fill = "white", colour = "grey60", linewidth = 0.8) +
     annotate("text", x = 2.5, y = 4.3, label = "CDC VSP entries +\nnon-VSP official reports after\nquality review (n = 436)", size = 3.5, lineheight = 0.9) +

     # ---- INCLUSION (final merged dataset) ----
     annotate("rect", xmin = 1.5, xmax = 10.5, ymin = 1.8, ymax = 3.2, fill = "#E9F4E5", colour = "#2F8F2F", linewidth = 1.0) +
     annotate("text", x = 6.0, y = 2.5, label = "Final reported-event dataset\n(N = 479 outbreak events)", size = 4.5, fontface = "bold", lineheight = 0.9) +

     # Section label: Inclusion
     annotate("text", x = 0.15, y = 2.5, label = "I\nN\nC\nL\nU\nD\nE\nD", size = 2.2, fontface = "bold", colour = "grey50", hjust = 0, lineheight = 0.6) +

     # ---- Breakdown annotation ----
     annotate("rect", xmin = 1.5, xmax = 10.5, ymin = 0.5, ymax = 1.5, fill = "grey97", colour = "grey70", linewidth = 0.5, linetype = "dashed") +
     annotate("text", x = 6.0, y = 1.0, label = "CDC VSP entries + non-VSP official reports: 436 (91.0%)\nEvents identified from peer-reviewed academic publications: 43 (9.0%)", size = 3.05, lineheight = 0.95) +

     # ---- ARROWS ----
     # CDC VSP entries + non-VSP official public-health reports: top box down to quality review
     annotate("segment", x = 2.5, xend = 2.5, y = 12.2, yend = 4.8, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 0.8) +

     # Academic: top box down to screening
     annotate("segment", x = 8.5, xend = 8.5, y = 12.2, yend = 11.3, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 0.8) +

     # Screening to full-text
     annotate("segment", x = 8.5, xend = 8.5, y = 10.0, yend = 8.0, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 0.8) +

     # Full-text to academic events
     annotate("segment", x = 8.5, xend = 8.5, y = 6.8, yend = 4.8, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 0.8) +

     # Exclusion arrows (horizontal from main flow to exclusion boxes)
     annotate("segment", x = 8.5, xend = 8.5, y = 10.0, yend = 9.5, colour = "#F97306", linewidth = 0.6, linetype = "solid") +
     annotate("segment", x = 8.5, xend = 8.5, y = 6.8, yend = 6.3, colour = "#F97306", linewidth = 0.6, linetype = "solid") +

     # CDC VSP entries + non-VSP official public-health reports to final
     annotate("segment", x = 2.5, xend = 2.5, y = 3.8, yend = 3.2, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 0.8) +

     # Academic to final
     annotate("segment", x = 8.5, xend = 8.5, y = 3.8, yend = 3.2, arrow = arrow(length = unit(0.12, "inches")), colour = "grey40", linewidth = 0.8) +

     # Final to breakdown
     annotate("segment", x = 6.0, xend = 6.0, y = 1.8, yend = 1.5, arrow = arrow(length = unit(0.08, "inches")), colour = "grey40", linewidth = 0.6)

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
