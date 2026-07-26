# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite — 02 ranking panels
# ranking & panel grain
#
# Author: Diogo Grieco
#
# Purpose: Non-spatial panels on the municipality-grain ranking (items 2-7).
#            2  KPI classification shares (by gap type)
#            3  top-20 horizontal bars + stacked 18y composition
#            5  log-log scatter (deforestation x fines) — the EGS formula drawn
#            6  historical x recent quadrant (avg_egs_18y vs avg_egs_3y)
#            7  small multiples: annual EGS of the 5 anchor cases
# =============================================================================

source("viz/00_setup.R")
library(ggrepel)   # non-overlapping point labels

# -----------------------------------------------------------------------------
#### 2 — KPI classification shares (from the panel grain)
# -----------------------------------------------------------------------------

kpi <- final %>%
  count(gap_type) %>%
  mutate(share = n / sum(n),
         gap_type = factor(gap_type,
                           levels = c("no_pressure", "absolute_gap", "measured_gap")))

stopifnot("kpi: shares must sum to 1" = abs(sum(kpi$share) - 1) < 1e-9)

p_kpi <- ggplot(kpi, aes(x = share, y = gap_type, fill = gap_type)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = percent(share, accuracy = 0.1)), hjust = -0.15, size = 4) +
  scale_fill_manual(values = GAP_PALETTE, guide = "none") +
  scale_y_discrete(labels = GAP_LABELS) +
  scale_x_continuous(labels = percent, limits = c(0, 0.65)) +
  labs(x = NULL, y = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### 3 — top-20 bars + 18y composition
# -----------------------------------------------------------------------------

top20 <- ranking %>%
  slice_max(avg_egs_18y, n = 20) %>%
  mutate(municipality_name = fct_reorder(municipality_name, avg_egs_18y))

p_top20_egs <- ggplot(top20, aes(x = avg_egs_18y, y = municipality_name)) +
  geom_col(fill = "#2e6e54", width = 0.7) +
  geom_text(aes(label = number(avg_egs_18y, accuracy = 0.001)), hjust = -0.15, size = 3) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(x = "avg_egs_18y", y = NULL) +
  theme_chart

# 18-year composition (absolute / measured / no_pressure years, sums to 18).
top20_comp <- top20 %>%
  select(municipality_name, n_absolute_gap, n_measured_gap, n_no_pressure) %>%
  pivot_longer(-municipality_name, names_to = "type", values_to = "years") %>%
  mutate(type = recode(type,
                       n_absolute_gap = "absolute_gap",
                       n_measured_gap = "measured_gap",
                       n_no_pressure  = "no_pressure"),
         type = factor(type, levels = c("absolute_gap", "measured_gap", "no_pressure")))

stopifnot("top20_comp: each municipality must sum to N_YEARS" =
            all(top20_comp %>% group_by(municipality_name) %>%
                  summarise(s = sum(years), .groups = "drop") %>% pull(s) == N_YEARS))

p_top20_comp <- ggplot(top20_comp, aes(x = years, y = municipality_name, fill = type)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = GAP_PALETTE, labels = GAP_LABELS, name = "Tipo de ano") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.02))) +
  labs(x = "anos (de 18)", y = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### 5 — log-log scatter (the EGS formula drawn)
# -----------------------------------------------------------------------------
# X = total deforested km2 (log10), Y = total fines (log10). On the reference
# diagonal = proportional response; below it = enforcement gap. Colour =
# dominant gap type; anchor cases labelled.

scatter_df <- ranking %>%
  mutate(dominant = case_when(
           n_absolute_gap >= n_measured_gap & n_absolute_gap >= n_no_pressure ~ "absolute_gap",
           n_measured_gap >= n_no_pressure                                    ~ "measured_gap",
           TRUE                                                               ~ "no_pressure"),
         dominant = factor(dominant, levels = c("absolute_gap","measured_gap","no_pressure")),
         # 129/772 municipalities have total_fines == 0 (never fined); floored to
         # 1000 so they still plot on the log axis instead of vanishing at -Inf.
         total_fines_plot = pmax(total_fines, 1000))

ANCHOR_NAMES <- c("Apuí", "Cumaru do Norte", "Cachoeira do Piriá",
                  "Nova Nazaré", "Governador Luiz Rocha")
anchors <- scatter_df %>% filter(municipality_name %in% ANCHOR_NAMES)

stopifnot("anchors: expected 5 anchor cases" = nrow(anchors) == length(ANCHOR_NAMES))

# Single reference diagonal (slope 1, intercept log10(1e5) in log-log space =
# fines = 1e5 x desmatado_km2): the EGS = 1 boundary, proportional response.
p_scatter <- ggplot(scatter_df, aes(x = total_desmatado_km2, y = total_fines_plot)) +
  geom_abline(slope = 1, intercept = log10(1e5), linetype = "dashed", colour = "grey60") +
  geom_point(aes(colour = dominant), alpha = 0.6, size = 1.8) +
  scale_x_log10(labels = label_number(scale_cut = cut_short_scale())) +
  scale_y_log10(labels = label_number(scale_cut = cut_short_scale())) +
  scale_colour_manual(values = GAP_PALETTE, labels = GAP_LABELS, name = "Tipo dominante") +
  geom_text_repel(data = anchors, aes(label = municipality_name),
                  size = 3, min.segment.length = 0) +
  labs(caption = "Pontos com multas zeradas (129/772) fixados em R$ 1.000 para permanecer na escala log.",
       x = "Total desmatado (km², log)", y = "Total de multas (R$ deflacionado, log)") +
  theme_chart +
  theme(legend.position = "right")

# -----------------------------------------------------------------------------
#### 6 — historical x recent quadrant
# -----------------------------------------------------------------------------
# X = avg_egs_18y (history), Y = avg_egs_3y (2023-25). Above the identity line
# = worsening recently; below = improving. Size = years of pressure.

p_quadrant <- ggplot(ranking, aes(x = avg_egs_18y, y = avg_egs_3y)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60") +
  geom_point(aes(size = n_years_pressure, colour = avg_egs_3y > avg_egs_18y), alpha = 0.6) +
  scale_colour_manual(values = c("TRUE" = "#a63d2f", "FALSE" = "#2e6e54"),
                      labels = c("TRUE" = "piorando", "FALSE" = "melhorando"), name = NULL) +
  scale_size_continuous(range = c(0.5, 5), name = "Anos de pressão") +
  geom_text_repel(data = ranking %>% slice_max(avg_egs_18y, n = 8),
                  aes(label = municipality_name), size = 3, min.segment.length = 0) +
  labs(x = "avg_egs_18y (histórico)", y = "avg_egs_3y (2023-25)") +
  theme_chart

# -----------------------------------------------------------------------------
#### 7 — small multiples: annual EGS of the 5 anchor cases
# -----------------------------------------------------------------------------

anchor_series <- final %>%
  filter(municipality_name %in% ANCHOR_NAMES) %>%
  mutate(municipality_name = factor(municipality_name, levels = ANCHOR_NAMES))

p_anchors <- ggplot(anchor_series, aes(x = year, y = egs)) +
  geom_line(colour = "#2e6e54", linewidth = 0.8) +
  geom_point(colour = "#2e6e54", size = 1) +
  facet_wrap(~ municipality_name, ncol = 5) +
  labs(x = NULL, y = "EGS (anual)") +
  theme_chart +
  theme(panel.spacing = unit(0.8, "lines"))

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "02_kpi_classification.png"),   p_kpi,        width = 7, height = 3, dpi = 150)
ggsave(file.path(PATH_OUT, "03a_top20_egs.png"),           p_top20_egs,  width = 7, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "03b_top20_composition.png"),   p_top20_comp, width = 7, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "05_loglog_scatter.png"),       p_scatter,    width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "06_quadrant.png"),             p_quadrant,   width = 8, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "07_anchor_small_multiples.png"), p_anchors,  width = 12, height = 3.2, dpi = 150)
