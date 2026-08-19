# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 02 ranking panels
# ranking & panel grain
#
# Author: Diogo Grieco
#
# Purpose: Non-spatial panels on the municipality-grain ranking (report
#          figures 1, 8 and 9).
#            1  the EGS formula drawn: numerator against denominator
#            8  historical x recent quadrant (avg_egs_18y vs avg_egs_3y)
#            9  small multiples: annual EGS of the 6 anchor cases
# =============================================================================

source("viz/00_setup.R")
library(ggrepel)   # non-overlapping point labels

# -----------------------------------------------------------------------------
#### 1: the EGS formula drawn
# -----------------------------------------------------------------------------

# One worked case per temporal shape, read by figures 1, 8 and 9.
ANCHOR_NAMES <- c("Apuí", "Cumaru do Norte", "Cachoeira do Piriá",
                  "Nova Nazaré", "Governador Luiz Rocha", "Santo Afonso")

FORMULA_FLOOR <- 1          # GREATEST(1, ...) in pipeline/03_analytics.sql
EGS_RAYS      <- c(0.25, 0.5, 1)
X_TICKS       <- c(0, 10, 100, 1000, 10000)

# Halo, not size or weight: it is what lifts the name off a dense cloud.
# seed: ggrepel jitters AT DRAW TIME, so without it the same plot renders
# byte-differently. force_pull above 1 keeps each label near its own point.
# bg.color/bg.r need ggrepel >= 0.9.0.
repel_names <- function(data)
  geom_text_repel(data = data, aes(label = municipality_name),
                  size = 3.2, fontface = "bold", colour = "grey15",
                  bg.color = "white", bg.r = 0.16,
                  min.segment.length = 0, box.padding = 0.8,
                  point.padding = 0.5, force = 5, force_pull = 2.5,
                  max.overlaps = Inf,
                  segment.colour = "grey40", segment.size = 0.3, seed = 42)

# A ring: it says which point the name belongs to.
ring_points <- function(data)
  geom_point(data = data, shape = 21, fill = NA, colour = OUTLINE_DARK,
             stroke = 0.8, size = 2.8)

PUB_N_ZERO_DEFOR <- 133     # dropped: no pressure in 18 years
PUB_N_AT_FLOOR   <- 106     # of the 639 drawn, response at the formula floor
PUB_SPEARMAN_AGG <- 0.503   # this figure's ratio vs. the published
                            # avg_egs_18y, over the municipalities DRAWN

# Computed in pipeline/03_analytics.sql: the tie precedence decides 23 of 772.
formula_df <- ranking %>%
  mutate(gap_dominant = factor(gap_dominant, levels = names(GAP_PALETTE)))

stopifnot("formula plot: zero-deforestation count changed" =
            sum(formula_df$total_desmatado_km2 == 0) == PUB_N_ZERO_DEFOR)

formula_df <- formula_df %>% filter(total_desmatado_km2 > 0)

# Measured on the DRAWN set: the 133 dropped would lift it to 0.701 hollowly,
# their ratio and their EGS both being zero.
stopifnot(
  "formula plot: drawn count changed" =
    nrow(formula_df) == N_MUNI - PUB_N_ZERO_DEFOR,
  "formula plot: floor count changed" =
    sum(formula_df$denominador_18y == FORMULA_FLOOR) == PUB_N_AT_FLOOR,
  "formula plot: aggregate-vs-index rank correlation changed" =
    round(cor(formula_df$numerador_18y / formula_df$denominador_18y,
              formula_df$avg_egs_18y, method = "spearman"), 3) ==
      PUB_SPEARMAN_AGG
)

anchors <- formula_df %>% filter(municipality_name %in% ANCHOR_NAMES)
stopifnot("anchors: some anchor is missing from the drawn set" =
            nrow(anchors) == length(ANCHOR_NAMES))

X_MAX <- ceiling(max(formula_df$numerador_18y) * 10) / 10
Y_MAX <- ceiling(max(formula_df$denominador_18y) * 10) / 10
ray_labels <- data.frame(
  egs   = EGS_RAYS,
  x     = 0.88 * pmin(X_MAX, Y_MAX * EGS_RAYS),
  y     = 0.88 * pmin(Y_MAX, X_MAX / EGS_RAYS),
  label = paste("EGS", sub("\\.", ",", as.character(EGS_RAYS))))

p_scatter <- ggplot(formula_df, aes(x = numerador_18y, y = denominador_18y)) +
  geom_abline(slope = 1 / EGS_RAYS, intercept = 0, linetype = "dashed",
              colour = "grey65") +
  geom_hline(yintercept = FORMULA_FLOOR, colour = "grey75", linewidth = 0.3) +
  # shape 21 with white stroke: full-strength colour under overlap.
  geom_point(aes(fill = gap_dominant), shape = 21, colour = "white",
             stroke = 0.25, size = 2.1) +
  geom_label(data = ray_labels, aes(x = x, y = y, label = label),
             colour = "grey45", fill = "white", label.size = 0,
             size = 2.8, label.padding = unit(0.12, "lines")) +
  scale_fill_manual(values = GAP_PALETTE, labels = GAP_LABELS,
                    name = "Tipo dominante") +
  # The axis is log10(1 + area), so the break sits at the true position of the
  # round decade. Breaks past the data range are dropped by ggplot.
  scale_x_continuous(breaks = log10(1 + X_TICKS),
                     labels = number(X_TICKS, accuracy = 1)) +
  ring_points(anchors) +
  repel_names(anchors) +
  labs(x = "Numerador: km² desmatados",
       y = "Denominador: autos × multas (média geométrica)") +
  theme_chart +
  theme(legend.position = "right")

# -----------------------------------------------------------------------------
#### 8: historical x recent quadrant
# -----------------------------------------------------------------------------

# Same six anchors as figures 1 and 9. Labelling by top avg_egs_18y instead
# would select on a coordinate of the x axis and pile every name in a corner.

p_quadrant <- ggplot(ranking, aes(x = avg_egs_18y, y = avg_egs_3y)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              colour = "grey60") +
  geom_point(aes(fill = egs_trend), shape = 21, colour = "white",
             stroke = 0.25, size = 2.4) +
  scale_fill_manual(values = TREND_PALETTE, labels = TREND_LABELS,
                    name = NULL) +
  scale_x_continuous(labels = number) +
  scale_y_continuous(labels = number) +
  ring_points(anchors) +
  repel_names(anchors) +
  labs(x = "EGS médio histórico (2008-2025)",
       y = "EGS médio recente (2023-2025)") +
  theme_chart

# -----------------------------------------------------------------------------
#### 9: small multiples, annual EGS of the 5 anchor cases
# -----------------------------------------------------------------------------

anchor_series <- final %>%
  filter(municipality_name %in% ANCHOR_NAMES) %>%
  mutate(municipality_name = factor(municipality_name, levels = ANCHOR_NAMES))

# The ranking's ordering criterion, read from the parquet, not refitted.
anchor_mean <- ranking %>%
  filter(municipality_name %in% ANCHOR_NAMES) %>%
  transmute(municipality_name = factor(municipality_name,
                                       levels = ANCHOR_NAMES), avg_egs_18y)

stopifnot("anchor mean: expected one row per anchor" =
            nrow(anchor_mean) == length(ANCHOR_NAMES))

p_anchors <- ggplot(anchor_series, aes(x = year, y = egs)) +
  geom_hline(data = anchor_mean, aes(yintercept = avg_egs_18y),
             colour = "grey45", linetype = "dashed", linewidth = 0.5) +
  # Plum: this panel plots the EGS.
  geom_line(colour = EGS_RAMP[5], linewidth = 0.8) +
  geom_point(colour = EGS_RAMP[5], size = 1) +
  # 3 x 2: a wider strip shrinks the labels to about half their intended size.
  facet_wrap(~ municipality_name, ncol = 3) +
  scale_y_continuous(labels = number) +
  labs(x = NULL, y = "EGS (anual)") +
  theme_chart +
  theme(panel.spacing = unit(0.8, "lines"))

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "01_egs_formula.png"), p_scatter,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "08_quadrant.png"), p_quadrant,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "09_anchor_small_multiples.png"), p_anchors,
       width = 7.5, height = 4.6, dpi = 150)
