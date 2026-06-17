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
figure_1_stub <- Sys.getenv("FIGURE_1_STUB", unset = "Figure_1_public_visibility")
figure_dpi <- as.integer(Sys.getenv("FIGURE_DPI", unset = "300"))
save_panels <- tolower(Sys.getenv("SAVE_PANELS", unset = "true")) %in% c("true", "1", "yes")

ink <- "#111827"
panel_rule <- "#2F3437"
grid_rule <- "#DDE3EA"

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
     "Viral gastroenteritis" = "#0072B2",
     "Unknown aetiology" = "#6B7280",
     "GI bacterial/protozoal" = "#E69F00",
     "Respiratory viral" = "#009E73",
     "Vaccine-preventable" = "#D55E00",
     "Legionella spp." = "#7B3294",
     "Zoonotic" = "#B2182B"
)

source_levels <- c("CDC VSP entries", "Non-VSP public sources")

source_palette <- c(
     "CDC VSP entries" = "#0072B2",
     "Non-VSP public sources" = "#D55E00"
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

theme_letter <- function(base_size = 8.2) {
     theme_bw(base_size = base_size, base_family = "sans") +
          theme(
               text = element_text(color = ink, lineheight = 0.92),
               axis.text = element_text(color = ink, size = rel(0.88)),
               axis.title = element_text(color = ink, size = rel(0.92)),
               axis.title.x = element_text(margin = margin(t = 4)),
               axis.title.y = element_text(margin = margin(r = 4)),
               axis.ticks = element_line(color = ink, linewidth = 0.25),
               axis.ticks.length = unit(1.5, "pt"),
               panel.background = element_rect(fill = "white", color = NA),
               panel.border = element_rect(color = panel_rule, fill = NA, linewidth = 0.32),
               panel.grid.major = element_blank(),
               panel.grid.minor = element_blank(),
               plot.title = element_text(face = "bold", size = rel(0.98), hjust = 0.5, margin = margin(b = 5)),
               plot.title.position = "panel",
               plot.margin = margin(4.5, 4.5, 4.5, 4.5),
               legend.title = element_blank(),
               legend.background = element_blank(),
               legend.key = element_blank(),
               legend.box.spacing = unit(1, "pt"),
               legend.spacing.x = unit(3, "pt"),
               legend.key.height = unit(0.11, "in"),
               legend.key.width = unit(0.16, "in"),
               strip.background = element_rect(fill = "#F3F4F6", color = panel_rule, linewidth = 0.28),
               strip.text = element_text(face = "bold", color = ink, size = rel(0.76), margin = margin(2, 2, 2, 2))
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
          label = paste0(n, " events (", percent(prop, accuracy = 0.1), ")"),
          label_x = ifelse(prop >= 0.75, prop - 0.025, prop + 0.035),
          label_hjust = ifelse(prop >= 0.75, 1, 0)
     )

source_tier_palette <- c(
     "CDC VSP entries" = "#0072B2",
     "Peer-reviewed publications" = "#7B3294",
     "Non-VSP official reports" = "#D55E00"
)

plot_a <- ggplot(source_tiers, aes(x = prop, y = source_tier)) +
     geom_segment(
          aes(x = 0, xend = prop, yend = source_tier),
          color = "#CBD5E1",
          linewidth = 1.05,
          lineend = "round"
     ) +
     geom_point(aes(fill = source_tier), shape = 21, size = 4.2, color = "white", stroke = 0.45) +
     geom_text(
          aes(x = label_x, label = label, hjust = label_hjust),
          size = 2.5,
          color = ink
     ) +
     scale_fill_manual(values = source_tier_palette, guide = "none") +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 1.08),
          breaks = seq(0, 1, 0.25),
          expand = expansion(mult = c(0, 0))
     ) +
     labs(x = "Share of public event records", y = NULL) +
     theme_letter() +
     theme(
          axis.text.y = element_text(size = 7.7),
          panel.grid.major.x = element_line(color = grid_rule, linewidth = 0.24)
     )

# Panel B: pathogen spectrum by source ------------------------------------

source_counts <- df %>%
     count(source_group, name = "source_n")

source_labels <- source_counts %>%
     mutate(label = ifelse(
          source_group == "CDC VSP entries",
          paste0("VSP\nn=", source_n),
          paste0("Non-VSP\nn=", source_n)
     )) %>%
     select(source_group, label)
source_labels <- setNames(source_labels$label, source_labels$source_group)
source_display_levels <- unname(source_labels[source_levels])

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
          source_display = factor(source_labels[as.character(source_group)], levels = source_display_levels),
          cell_label = ifelse(n == 0, "0", paste0(percent(prop, accuracy = 0.1), "\n", n)),
          label_color = ifelse(prop >= 0.45, "white", ink)
     )

plot_b <- ggplot(source_summary, aes(x = source_display, y = pathogen_label, fill = prop)) +
     geom_tile(color = "white", linewidth = 0.55) +
     geom_text(aes(label = cell_label, color = label_color), size = 2.35, lineheight = 0.86) +
     scale_fill_gradientn(
          colors = c("#F8FAFC", "#A9CBE3", "#0072B2"),
          limits = c(0, 0.8),
          oob = squish,
          labels = percent_format(accuracy = 1),
          guide = "none"
     ) +
     scale_color_identity() +
     scale_x_discrete(position = "top") +
     labs(x = NULL, y = NULL) +
     theme_letter() +
     theme(
          axis.text.x = element_text(size = 7.4, face = "bold", lineheight = 0.92, margin = margin(b = 3)),
          axis.text.y = element_text(size = 7.2),
          axis.ticks = element_blank(),
          panel.grid = element_blank()
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
          stack_label = ifelse(prop >= 0.13, percent(prop, accuracy = 1), "")
     )

plot_c <- ggplot(period_summary, aes(x = period, y = prop, fill = pathogen_label)) +
     geom_col(width = 0.66, color = "white", linewidth = 0.28) +
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
          color = ink
     ) +
     scale_fill_manual(values = pathogen_palette, breaks = pathogen_levels, drop = FALSE) +
     scale_x_discrete(labels = c(
          "1993-2009" = "1993-\n2009",
          "2010-2019" = "2010-\n2019",
          "2020-2022" = "2020-\n2022",
          "2023-2026" = "2023-\n2026"
     )) +
     scale_y_continuous(
          labels = percent_format(accuracy = 1),
          breaks = seq(0, 1, 0.25),
          expand = expansion(mult = c(0, 0.08))
     ) +
     coord_cartesian(ylim = c(0, 1.08), clip = "off") +
     labs(x = NULL, y = "Within-period proportion") +
     guides(fill = guide_legend(ncol = 2, byrow = TRUE)) +
     theme_letter() +
     theme(
          panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(color = grid_rule, linewidth = 0.22),
          axis.text.x = element_text(size = 7.0, lineheight = 0.9),
          legend.position = "bottom",
          legend.text = element_text(size = 6.5),
          legend.key.width = unit(0.14, "in")
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
          label_x = ifelse(prop >= 0.35, pmax(prop - 0.025, 0.12), prop + 0.025),
          label_hjust = ifelse(prop >= 0.35, 1, 0),
          label_color = ifelse(prop >= 0.35, "white", ink),
          status = case_when(
               prop < 0.25 ~ "Sparse",
               prop < 0.75 ~ "Partial",
               TRUE ~ "Broad"
          )
     )

field_palette <- c(
     "Sparse" = "#B2182B",
     "Partial" = "#E69F00",
     "Broad" = "#0072B2"
)

plot_d <- ggplot(field_summary, aes(x = prop, y = field_label)) +
     geom_col(aes(fill = status), width = 0.58, color = "white", linewidth = 0.25) +
     geom_text(
          aes(x = label_x, label = label, hjust = label_hjust, color = label_color),
          size = 2.35,
          lineheight = 0.9
     ) +
     scale_fill_manual(values = field_palette, guide = "none") +
     scale_color_identity() +
     scale_x_continuous(
          labels = percent_format(accuracy = 1),
          limits = c(0, 1.04),
          breaks = seq(0, 1, 0.25),
          expand = expansion(mult = c(0, 0))
     ) +
     labs(x = "Events with field visible\nin public record", y = NULL) +
     theme_letter() +
     theme(
          axis.text.y = element_text(size = 7.5),
          panel.grid.major.x = element_line(color = grid_rule, linewidth = 0.24)
     )

figure <- ((plot_a | plot_b) / (free(plot_c, side = "l") | plot_d)) +
     plot_layout(widths = c(0.95, 1.15), heights = c(0.82, 1.18)) +
     plot_annotation(tag_levels = "A") &
     theme(
          plot.tag = element_text(face = "bold", size = 9.6, color = ink, margin = margin(r = 3, b = 2))
     )

save_figure_set(figure, figure_1_stub, width = 7.6, height = 8.8)
if (save_panels) {
     save_figure_set(plot_a, "Figure_1A_source_architecture", width = 3.55, height = 2.9)
     save_figure_set(plot_b, "Figure_1B_pathogen_by_source", width = 4.35, height = 3.65)
     save_figure_set(plot_c, "Figure_1C_temporal_composition", width = 3.75, height = 4.4)
     save_figure_set(plot_d, "Figure_1D_field_visibility", width = 4.05, height = 4.4)
}
