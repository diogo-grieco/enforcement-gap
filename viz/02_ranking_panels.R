# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 02 ranking panels
# ranking & panel grain
#
# Author: Diogo Grieco
#
# Purpose: Non-spatial panels on the municipality-grain ranking (report
#          figures 7, 8 and 14).
#            7   the EGS formula drawn: its numerator against its denominator
#            8   historical x recent quadrant (avg_egs_18y vs avg_egs_3y)
#            14  small multiples: annual EGS of the 5 anchor cases
# =============================================================================

source("viz/00_setup.R")
library(ggrepel)   # non-overlapping point labels

# -----------------------------------------------------------------------------
#### 1: the EGS formula drawn
# -----------------------------------------------------------------------------

ANCHOR_NAMES <- c("Apuí", "Cumaru do Norte", "Cachoeira do Piriá",
                  "Nova Nazaré", "Governador Luiz Rocha")

FORMULA_FLOOR <- 1          # GREATEST(1, ...) in pipeline/03_analytics.sql
EGS_RAYS      <- c(0.25, 0.5, 1)

PUB_N_ZERO_DEFOR <- 133     # dropped: no pressure in 18 years
PUB_N_AT_FLOOR   <- 106     # of the 639 drawn, response at the formula floor
PUB_SPEARMAN_AGG <- 0.503   # this figure's ratio vs. the published
                            # avg_egs_18y, over the municipalities DRAWN

formula_df <- ranking %>%
  mutate(numerator   = log10(1 + total_desmatado_km2),
         denominator = pmax(FORMULA_FLOOR,
                            sqrt(log10(1 + n_infractions) *
                                   log10(1 + total_fines))),
         dominant = factor(case_when(
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
    sum(formula_df$denominator == FORMULA_FLOOR) == PUB_N_AT_FLOOR,
  "formula plot: aggregate-vs-index rank correlation changed" =
    round(cor(formula_df$numerator / formula_df$denominator,
              formula_df$avg_egs_18y, method = "spearman"), 3) ==
      PUB_SPEARMAN_AGG
)

anchors <- formula_df %>% filter(municipality_name %in% ANCHOR_NAMES)
stopifnot("anchors: expected 5 anchor cases" =
            nrow(anchors) == length(ANCHOR_NAMES))

X_MAX <- ceiling(max(formula_df$numerator) * 10) / 10
Y_MAX <- ceiling(max(formula_df$denominator) * 10) / 10
ray_labels <- data.frame(
  egs   = EGS_RAYS,
  x     = 0.88 * pmin(X_MAX, Y_MAX * EGS_RAYS),
  y     = 0.88 * pmin(Y_MAX, X_MAX / EGS_RAYS),
  label = paste("EGS", sub("\\.", ",", as.character(EGS_RAYS))))

p_scatter <- ggplot(formula_df, aes(x = numerator, y = denominator)) +
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
  scale_x_continuous(breaks = 0:4,
                     labels = number(10^(0:4) - 1, accuracy = 1)) +
  geom_text_repel(data = anchors, aes(label = municipality_name),
                  size = 3, min.segment.length = 0, seed = 42) +
  labs(x = "Numerador: km² desmatados",
       y = "Denominador: autos × multas (média geométrica)") +
  theme_chart +
  theme(legend.position = "right")

# -----------------------------------------------------------------------------
#### 8: historical x recent quadrant
# -----------------------------------------------------------------------------

p_quadrant <- ggplot(ranking, aes(x = avg_egs_18y, y = avg_egs_3y)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              colour = "grey60") +
  geom_point(aes(fill = egs_trend), shape = 21, colour = "white",
             stroke = 0.25, size = 2.4) +
  scale_fill_manual(values = TREND_PALETTE, labels = TREND_LABELS,
                    name = NULL) +
  scale_x_continuous(labels = number) +
  scale_y_continuous(labels = number) +
  geom_text_repel(data = ranking %>% slice_max(avg_egs_18y, n = 8),
                  aes(label = municipality_name), size = 3,
                  min.segment.length = 0, seed = 42) +   # seed: see item 7
  labs(x = "EGS médio histórico (2008–2025)",
       y = "EGS médio recente (2023–2025)") +
  theme_chart

# -----------------------------------------------------------------------------
#### 9: small multiples, annual EGS of the 5 anchor cases
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

ggsave(file.path(PATH_OUT, "01_egs_formula.png"), p_scatter,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "08_quadrant.png"), p_quadrant,
       width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "09_anchor_small_multiples.png"), p_anchors,
       width = 7.5, height = 4.6, dpi = 150)
