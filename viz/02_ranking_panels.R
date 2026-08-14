# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 02 ranking panels
# ranking & panel grain
#
# Author: Diogo Grieco
#
# Purpose: Non-spatial panels on the municipality-grain ranking (report
#          figures 7, 8 and 14).
#            7   log-log scatter (deforestation x fines): the EGS formula drawn
#            8   historical x recent quadrant (avg_egs_18y vs avg_egs_3y)
#            14  small multiples: annual EGS of the 5 anchor cases
# =============================================================================

source("viz/00_setup.R")
library(ggrepel)   # non-overlapping point labels

# -----------------------------------------------------------------------------
#### 7: log-log scatter (the EGS formula drawn)
# -----------------------------------------------------------------------------
# X = total deforested km2 (log10), Y = total fines (log10). On the reference
# diagonal = proportional response; below it = enforcement gap. Colour =
# dominant gap type; anchor cases labelled.
#
# The caption is built from the two constants below, so text and data cannot
# diverge. Snapshot values, same nature as the pipeline's expected counts.
# PUB_N_ZERO_DEFOR counts the parquet column, which is ROUND(SUM(area), 1):
# 131 sum to exactly zero and 2 round to it, and it is the column the axis
# reads, so 133 is what disappears from the plot.

PUB_N_ZERO_FINES <- 129   # never fined: floored to R$ 1.000 on the y axis
PUB_N_ZERO_DEFOR <- 133   # no deforestation: absent (log of zero) on the x axis

stopifnot(
  "log-log: zero-fine count changed" =
    sum(ranking$total_fines == 0) == PUB_N_ZERO_FINES,
  "log-log: zero-deforestation count changed" =
    sum(ranking$total_desmatado_km2 == 0) == PUB_N_ZERO_DEFOR
)

# The zero-fine municipalities are floored so they still plot; the
# zero-deforestation ones are not, because a floor on the pressure axis would
# invent pressure.
scatter_df <- ranking %>%
  mutate(dominant = case_when(
           n_absolute_gap >= n_measured_gap &
             n_absolute_gap >= n_no_pressure ~ "absolute_gap",
           n_measured_gap >= n_no_pressure   ~ "measured_gap",
           TRUE                              ~ "no_pressure"),
         dominant = factor(dominant, levels = c("absolute_gap",
                                                "measured_gap",
                                                "no_pressure")),
         total_fines_plot = pmax(total_fines, 1000))

ANCHOR_NAMES <- c("Apuí", "Cumaru do Norte", "Cachoeira do Piriá",
                  "Nova Nazaré", "Governador Luiz Rocha")
anchors <- scatter_df %>% filter(municipality_name %in% ANCHOR_NAMES)

stopifnot("anchors: expected 5 anchor cases" =
            nrow(anchors) == length(ANCHOR_NAMES))

# The dashed diagonal is a CHOSEN proportionality reference (R$ 100k per km2),
# not the EGS = 1 locus: EGS also depends on n_infractions, which is on neither
# axis, and is annual, while this plot aggregates 18 years. Earlier versions
# called it "the EGS = 1 boundary"; corrected by the sixth audit.
p_scatter <- ggplot(scatter_df,
                    aes(x = total_desmatado_km2, y = total_fines_plot)) +
  geom_abline(slope = 1, intercept = log10(1e5), linetype = "dashed",
              colour = "grey60") +
  geom_point(aes(colour = dominant), alpha = 0.6, size = 1.8) +
  scale_x_log10(labels = label_number(scale_cut = cut_br_scale())) +
  scale_y_log10(labels = label_number(scale_cut = cut_br_scale())) +
  scale_colour_manual(values = GAP_PALETTE, labels = GAP_LABELS,
                      name = "Tipo dominante") +
  # seed: ggrepel jitters labels AT DRAW TIME, so the same plot object rendered
  # twice differs byte-for-byte. set.seed() before the plot would NOT work.
  geom_text_repel(data = anchors, aes(label = municipality_name),
                  size = 3, min.segment.length = 0, seed = 42) +
  labs(caption = paste(
         sprintf(paste("Multas zeradas (%d/%d) fixadas em R$ 1.000 para",
                       "permanecer na escala log;"),
                 PUB_N_ZERO_FINES, N_MUNI),
         sprintf(paste("os %d municípios sem desmatamento no período não",
                       "aparecem (log de zero)."),
                 PUB_N_ZERO_DEFOR), sep = "\n"),
       x = "Total desmatado (km², log)",
       y = "Total de multas (R$ deflacionado, log)") +
  theme_chart +
  theme(legend.position = "right")

# -----------------------------------------------------------------------------
#### 8: historical x recent quadrant
# -----------------------------------------------------------------------------
# X = avg_egs_18y (history), Y = avg_egs_3y (2023-25). Above the identity line
# = worsening recently; below = improving. Size = years of pressure.

p_quadrant <- ggplot(ranking, aes(x = avg_egs_18y, y = avg_egs_3y)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              colour = "grey60") +
  geom_point(aes(size = n_years_pressure,
                 colour = avg_egs_3y > avg_egs_18y), alpha = 0.6) +
  scale_colour_manual(values = c("TRUE" = "#a63d2f", "FALSE" = "#2e6e54"),
                      labels = c("TRUE" = "piorando",
                                 "FALSE" = "melhorando"), name = NULL) +
  scale_size_continuous(range = c(0.5, 5), name = "Anos de pressão") +
  scale_x_continuous(labels = number) +
  scale_y_continuous(labels = number) +
  # order: with two guides and neither declaring one, ggplot2 does not
  # guarantee a stable arrangement between sessions, and the swap breaks the
  # byte-identity between the PNG on disk and the one in the deliverables.
  # Colour first: it is the primary encoding and the one the caption refers to.
  guides(colour = guide_legend(order = 1), size = guide_legend(order = 2)) +
  geom_text_repel(data = ranking %>% slice_max(avg_egs_18y, n = 8),
                  aes(label = municipality_name), size = 3,
                  min.segment.length = 0, seed = 42) +   # seed: see item 5
  labs(x = "EGS médio histórico (2008–2025)",
       y = "EGS médio recente (2023–2025)") +
  theme_chart

# -----------------------------------------------------------------------------
#### 14: small multiples, annual EGS of the 5 anchor cases
# -----------------------------------------------------------------------------

anchor_series <- final %>%
  filter(municipality_name %in% ANCHOR_NAMES) %>%
  mutate(municipality_name = factor(municipality_name, levels = ANCHOR_NAMES))

p_anchors <- ggplot(anchor_series, aes(x = year, y = egs)) +
  geom_line(colour = "#2e6e54", linewidth = 0.8) +
  geom_point(colour = "#2e6e54", size = 1) +
  # 3 + 2 panels: the compact block fits the report's text width without
  # shrinking the labels, which the single 12-inch strip did (text rendered at
  # about 52% of the intended size).
  facet_wrap(~ municipality_name, ncol = 3) +
  scale_y_continuous(labels = number) +
  labs(x = NULL, y = "EGS (anual)") +
  theme_chart +
  theme(panel.spacing = unit(0.8, "lines"))

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "07_loglog_scatter.png"), p_scatter,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "08_quadrant.png"), p_quadrant,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "14_anchor_small_multiples.png"), p_anchors,
       width = 7.5, height = 4.6, dpi = 150)
