#!/usr/bin/env Rscript

suppressPackageStartupMessages({
     library(dplyr)
     library(ggplot2)
     library(grid)
     library(patchwork)
     library(readr)
     library(scales)
     library(tidyr)
})

repo_root <- normalizePath(".", mustWork = TRUE)
data_path <- file.path(repo_root, "output", "table_s_full_dataset.csv")
output_dir <- Sys.getenv("FIGURE_OUTPUT_DIR", unset = file.path(repo_root, "output"))
figure_1_stub <- Sys.getenv("FIGURE_1_STUB", unset = "Figure_1_journal_of_infection_letter")
figure_dpi <- as.integer(Sys.getenv("FIGURE_DPI", unset = "300"))
save_panels <- tolower(Sys.getenv("SAVE_PANELS", unset = "true")) %in% c("true", "1", "yes")

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
     "Unknown aetiology",
     "GI bacterial/protozoal",
     "Respiratory viral",
     "Vaccine-preventable",
     "Legionella spp.",
     "Zoonotic"
)

pathogen_palette <- c(
     "Viral gastroenteritis" = "#256EA9",
     "Unknown aetiology" = "#6B7280",
     "GI bacterial/protozoal" = "#C9892B",
     "Respiratory viral" = "#2A9D8F",
     "Vaccine-preventable" = "#B85C38",
     "Legionella spp." = "#7C5C9E",
     "Zoonotic" = "#B84A4A"
)

source_levels <- c("CDC VSP entries", "Non-VSP public sources")

source_palette <- c(
     "CDC VSP entries" = "#256EA9",
     "Non-VSP public sources" = "#B85C38"
)

source_tier_levels <- c(
     "CDC VSP entries",
     "Peer-reviewed publications",
     "Non-VSP official reports"
)

field_labels <- c(
     public_health_response = "Response actions",
     pathogen_identified = "Pathogen/syndrome",
     outbreak_duration_days = "Outbreak duration",
     deaths = "Deaths",
     cases_passengers = "Passenger cases",
     cases_crew = "Crew cases",
     attack_rate_percent = "Attack rate",
     hospitalisations = "Hospitalisations"
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

theme_letter <- function(base_size = 8.8) {
     theme_minimal(base_size = base_size, base_family = "sans") +
          theme(
               text = element_text(color = "#1F2933"),
               axis.text = element_text(color = "#1F2933"),
               axis.title = element_text(color = "#1F2933"),
               axis.title.x = element_text(margin = margin(t = 4)),
               panel.grid.major.y = element_blank(),
               panel.grid.minor = element_blank(),
               panel.grid.major.x = element_line(color = "#E5E7EB", linewidth = 0.26),
               plot.title = element_text(face = "bold", size = rel(1.0), margin = margin(b = 4)),
               plot.margin = margin(5, 5, 5, 5),
               legend.title = element_blank(),
               legend.key.height = unit(0.13, "in"),
               legend.key.width = unit(0.20, "in")
          )
}

save_figure_set <- function(plot, file_stub, width, height) {
     dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
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
          dpi = figure_dpi,
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
          dpi = figure_dpi,
          bg = "white"
     )
}

df <- read_csv(data_path, show_col_types = FALSE) %>%
     mutate(
          outbreak_year = as.integer(outbreak_year),
          pathogen_label = recode(pathogen_category, !!!cat_map),
          pathogen_label = factor(pathogen_label, levels = pathogen_levels),
          source_group = source_group_label(data_source_category, data_source_reference),
          source_group = factor(source_group, levels = source_levels),
          source_tier = source_tier_label(data_source_category, data_source_reference),
          source_tier = factor(source_tier, levels = source_tier_levels),
          period = case_when(
               outbreak_year <= 2009 ~ "1993-2009",
               outbreak_year <= 2019 ~ "2010-2019",
               outbreak_year <= 2022 ~ "2020-2022",
               TRUE ~ "2023-2026"
          )
     )

period_levels <- c("1993-2009", "2010-2019", "2020-2022", "2023-2026")

# Panel A: public source architecture -------------------------------------

source_tiers <- df %>%
     count(source_tier, name = "n") %>%
     complete(source_tier = source_tier_levels, fill = list(n = 0)) %>%
     mutate(
          prop = n / sum(n),
          source_tier = factor(source_tier, levels = rev(source_tier_levels)),
          label = paste0(n, " (", percent(prop, accuracy = 0.1), ")"),
          label_x = ifelse(prop >= 0.18, prop - 0.018, prop + 0.018),
          label_hjust = ifelse(prop >= 0.18, 1, 0),
          label_color = ifelse(prop >= 0.18, "white", "#1F2933")
     )

source_tier_palette <- c(
     "CDC VSP entries" = "#256EA9",
     "Peer-reviewed publications" = "#7C5C9E",
     "Non-VSP official reports" = "#B85C38"
)

plot_a <- ggplot(source_tiers, aes(x = prop, y = source_tier)) +
     geom_col(aes(fill = source_tier), width = 0.62, color = "white", linewidth = 0.3) +
     geom_text(
          aes(x = label_x, label = label, hjust = label_hjust, color = label_color),
          size = 2.65
     ) +
     scale_fill_manual(values = source_tier_palette, guide = "none") +
     scale_color_identity() +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 1.02),
          breaks = seq(0, 1, 0.25),
          expand = expansion(mult = c(0, 0))
     ) +
     labs(title = "Source architecture", x = "Share of public event records", y = NULL) +
     theme_letter() +
     theme(axis.text.y = element_text(size = 8.4))

# Panel B: pathogen spectrum by source ------------------------------------

source_counts <- df %>%
     count(source_group, name = "source_n")

legend_labels <- source_counts %>%
     mutate(label = ifelse(
          source_group == "CDC VSP entries",
          paste0("VSP (n=", source_n, ")"),
          paste0("Non-VSP (n=", source_n, ")")
     )) %>%
     select(source_group, label)
legend_labels <- setNames(legend_labels$label, legend_labels$source_group)

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
          point_label = case_when(
               n == 0 ~ "0",
               prop < 0.05 ~ paste0(percent(prop, accuracy = 0.1), " (", n, ")"),
               TRUE ~ paste0(percent(prop, accuracy = 0.1), "\n(", n, ")")
          ),
          label_x = pmin(prop + 0.025, 0.86)
     )

source_lines <- source_summary %>%
     select(source_group, pathogen_label, prop) %>%
     pivot_wider(names_from = source_group, values_from = prop)

plot_b <- ggplot(source_summary, aes(x = prop, y = pathogen_label)) +
     geom_segment(
          data = source_lines,
          aes(
               x = `CDC VSP entries`,
               xend = `Non-VSP public sources`,
               y = pathogen_label,
               yend = pathogen_label
          ),
          inherit.aes = FALSE,
          color = "#CBD5E1",
          linewidth = 0.50
     ) +
     geom_point(
          aes(shape = source_group, fill = source_group, color = source_group),
          size = 2.7,
          stroke = 0.55
     ) +
     geom_text(
          data = source_summary %>% filter(source_group == "CDC VSP entries"),
          aes(x = label_x, label = point_label, color = source_group),
          hjust = 0,
          size = 2.15,
          lineheight = 0.86,
          position = position_nudge(y = 0.16),
          show.legend = FALSE
     ) +
     geom_text(
          data = source_summary %>% filter(source_group == "Non-VSP public sources"),
          aes(x = label_x, label = point_label, color = source_group),
          hjust = 0,
          size = 2.15,
          lineheight = 0.86,
          position = position_nudge(y = -0.16),
          show.legend = FALSE
     ) +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 0.90),
          breaks = seq(0, 0.8, 0.2),
          expand = expansion(mult = c(0, 0))
     ) +
     scale_shape_manual(values = c("CDC VSP entries" = 21, "Non-VSP public sources" = 24), labels = legend_labels) +
     scale_fill_manual(values = source_palette, labels = legend_labels) +
     scale_color_manual(values = source_palette, labels = legend_labels) +
     labs(title = "Pathogen spectrum by source", x = "Within-source proportion", y = NULL) +
     guides(
          shape = guide_legend(
               override.aes = list(size = 2.8, fill = unname(source_palette)),
               nrow = 1,
               byrow = TRUE
          ),
          fill = "none",
          color = "none"
     ) +
     theme_letter() +
     theme(
          legend.position = "bottom",
          legend.text = element_text(size = 7.2),
          axis.text.y = element_text(size = 8.0)
     )

# Panel C: temporal composition -------------------------------------------

period_counts <- df %>%
     mutate(period = factor(period, levels = period_levels)) %>%
     count(period, name = "n")

period_summary <- df %>%
     mutate(period = factor(period, levels = period_levels)) %>%
     count(period, pathogen_label, name = "n") %>%
     group_by(period) %>%
     mutate(prop = n / sum(n)) %>%
     ungroup() %>%
     complete(period = period_levels, pathogen_label = pathogen_levels, fill = list(n = 0, prop = 0)) %>%
     mutate(
          period = factor(period, levels = period_levels),
          pathogen_label = factor(pathogen_label, levels = pathogen_levels),
          stack_label = ifelse(prop >= 0.14, percent(prop, accuracy = 1), "")
     )

plot_c <- ggplot(period_summary, aes(x = period, y = prop, fill = pathogen_label)) +
     geom_col(width = 0.68, color = "white", linewidth = 0.25) +
     geom_text(
          aes(label = stack_label),
          position = position_stack(vjust = 0.5),
          size = 2.25,
          color = "white",
          fontface = "bold"
     ) +
     geom_text(
          data = period_counts,
          aes(x = period, y = 1.045, label = paste0("n=", n)),
          inherit.aes = FALSE,
          size = 2.55,
          fontface = "bold",
          color = "#1F2933"
     ) +
     scale_fill_manual(values = pathogen_palette, breaks = pathogen_levels, drop = FALSE) +
     scale_x_discrete(labels = c(
          "1993-2009" = "1993-\n2009",
          "2010-2019" = "2010-\n2019",
          "2020-2022" = "2020-\n2022",
          "2023-2026" = "2023-\n2026"
     )) +
     scale_y_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.08))) +
     coord_cartesian(ylim = c(0, 1.08), clip = "off") +
     labs(title = "Temporal composition", x = NULL, y = "Within-period proportion") +
     guides(fill = guide_legend(ncol = 2, byrow = TRUE)) +
     theme_letter() +
     theme(
          panel.grid.major.x = element_blank(),
          axis.text.x = element_text(size = 7.1, lineheight = 0.9),
          legend.position = "bottom",
          legend.text = element_text(size = 7.0)
     )

# Panel D: event-field visibility -----------------------------------------

field_summary <- tibble(
     field = names(field_labels),
     field_label = unname(field_labels)
) %>%
     mutate(
          total_events = nrow(df),
          reported = vapply(field, function(field_name) sum(is_reported(df[[field_name]])), numeric(1)),
          prop = reported / total_events,
          field_label = factor(field_label, levels = field_label[order(prop)]),
          label = paste0(percent(prop, accuracy = 0.1), " (", reported, "/", total_events, ")"),
          label_x = ifelse(prop >= 0.55, pmax(prop - 0.025, 0.12), prop + 0.025),
          label_hjust = ifelse(prop >= 0.55, 1, 0),
          status = case_when(
               prop < 0.25 ~ "Sparse",
               prop < 0.75 ~ "Partial",
               TRUE ~ "Broad"
          )
     )

field_palette <- c(
     "Sparse" = "#B84A4A",
     "Partial" = "#C9892B",
     "Broad" = "#256EA9"
)

plot_d <- ggplot(field_summary, aes(x = prop, y = field_label)) +
     geom_segment(aes(x = 0, xend = prop, yend = field_label), color = "#CBD5E1", linewidth = 0.80) +
     geom_point(aes(fill = status), shape = 21, size = 3.2, color = "white", stroke = 0.45) +
     geom_text(
          aes(x = label_x, label = label, hjust = label_hjust),
          size = 2.35,
          color = "#1F2933"
     ) +
     scale_fill_manual(values = field_palette, guide = "none") +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 1.04),
          breaks = seq(0, 1, 0.25),
          expand = expansion(mult = c(0, 0))
     ) +
     labs(title = "Minimum dataset gaps", x = "Events with field visible\nin public record", y = NULL) +
     theme_letter() +
     theme(axis.text.y = element_text(size = 8.2))

figure <- ((plot_a | plot_b) / (plot_c | plot_d)) +
     plot_layout(widths = c(0.95, 1.15), heights = c(0.82, 1.18)) +
     plot_annotation(tag_levels = "A") &
     theme(plot.tag = element_text(face = "bold", size = 10, color = "#1F2933"))

save_figure_set(figure, figure_1_stub, width = 7.6, height = 8.8)
if (save_panels) {
     save_figure_set(plot_a, "Figure_1A_journal_of_infection_source_architecture", width = 3.55, height = 2.9)
     save_figure_set(plot_b, "Figure_1B_journal_of_infection_pathogen_by_source", width = 4.35, height = 3.65)
     save_figure_set(plot_c, "Figure_1C_journal_of_infection_temporal_composition", width = 3.75, height = 4.4)
     save_figure_set(plot_d, "Figure_1D_journal_of_infection_minimum_dataset_gaps", width = 4.05, height = 4.4)
}
