#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(scales)
  library(patchwork)
})

repo_root <- normalizePath(".", mustWork = TRUE)
data_path <- file.path(repo_root, "data", "outbreak_events.csv")
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

df <- read_csv(data_path, show_col_types = FALSE) %>%
  mutate(
    outbreak_year = as.integer(outbreak_year),
    pathogen_label = recode(pathogen_category, !!!cat_map),
    period = case_when(
      outbreak_year <= 2019 ~ "1993-2019",
      outbreak_year <= 2022 ~ "2020-2022",
      TRUE ~ "2023-2026"
    )
  )

period_levels <- c("1993-2019", "2020-2022", "2023-2026")
df$period <- factor(df$period, levels = period_levels)
df$pathogen_label <- factor(df$pathogen_label, levels = names(palette))

period_summary <- df %>%
  count(period, pathogen_label, name = "n") %>%
  group_by(period) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

plot_a <- ggplot(period_summary, aes(x = period, y = prop, fill = pathogen_label)) +
  geom_col(width = 0.68, colour = "white", linewidth = 0.3) +
  geom_text(
    data = period_summary %>% filter(prop >= 0.08),
    aes(label = percent(prop, accuracy = 1)),
    colour = "white",
    size = 4,
    fontface = "bold",
    position = position_stack(vjust = 0.5)
  ) +
  scale_y_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.03))) +
  scale_fill_manual(values = palette) +
  labs(x = NULL, y = "Proportion of outbreak events", fill = NULL) +
  theme_minimal(base_size = 15) +
  theme(
    axis.text.x = element_text(face = "bold", size = 16),
    axis.title.y = element_text(size = 17),
    legend.position = "bottom",
    panel.grid.major.x = element_blank(),
    plot.margin = margin(5, 5, 5, 5)
  )

source_summary <- df %>%
  filter(data_source_category %in% c("official_public_health", "academic")) %>%
  count(data_source_category, pathogen_label, name = "n") %>%
  group_by(data_source_category) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup()

wide <- source_summary %>%
  select(data_source_category, pathogen_label, prop) %>%
  tidyr::pivot_wider(names_from = data_source_category, values_from = prop, values_fill = 0)

diff_df <- wide %>%
  mutate(
    diff = official_public_health - academic,
    direction = ifelse(diff >= 0, "Over-represented\nin official sources", "Under-represented\nin official sources")
  ) %>%
  select(pathogen_label, diff, direction) %>%
  mutate(pathogen_label_rev = factor(pathogen_label, levels = rev(levels(pathogen_label))))

plot_b <- ggplot(diff_df, aes(y = pathogen_label_rev, x = diff * 100, colour = direction)) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.8) +
  geom_segment(aes(x = 0, xend = diff * 100, yend = pathogen_label_rev), linewidth = 1.1) +
  geom_point(size = 5) +
  scale_colour_manual(values = c(
    "Over-represented\nin official sources" = "#425A8C",
    "Under-represented\nin official sources" = "#E64B35"
  )) +
  scale_x_continuous(
    limits = c(-60, 80),
    breaks = seq(-60, 80, 20),
    labels = function(x) paste0(ifelse(x > 0, "+", ""), x, "pp")
  ) +
  labs(x = "Difference in proportion (percentage points)\nOfficial PH - Academic", y = NULL, colour = NULL) +
  theme_minimal(base_size = 15) +
  theme(
    legend.position = "bottom",
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 16),
    axis.text.x = element_text(size = 14),
    axis.title.x = element_text(size = 16),
    plot.margin = margin(5, 5, 5, 5)
  )

panel_a <- plot_a + annotate("text", x = 0.1, y = 1.03, label = "A", size = 8, fontface = "bold") +
  theme(plot.margin = margin(5, 10, 5, 5))
panel_b <- plot_b + annotate("text", x = -58, y = 7.5, label = "B", size = 8, fontface = "bold") +
  theme(plot.margin = margin(5, 5, 5, 10))

figure <- panel_a + panel_b + plot_layout(widths = c(1.05, 1.25), guides = "collect") &
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "figure1.pdf"), figure, width = 15, height = 7.2, device = cairo_pdf)
ggsave(file.path(output_dir, "figure1.png"), figure, width = 15, height = 7.2, dpi = 320)
