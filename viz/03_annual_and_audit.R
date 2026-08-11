# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 03 annual series
#
# Author: Diogo Grieco
#
# Purpose: National annual series (item 4): gap counts by type + total
#          deforested area. The pipeline's own verification checks (54 checks
#          across pipeline/01-04*.sql) are unaffected by this file; this
#          script only ever produced a chart of them, never the checks
#          themselves.
# =============================================================================

source("viz/00_setup.R")

# -----------------------------------------------------------------------------
#### 4: national annual series
# -----------------------------------------------------------------------------
# Two gap counts per year (primary axis) + total deforested area (secondary
# axis). ggplot secondary axes need a manual rescale onto the primary scale,
# inverted in sec_axis. Fixed annotations: 2019-2022 capacity shock, and the
# 2025 band (last panel year, still subject to revision).

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
  geom_area(data = annual, aes(x = year, y = total_deforested_km2 * rescale_factor),
            fill = "#d9ae6a", alpha = 0.25) +
  geom_line(data = annual_long, aes(x = year, y = count, colour = type), linewidth = 1) +
  geom_point(data = annual_long, aes(x = year, y = count, colour = type)) +
  scale_colour_manual(values = GAP_PALETTE, labels = GAP_LABELS, name = "Tipo de lacuna") +
  scale_y_continuous(name = "Municípios em lacuna", labels = number,
                     sec.axis = sec_axis(~ . / rescale_factor, name = "Total desmatado (km²)",
                                         labels = number)) +
  annotate("text", x = 2020.5, y = max(annual_long$count),
           label = "2019-2022\nchoque de capacidade", size = 3, colour = "#6b756d") +
  labs(x = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "04_annual_series.png"), p_annual, width = 8, height = 5, dpi = 150)
