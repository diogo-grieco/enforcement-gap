# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 03 annual series
#
# Author: Diogo Grieco
#
# Purpose: National annual series (report figure 6): the annual situation of
#          the 772 municipalities plus total deforested area.
# =============================================================================

source("viz/00_setup.R")

# -----------------------------------------------------------------------------
#### 6: national annual series
# -----------------------------------------------------------------------------

PUB_SHOCK_INVERSION <- c(2020, 2021, 2022)

stopifnot(
  "annual series: the capacity-shock inversion changed" =
    setequal(annual$year[annual$n_absolute_gap > annual$n_measured_gap &
                           annual$year >= 2017], PUB_SHOCK_INVERSION),
  "annual series: the three situations no longer partition the panel" =
    all(annual$n_absolute_gap + annual$n_measured_gap +
          annual$n_no_pressure == N_MUNI)
)

PANEL_MUNI  <- "Municípios"
PANEL_DEFOR <- "Total desmatado (km²)"
PANELS      <- c(PANEL_MUNI, PANEL_DEFOR)

SITUATIONS <- c("absolute_gap", "measured_gap", "no_pressure")

muni_series <- annual %>%
  select(year, n_absolute_gap, n_measured_gap, n_no_pressure) %>%
  pivot_longer(-year, names_to = "type", values_to = "value") %>%
  mutate(type  = factor(sub("^n_", "", type), levels = SITUATIONS),
         panel = factor(PANEL_MUNI, levels = PANELS))

defor_series <- annual %>%
  transmute(year, value = total_deforested_km2,
            panel = factor(PANEL_DEFOR, levels = PANELS))

breaks_by_panel <- function(limits) {
  if (max(limits) > 1000) scales::breaks_width(2500)(limits)
  else                    scales::breaks_width(100)(limits)
}

p_annual <- ggplot(mapping = aes(x = year, y = value)) +
  annotate("rect", xmin = min(PUB_SHOCK_INVERSION) - 0.5,
           xmax = max(PUB_SHOCK_INVERSION) + 0.5, ymin = -Inf, ymax = Inf,
           fill = "#f3e9df", alpha = 0.7) +
  geom_col(data = defor_series, fill = QUINTILE_PALETTE[["5"]], width = 0.7) +
  geom_line(data = muni_series, aes(colour = type), linewidth = 1) +
  geom_point(data = muni_series, aes(colour = type)) +
  facet_grid(panel ~ ., scales = "free_y", switch = "y") +
  scale_colour_manual(values = GAP_PALETTE, labels = GAP_LABELS,
                      name = "Situação anual") +
  scale_y_continuous(labels = number, breaks = breaks_by_panel) +
  expand_limits(y = 0) +
  labs(x = NULL, y = NULL) +
  theme_chart +
  theme(strip.placement   = "outside",
        strip.background  = element_blank(),
        strip.text.y.left = element_text(angle = 90))

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "06_annual_series.png"), p_annual,
       width = 8, height = 6, dpi = 150)
