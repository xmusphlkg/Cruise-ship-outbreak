#!/usr/bin/env Rscript

suppressPackageStartupMessages({
     library(dplyr)
     library(ggplot2)
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
df$pathogen_label <- factor(df$pathogen_label, levels = pathogen_levels)

period_summary <- df %>%
     count(period, pathogen_label, name = "n") %>%
     group_by(period) %>%
     mutate(prop = n / sum(n)) %>%
     ungroup()

period_counts <- df %>%
     count(period, name = "n") %>%
     mutate(period = factor(period, levels = period_levels))

# panel A -----------------------------------------------------------------

plot_a <- ggplot(period_summary, aes(x = period, y = prop, fill = pathogen_label)) +
     geom_col(width = 0.68, colour = "white", linewidth = 0.3) +
     geom_text(
          data = period_summary %>% filter(prop >= 0.08),
          aes(label = percent(prop, accuracy = 1)),
          colour = "white",
          size = 3.6,
          fontface = "bold",
          position = position_stack(vjust = 0.5)
     ) +
     geom_text(
          data = period_counts,
          aes(x = period, y = 1.045, label = paste0("n=", n)),
          inherit.aes = FALSE,
          size = 3.5,
          fontface = "bold",
          colour = "grey20"
     ) +
     scale_y_continuous(labels = percent_format(accuracy = 1), expand = expansion(mult = c(0, 0.08))) +
     scale_fill_manual(values = palette, breaks = pathogen_levels, drop = FALSE) +
     coord_cartesian(ylim = c(0, 1.08), clip = "off") +
     labs(x = NULL, y = "Proportion of outbreak events", fill = "Pathogen category") +
     theme_bw() +
     theme(legend.position = 'bottom') +
     guides(fill = guide_legend(ncol = 3, byrow = TRUE, title.position = "top"))

source_levels <- c(
     "official_public_health",
     "academic",
     "other"
)

source_labels <- c(
     official_public_health = "CDC VSP\nlogs",
     academic = "Academic\npublications",
     other = "Grey\nliterature"
)

source_summary <- df %>%
     mutate(
          source_group = case_when(
               data_source_category == "official_public_health" ~ "official_public_health",
               data_source_category == "academic" ~ "academic",
               TRUE ~ "other"
          )
     ) %>%
     count(source_group, pathogen_label, name = "n") %>%
     group_by(source_group) %>%
     mutate(prop = n / sum(n)) %>%
     ungroup() %>%
     complete(source_group, pathogen_label, fill = list(n = 0, prop = 0)) %>%
     mutate(
          source_group = factor(source_group, levels = source_levels),
          source_display = factor(recode(source_group, !!!source_labels), levels = unname(source_labels)),
          pathogen_display = factor(pathogen_label, levels = pathogen_levels)
     )

# panel B -----------------------------------------------------------------

plot_b <- ggplot(source_summary, aes(x = source_display, y = pathogen_display, fill = prop)) +
     geom_tile(colour = "white", linewidth = 0.8) +
     geom_text(
          aes(label = ifelse(n == 0, "—", sprintf("%.1f%%\n(%d)", prop * 100, n))),
          size = 3.4,
          lineheight = 0.9,
          colour = "black"
     ) +
     scale_fill_gradient(
          low = "#FFF7A7",
          high = "#C40024",
          limits = c(0, 0.80),
          breaks = seq(0, 0.8, 0.2),
          labels = percent_format(accuracy = 1),
          name = "Within-source proportion"
     ) +
     scale_y_discrete(labels = c("Viral gastroenteritis" = "Viral gastroenteritis",
                                 "GI bacterial/protozoal" = "GI bacterial/\nprotozoal",
                                 "Unknown aetiology" = "Unknown\naetiology",
                                 "Respiratory viral" = "Respiratory viral",
                                 "Legionella spp." = "Legionella spp.",
                                 "Vaccine-preventable" = "Vaccine-preventable",
                                 "Zoonotic" = "Zoonotic"),
                      limits = rev(pathogen_levels)) +
     labs(x = NULL, y = NULL) +
     theme_bw() +
     theme(legend.position = 'bottom') +
     guides(fill = guide_legend(title.position = "top", title.hjust = 0.5))

figure <- plot_a + plot_b +
     plot_annotation(tag_levels = "A", theme = theme(plot.tag = element_text(size = 20, face = "bold")))

ggsave(file.path(output_dir, "figure1.pdf"), figure, width = 10, height = 6.8, device = cairo_pdf)
ggsave(file.path(output_dir, "figure1.png"), figure, width = 10, height = 6.8, dpi = 300)
