# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 03 annual series
#
# Author: Diogo Grieco
#
# Purpose: National annual series (report figure 6): gap counts by type plus
#          total deforested area.
# =============================================================================

source("viz/00_setup.R")

# -----------------------------------------------------------------------------
#### 4: national annual series
# -----------------------------------------------------------------------------
# Two gap counts per year (primary axis) plus total deforested area (secondary
# axis; ggplot needs the manual rescale onto the primary scale, inverted in
# sec_axis). Two fixed annotations: the 2019-2022 capacity shock and the 2025
# band (last panel year, still subject to revision).
#
# Guard: what the series shows of the shock is the INVERSION, the years when
# absolute gap overtakes measured gap, not the counts themselves.

PUB_SHOCK_INVERSION <- c(2020, 2021, 2022)

stopifnot(
  "annual series: the capacity-shock inversion changed" =
    setequal(annual$year[annual$n_absolute_gap > annual$n_measured_gap &
                           annual$year >= 2017], PUB_SHOCK_INVERSION)
)

rescale_factor <- max(annual$n_absolute_gap, annual$n_measured_gap) /
  max(annual$total_deforested_km2)

annual_long <- annual %>%
  select(year, n_absolute_gap, n_measured_gap) %>%
  pivot_longer(-year, names_to = "type", values_to = "count") %>%
  mutate(type = recode(type, n_absolute_gap = "absolute_gap",
                       n_measured_gap = "measured_gap"))

p_annual <- ggplot() +
  annotate("rect", xmin = 2024.5, xmax = 2025.5, ymin = -Inf, ymax = Inf,
           fill = "#f3e9df", alpha = 0.6) +
  geom_area(data = annual,
            aes(x = year, y = total_deforested_km2 * rescale_factor),
            fill = "#d9ae6a", alpha = 0.25) +
  geom_line(data = annual_long, aes(x = year, y = count, colour = type),
            linewidth = 1) +
  geom_point(data = annual_long, aes(x = year, y = count, colour = type)) +
  scale_colour_manual(values = GAP_PALETTE, labels = GAP_LABELS,
                      name = "Tipo de lacuna") +
  scale_y_continuous(name = "Municípios em lacuna", labels = number,
                     sec.axis = sec_axis(~ . / rescale_factor,
                                         name = "Total desmatado (km²)",
                                         labels = number)) +
  annotate("text", x = 2020.5, y = max(annual_long$count),
           label = "2019-2022\nchoque de capacidade", size = 3,
           colour = "#6b756d") +
  labs(x = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "06_annual_series.png"), p_annual,
       width = 8, height = 5, dpi = 150)
