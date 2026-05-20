#!/usr/bin/env Rscript

suppressPackageStartupMessages({
     library(dplyr)
     library(ggplot2)
     library(grid)
     library(readr)
     library(scales)
     library(tidyr)
     library(patchwork)
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
     unknown = "Unknown etiology"
)

pathogen_levels <- c(
     "Viral gastroenteritis",
     "GI bacterial/protozoal",
     "Respiratory viral",
     "Legionella spp.",
     "Vaccine-preventable",
     "Zoonotic",
     "Unknown etiology"
)

pathogen_palette <- c(
     "Viral gastroenteritis" = "#0072B2",
     "GI bacterial/protozoal" = "#D55E00",
     "Respiratory viral" = "#009E73",
     "Legionella spp." = "#CC79A7",
     "Vaccine-preventable" = "#E69F00",
     "Zoonotic" = "#56B4E9",
     "Unknown etiology" = "#6B7280"
)

pathogen_label_text <- c(
     "Viral gastroenteritis" = "white",
     "GI bacterial/protozoal" = "white",
     "Respiratory viral" = "white",
     "Legionella spp." = "white",
     "Vaccine-preventable" = "black",
     "Zoonotic" = "black",
     "Unknown etiology" = "white"
)

source_tier_palette <- c(
     "CDC VSP entries" = "#1F77B4",
     "Non-VSP official reports" = "#2A9D8F",
     "Peer-reviewed publications" = "#B56576"
)

source_group_palette <- c(
     "CDC VSP entries" = "#1F77B4",
     "Non-VSP public sources" = "#B56576"
)

completeness_palette <- c(
     "#F8FAFC",
     "#D6EAF2",
     "#7FB8D6",
     "#256EA9",
     "#083B66"
)

field_labels <- c(
     pathogen_identified = "Pathogen identified",
     cases_passengers = "Passenger cases",
     cases_crew = "Crew cases",
     outbreak_duration_days = "Outbreak duration",
     public_health_response = "Response actions",
     deaths = "Deaths",
     hospitalisations = "Hospitalizations"
)

field_heatmap_labels <- c(
     pathogen_identified = "Pathogen/\nsyndrome",
     voyage_route = "Voyage\nroute",
     cases_passengers = "Passenger\ncases",
     cases_crew = "Crew\ncases",
     outbreak_duration_days = "Outbreak\nduration",
     attack_rate_percent = "Attack\nrate",
     public_health_response = "Response\nactions",
     deaths = "Deaths",
     hospitalisations = "Hospitalizations"
)

is_reported <- function(x) {
     !is.na(x) & x != "" & x != "NR"
}

source_group_label <- function(category, reference) {
     ifelse(
          category == "official_public_health" &
               (is.na(reference) | reference == "NR" | startsWith(reference, "CDC VSP")),
          "CDC VSP entries",
          "Non-VSP public sources"
     )
}

source_tier_label <- function(category, reference) {
     case_when(
          category == "official_public_health" &
               (is.na(reference) | reference == "NR" | startsWith(reference, "CDC VSP")) ~ "CDC VSP entries",
          category == "official_public_health" ~ "Non-VSP official reports",
          category == "academic" ~ "Peer-reviewed publications",
          TRUE ~ "Other public sources"
     )
}

theme_eid <- function(base_size = 10) {
     theme_minimal(base_size = base_size, base_family = "sans") +
          theme(
               text = element_text(color = "#1F2933"),
               axis.text = element_text(color = "#1F2933"),
               axis.title = element_text(color = "#1F2933"),
               axis.ticks = element_line(color = "#1F2933", linewidth = 0.3),
               panel.grid.major = element_line(color = "#E5E7EB", linewidth = 0.28),
               panel.grid.minor = element_blank(),
               legend.position = "bottom",
               legend.title = element_text(color = "#1F2933"),
               legend.text = element_text(color = "#1F2933"),
               legend.key.height = unit(0.16, "in"),
               legend.key.width = unit(0.20, "in"),
               legend.margin = margin(t = 2, r = 0, b = 0, l = 0),
               plot.margin = margin(6, 6, 6, 6)
          )
}

save_figure_set <- function(plot, file_stub, width, height) {
     ggsave(
          file.path(output_dir, paste0(file_stub, ".pdf")),
          plot,
          width = width,
          height = height,
          units = "in",
          device = cairo_pdf,
          bg = "white"
     )
     ggsave(
          file.path(output_dir, paste0(file_stub, ".tif")),
          plot,
          width = width,
          height = height,
          units = "in",
          dpi = 300,
          device = "tiff",
          compression = "lzw",
          bg = "white"
     )
     ggsave(
          file.path(output_dir, paste0(file_stub, ".png")),
          plot,
          width = width,
          height = height,
          units = "in",
          dpi = 300,
          bg = "white"
     )
}

df <- read_csv(data_path, show_col_types = FALSE) %>%
     mutate(
          outbreak_year = as.integer(outbreak_year),
          pathogen_label = recode(pathogen_category, !!!cat_map),
          pathogen_label = factor(pathogen_label, levels = pathogen_levels),
          source_group = source_group_label(data_source_category, data_source_reference),
          source_tier = source_tier_label(data_source_category, data_source_reference),
          period = case_when(
               outbreak_year <= 2009 ~ "1993-2009",
               outbreak_year <= 2019 ~ "2010-2019",
               outbreak_year <= 2022 ~ "2020-2022",
               TRUE ~ "2023-2026"
          )
     )

source_levels <- c("CDC VSP entries", "Non-VSP public sources")
source_tier_levels <- c(
     "CDC VSP entries",
     "Non-VSP official reports",
     "Peer-reviewed publications"
)
period_levels <- c("1993-2009", "2010-2019", "2020-2022", "2023-2026")

df <- df %>%
     mutate(
          source_group = factor(source_group, levels = source_levels),
          source_tier = factor(source_tier, levels = source_tier_levels),
          period = factor(period, levels = period_levels)
     )

# Figure 1: public visibility by source -----------------------------------

source_tiers <- df %>%
     count(source_tier, name = "n") %>%
     complete(source_tier = source_tier_levels, fill = list(n = 0)) %>%
     mutate(
          source_tier = factor(source_tier, levels = rev(source_tier_levels)),
          prop = n / sum(n),
          label = paste0(n, " (", percent(prop, accuracy = 0.1), ")"),
          label_x = ifelse(prop > 0.12, prop - 0.012, prop + 0.012),
          label_hjust = ifelse(prop > 0.12, 1, 0),
          label_color = ifelse(prop > 0.12, "white", "#1F2933")
     )

plot_1a <- ggplot(source_tiers, aes(x = prop, y = source_tier)) +
     geom_col(aes(fill = source_tier), width = 0.62, color = "white", linewidth = 0.3) +
     geom_text(
          aes(x = label_x, label = label, hjust = label_hjust, color = label_color),
          size = 3.0
     ) +
     scale_fill_manual(values = source_tier_palette, guide = "none") +
     scale_color_identity() +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 0.96),
          breaks = seq(0, 0.9, 0.3),
          expand = expansion(mult = c(0, 0))
     ) +
     labs(x = "Share of reported events", y = NULL) +
     theme_eid(base_size = 10) +
     theme(
          panel.grid.major.y = element_blank(),
          legend.position = "none"
     )

source_counts <- df %>%
     count(source_group, name = "source_n")

source_legend_labels <- source_counts %>%
     mutate(label = paste0(source_group, " (n=", source_n, ")")) %>%
     select(source_group, label)
source_legend_labels <- setNames(source_legend_labels$label, source_legend_labels$source_group)

source_summary <- df %>%
     count(source_group, pathogen_label, name = "n") %>%
     group_by(source_group) %>%
     mutate(prop = n / sum(n)) %>%
     ungroup() %>%
     complete(
          source_group = source_levels,
          pathogen_label = pathogen_levels,
          fill = list(n = 0, prop = 0)
     ) %>%
     mutate(
          source_group = factor(source_group, levels = source_levels),
          pathogen_label = factor(pathogen_label, levels = rev(pathogen_levels)),
          pct_label = ifelse(prop == 0, "0%", percent(prop, accuracy = 0.1)),
          label_x = case_when(
               prop >= 0.72 ~ prop - 0.018,
               TRUE ~ prop + 0.018
          ),
          label_x = pmin(pmax(label_x, 0.018), 0.785),
          label_hjust = ifelse(prop >= 0.72, 1, 0),
          label_nudge_y = ifelse(source_group == "CDC VSP entries", 0.18, -0.18)
     )

plot_1b <- ggplot(source_summary, aes(x = prop, y = pathogen_label)) +
     geom_line(
          aes(group = pathogen_label),
          color = "#CBD5E1",
          linewidth = 0.4
     ) +
     geom_point(
          aes(shape = source_group, fill = source_group, color = source_group),
          size = 3.1,
          stroke = 0.55
     ) +
     geom_text(
          aes(
               x = label_x,
               label = pct_label,
               hjust = label_hjust,
               group = source_group
          ),
          position = position_nudge(y = source_summary$label_nudge_y),
          size = 2.8,
          color = "#1F2933"
     ) +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 0.82),
          breaks = seq(0, 0.8, 0.2),
          expand = expansion(mult = c(0, 0.02))
     ) +
     scale_shape_manual(
          values = c("CDC VSP entries" = 21, "Non-VSP public sources" = 24),
          labels = source_legend_labels,
          name = NULL
     ) +
     scale_fill_manual(
          values = source_group_palette,
          labels = source_legend_labels,
          name = NULL
     ) +
     scale_color_manual(
          values = source_group_palette,
          labels = source_legend_labels,
          name = NULL
     ) +
     labs(x = "Within-source proportion of events", y = NULL) +
     guides(
          shape = guide_legend(
               override.aes = list(size = 3.2, fill = unname(source_group_palette)),
               nrow = 2,
               byrow = TRUE
          ),
          fill = "none",
          color = "none"
     ) +
     theme_eid(base_size = 10) +
     theme(
          panel.grid.major.y = element_blank(),
          legend.justification = "left"
     )

figure_1 <- plot_1a / plot_1b +
     plot_layout(heights = c(0.82, 1.18)) +
     plot_annotation(tag_levels = "A") &
     theme(plot.tag = element_text(face = "bold", size = 10, color = "#1F2933"))

# Figure 2: temporal visibility ------------------------------------------

annual_counts <- df %>%
     count(outbreak_year, pathogen_label, name = "n") %>%
     complete(
          outbreak_year = min(df$outbreak_year, na.rm = TRUE):max(df$outbreak_year, na.rm = TRUE),
          pathogen_label = pathogen_levels,
          fill = list(n = 0)
     ) %>%
     mutate(pathogen_label = factor(pathogen_label, levels = pathogen_levels))

plot_2a <- ggplot(annual_counts, aes(x = outbreak_year, y = n, fill = pathogen_label)) +
     annotate("rect", xmin = 2020, xmax = 2022.99, ymin = -Inf, ymax = Inf, fill = "#EDF2F7", alpha = 0.85) +
     geom_col(width = 0.82, color = "white", linewidth = 0.15) +
     annotate(
          "text",
          x = 2021.45,
          y = max(tapply(annual_counts$n, annual_counts$outbreak_year, sum), na.rm = TRUE) * 0.96,
          label = "COVID-19\nperiod",
          size = 2.7,
          lineheight = 0.9,
          fontface = "italic",
          color = "#1F2933"
     ) +
     scale_fill_manual(values = pathogen_palette, breaks = pathogen_levels, drop = FALSE) +
     scale_x_continuous(breaks = seq(1994, 2026, by = 4), limits = c(1992.5, 2026.5)) +
     scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
     labs(x = "Year", y = "Reported events", fill = NULL) +
     theme_eid(base_size = 10) +
     theme(
          axis.text.x = element_text(angle = 45, hjust = 1),
          panel.grid.major.x = element_blank(),
          legend.position = "none"
     )

period_counts <- df %>%
     count(period, name = "n")

period_summary <- df %>%
     count(period, pathogen_label, name = "n") %>%
     group_by(period) %>%
     mutate(prop = n / sum(n)) %>%
     ungroup() %>%
     complete(period = period_levels, pathogen_label = pathogen_levels, fill = list(n = 0, prop = 0)) %>%
     mutate(
          period = factor(period, levels = period_levels),
          pathogen_label = factor(pathogen_label, levels = pathogen_levels),
          stack_label_color = unname(pathogen_label_text[as.character(pathogen_label)])
     )

plot_2b <- ggplot(period_summary, aes(x = period, y = prop, fill = pathogen_label)) +
     geom_col(width = 0.68, color = "white", linewidth = 0.25) +
     geom_text(
          aes(label = ifelse(prop >= 0.12, percent(prop, accuracy = 1), ""), color = stack_label_color),
          position = position_stack(vjust = 0.5),
          size = 2.5,
          fontface = "bold"
     ) +
     geom_text(
          data = period_counts,
          aes(x = period, y = 1.045, label = paste0("n=", n)),
          inherit.aes = FALSE,
          size = 2.8,
          fontface = "bold",
          color = "#1F2933"
     ) +
     scale_fill_manual(values = pathogen_palette, breaks = pathogen_levels, drop = FALSE) +
     scale_color_identity() +
     scale_y_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.08))) +
     coord_cartesian(ylim = c(0, 1.08), clip = "off") +
     labs(x = "Period", y = "Within-period proportion", fill = "Pathogen category") +
     theme_eid(base_size = 10) +
     theme(
          legend.position = "bottom",
          panel.grid.major.x = element_blank()
     ) +
     guides(fill = guide_legend(ncol = 2, byrow = TRUE))

figure_2 <- plot_2a / plot_2b +
     plot_layout(heights = c(1.08, 0.92)) +
     plot_annotation(tag_levels = "A") &
     theme(plot.tag = element_text(face = "bold", size = 10, color = "#1F2933"))

# Figure 3: event-record completeness ------------------------------------

field_summary <- tibble(
     field = names(field_labels),
     field_label = unname(field_labels)
) %>%
     mutate(
          total_events = nrow(df),
          reported = vapply(field, function(field_name) sum(is_reported(df[[field_name]])), numeric(1)),
          prop = reported / total_events,
          field_label = factor(field_label, levels = field_label[order(prop)]),
          pct_count_label = paste0(percent(prop, accuracy = 0.1), " (", reported, "/", total_events, ")"),
          label_x = ifelse(prop >= 0.20, prop - 0.02, prop + 0.02),
          label_hjust = ifelse(prop >= 0.20, 1, 0),
          label_color = ifelse(prop >= 0.65, "white", "#1F2933")
     )

plot_3a <- ggplot(field_summary, aes(x = prop, y = field_label)) +
     geom_col(aes(fill = prop), width = 0.62, color = "white", linewidth = 0.3) +
     geom_text(
          aes(x = label_x, label = pct_count_label, hjust = label_hjust, color = label_color),
          size = 2.9
     ) +
     scale_fill_gradientn(colors = completeness_palette, limits = c(0, 1), guide = "none") +
     scale_color_identity() +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 1.07),
          breaks = seq(0, 1, 0.25),
          expand = expansion(mult = c(0, 0))
     ) +
     labs(x = "Events with field reported", y = NULL) +
     theme_eid(base_size = 10) +
     theme(
          panel.grid.major.y = element_blank(),
          legend.position = "none"
     )

field_by_pathogen <- df %>%
     select(pathogen_label, all_of(names(field_heatmap_labels))) %>%
     pivot_longer(
          cols = all_of(names(field_heatmap_labels)),
          names_to = "field",
          values_to = "value"
     ) %>%
     group_by(pathogen_label, field) %>%
     summarise(
          n = n(),
          reported = sum(is_reported(value)),
          prop = reported / n,
          .groups = "drop"
     ) %>%
     mutate(
          field_label = field_heatmap_labels[field],
          pathogen_n = paste0(as.character(pathogen_label), "\n(n=", n, ")"),
          pct_label = case_when(
               prop > 0 & prop < 0.01 ~ "<1%",
               TRUE ~ percent(prop, accuracy = 1)
          ),
          text_color = ifelse(prop >= 0.65, "white", "#1F2933")
     )

pathogen_n_levels <- df %>%
     count(pathogen_label, name = "n") %>%
     mutate(pathogen_n = paste0(as.character(pathogen_label), "\n(n=", n, ")")) %>%
     arrange(match(as.character(pathogen_label), pathogen_levels)) %>%
     pull(pathogen_n)

make_field_heatmap <- function(selected_fields) {
     selected_labels <- field_heatmap_labels[selected_fields]

     field_by_pathogen %>%
          filter(field %in% selected_fields) %>%
          mutate(
               field_label = factor(field_label, levels = unname(selected_labels)),
               pathogen_n = factor(pathogen_n, levels = rev(pathogen_n_levels))
          ) %>%
          ggplot(aes(x = field_label, y = pathogen_n, fill = prop)) +
          geom_tile(color = "white", linewidth = 0.8) +
          geom_text(aes(label = pct_label, color = text_color), size = 2.9) +
          scale_fill_gradientn(
               colors = completeness_palette,
               limits = c(0, 1),
               breaks = seq(0, 1, 0.25),
               labels = percent_format(accuracy = 1),
               name = "Events with\nfield reported"
          ) +
          scale_color_identity() +
          labs(x = NULL, y = NULL) +
          guides(fill = guide_colorbar(
               title.position = "top",
               title.hjust = 0.5,
               barwidth = unit(2.0, "in"),
               barheight = unit(0.12, "in")
          )) +
          theme_eid(base_size = 10) +
          theme(
               panel.background = element_rect(fill = "white", color = NA),
               panel.border = element_rect(fill = NA, color = "#1F2933", linewidth = 0.35),
               panel.grid = element_blank(),
               axis.line = element_blank(),
               axis.ticks = element_blank(),
               axis.text.x = element_text(size = 9.5, lineheight = 0.95),
               axis.text.y = element_text(size = 9.2, lineheight = 0.95),
               legend.justification = "center"
          )
}

plot_3b <- make_field_heatmap(c(
     "pathogen_identified",
     "voyage_route",
     "cases_passengers",
     "cases_crew",
     "outbreak_duration_days"
))

plot_3c <- make_field_heatmap(c(
     "attack_rate_percent",
     "public_health_response",
     "deaths",
     "hospitalisations"
))

figure_3 <- plot_3a / plot_3b / plot_3c +
     plot_layout(heights = c(0.75, 1.05, 1.0)) +
     plot_annotation(tag_levels = "A") &
     theme(plot.tag = element_text(face = "bold", size = 10, color = "#1F2933"))

# Save final multi-panel figures and individual panels --------------------

save_figure_set(figure_1, "Figure_1_public_visibility", width = 6.7, height = 7.9)
save_figure_set(plot_1a, "Figure_1A_source_tiers", width = 5.7, height = 2.2)
save_figure_set(plot_1b, "Figure_1B_source_pathogen_distribution", width = 6.7, height = 4.25)

save_figure_set(figure_2, "Figure_2_temporal_visibility", width = 6.7, height = 7.2)
save_figure_set(plot_2a, "Figure_2A_annual_events", width = 6.7, height = 3.4)
save_figure_set(plot_2b, "Figure_2B_period_distribution", width = 6.7, height = 3.4)

save_figure_set(figure_3, "Figure_3_reporting_completeness", width = 6.7, height = 12.4)
save_figure_set(plot_3a, "Figure_3A_field_completeness_overall", width = 5.7, height = 3.55)
save_figure_set(plot_3b, "Figure_3B_field_completeness_core", width = 6.7, height = 4.45)
save_figure_set(plot_3c, "Figure_3C_field_completeness_outcomes", width = 6.7, height = 4.45)
