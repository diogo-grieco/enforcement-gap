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
#            9  small multiples: annual EGS of the 5 anchor cases
# =============================================================================

source("viz/00_setup.R")
library(ggrepel)   # non-overlapping point labels

# -----------------------------------------------------------------------------
#### 1: the EGS formula drawn
# -----------------------------------------------------------------------------

# One worked case per temporal shape. Santo Afonso (MT) is the sixth: 14
# straight years above the materiality threshold, zero notices and zero reais
# in all 18, then the deforestation stops and the series flatlines. Under the
# old grey rule (n_years_pressure == 0) it would not have been grey, and its
# difference of -0.491 would have put it in the STRONGEST improvement band.
ANCHOR_NAMES <- c("Apuí", "Cumaru do Norte", "Cachoeira do Piriá",
                  "Nova Nazaré", "Governador Luiz Rocha", "Santo Afonso")

FORMULA_FLOOR <- 1          # GREATEST(1, ...) in pipeline/03_analytics.sql
EGS_RAYS      <- c(0.25, 0.5, 1)
X_TICKS       <- c(0, 10, 100, 1000, 10000)

# Figures 1 and 8 both drop a handful of names onto a dense point cloud. Size
# and weight alone do not fix that: a bigger dark glyph on a busy field is
# still a dark glyph on a busy field. What fixes it is a halo, which lifts the
# letters off whatever is behind them while erasing far less than the opaque
# plate a geom_label would paint. seed: ggrepel jitters AT DRAW TIME, so the
# same plot object rendered twice differs byte-for-byte without it.
# bg.color/bg.r need ggrepel >= 0.9.0. force_pull is raised above its
# default of 1 because figures 1 and 8 both have anchors sitting in tight
# pairs: with the default the labels drift far enough that the leader lines
# cross and the reader cannot tell which name belongs to which point.
repel_names <- function(data)
  geom_text_repel(data = data, aes(label = municipality_name),
                  size = 3.2, fontface = "bold", colour = "grey15",
                  bg.color = "white", bg.r = 0.16,
                  min.segment.length = 0, box.padding = 0.8,
                  point.padding = 0.5, force = 5, force_pull = 2.5,
                  max.overlaps = Inf,
                  segment.colour = "grey40", segment.size = 0.3, seed = 42)

# A ring so the reader can tell which point each name belongs to.
ring_points <- function(data)
  geom_point(data = data, shape = 21, fill = NA, colour = OUTLINE_DARK,
             stroke = 0.8, size = 2.8)

PUB_N_ZERO_DEFOR <- 133     # dropped: no pressure in 18 years
PUB_N_AT_FLOOR   <- 106     # of the 639 drawn, response at the formula floor
PUB_SPEARMAN_AGG <- 0.503   # this figure's ratio vs. the published
                            # avg_egs_18y, over the municipalities DRAWN

formula_df <- ranking %>%
  mutate(dominant = factor(case_when(
           n_absolute_gap >= n_measured_gap &
             n_absolute_gap >= n_no_pressure ~ "absolute_gap",
           n_measured_gap >= n_no_pressure   ~ "measured_gap",
           TRUE                              ~ "no_pressure"),
           levels = c("absolute_gap", "measured_gap", "no_pressure")))

stopifnot("formula plot: zero-deforestation count changed" =
            sum(formula_df$total_desmatado_km2 == 0) == PUB_N_ZERO_DEFOR)

formula_df <- formula_df %>% filter(total_desmatado_km2 > 0)

# Measured on the DRAWN set: including the 133 dropped lifts it to 0.701 for a
# hollow reason, since their ratio and their EGS are both zero.
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
  # shape 21 with a white stroke: full-strength colour and readable overlap,
  # the same device the maps use between municipalities.
  geom_point(aes(fill = dominant), shape = 21, colour = "white",
             stroke = 0.25, size = 2.1) +
  geom_label(data = ray_labels, aes(x = x, y = y, label = label),
             colour = "grey45", fill = "white", label.size = 0,
             size = 2.8, label.padding = unit(0.12, "lines")) +
  scale_fill_manual(values = GAP_PALETTE, labels = GAP_LABELS,
                    name = "Tipo dominante") +
  # Round decades on the tick, not 10^k - 1: the axis is log10(1 + area), so
  # the break sits at the true position of 10, 100, 1.000 km2. Breaks beyond
  # the data range are dropped by ggplot.
  scale_x_continuous(breaks = log10(1 + X_TICKS),
                     labels = number(X_TICKS, accuracy = 1)) +
  # The anchors get a dark ring so the reader can tell which point each label
  # belongs to; the repel is loosened so the labels stop landing on the cloud.
  ring_points(anchors) +
  repel_names(anchors) +
  labs(x = "Numerador: km² desmatados",
       y = "Denominador: autos × multas (média geométrica)") +
  theme_chart +
  theme(legend.position = "right")

# -----------------------------------------------------------------------------
#### 8: historical x recent quadrant
# -----------------------------------------------------------------------------

# The labelled points are the same six anchors as figures 1 and 9. The old
# rule was the top 8 by avg_egs_18y, which is a coordinate of the x axis, so
# every name landed in the same corner and none of them was an extreme of the
# quantity this figure is about. The anchors spread across the panel and name
# a case in five of the six bands.

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

# The ordering criterion of the ranking, drawn on the series it summarises.
# Read straight from the parquet, not refitted here. The 2023-2025 mean was
# tried and removed: over its own three-year window it lands among the very
# points it averages, so the segment sat on top of the line. The slope stays
# out too: it is a rate, not a level, and does not share this axis.
anchor_mean <- ranking %>%
  filter(municipality_name %in% ANCHOR_NAMES) %>%
  transmute(municipality_name = factor(municipality_name,
                                       levels = ANCHOR_NAMES), avg_egs_18y)

stopifnot("anchor mean: expected one row per anchor" =
            nrow(anchor_mean) == length(ANCHOR_NAMES))

p_anchors <- ggplot(anchor_series, aes(x = year, y = egs)) +
  geom_hline(data = anchor_mean, aes(yintercept = avg_egs_18y),
             colour = "grey45", linetype = "dashed", linewidth = 0.5) +
  # Plum, the suite's ramp for the EGS: this panel plots the EGS. The green
  # it used before was the exact hex of "melhorando muito" in TREND_PALETTE.
  geom_line(colour = EGS_RAMP[5], linewidth = 0.8) +
  geom_point(colour = EGS_RAMP[5], size = 1) +
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

ggsave(file.path(PATH_OUT, "01_egs_formula.png"), p_scatter,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "08_quadrant.png"), p_quadrant,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "09_anchor_small_multiples.png"), p_anchors,
       width = 7.5, height = 4.6, dpi = 150)
