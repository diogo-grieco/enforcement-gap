# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite — 06 animated map
# panel grain x mesh
#
# Author: Diogo Grieco
#
# Purpose: Year-by-year animated choropleth (item 20). Uses the municipality-
#          YEAR panel (not the ranking): an annual animation needs each
#          municipality's value in each year, not the 18y mean.
#
# WARNING: gganimate over 772 polygons x 18 years is heavy (minutes to render).
#          Run the 3-frame static preview FIRST (below) before the full render.
# =============================================================================

source("viz/00_setup.R")
library(gganimate)
library(gifski)

# -----------------------------------------------------------------------------
#### Setting the animated variable
# -----------------------------------------------------------------------------
# "egs"             -> the enforcement frontier moving (or not) over time
# "area_annual"     -> the annual deforestation flow, year by year
# "area_cumulative" -> TOTAL deforestation per municipality, accumulated up to
#                      each year (the frontier expanding — a growing total)

ANIMATE_VAR <- "area_cumulative"

# Human label + output slug per variable (keeps the GIFs from overwriting).
var_meta <- list(
  egs             = list(label = "EGS anual",                        slug = "egs"),
  area_annual     = list(label = "desmatamento anual (km²)",         slug = "defor_annual"),
  area_cumulative = list(label = "desmatamento acumulado (km²)",     slug = "defor_cumulative")
)
stopifnot("ANIMATE_VAR must be egs / area_annual / area_cumulative" =
            ANIMATE_VAR %in% names(var_meta))
var_label <- var_meta[[ANIMATE_VAR]]$label
out_slug  <- var_meta[[ANIMATE_VAR]]$slug

# -----------------------------------------------------------------------------
#### Build per-year quintiles (recomputed WITHIN each year)
# -----------------------------------------------------------------------------
# Colour always means "this municipality's rank among the 772 THIS year".
# For the cumulative variant we first sum area_km2 within municipality ordered
# by year, THEN rank across municipalities each year — so the colour shows how
# a municipality's accumulated total ranks as the frontier grows.

panel_year <- final %>%
  arrange(geocode_ibge, year) %>%
  group_by(geocode_ibge) %>%
  mutate(area_cumulative = cumsum(area_km2)) %>%        # running total per muni
  ungroup() %>%
  mutate(metric = dplyr::case_when(
           ANIMATE_VAR == "egs"             ~ egs,
           ANIMATE_VAR == "area_annual"     ~ area_km2,
           ANIMATE_VAR == "area_cumulative" ~ area_cumulative)) %>%
  group_by(year) %>%
  mutate(q_value = factor(q5(metric))) %>%              # rank-quintile within year
  ungroup()

# Join geometry onto every municipality-year (mesh repeated across years):
# an N_MUNI x N_YEARS = N_PANEL-row sf object — the source of the render weight.
anim_sf <- muni_mesh %>%
  select(code_muni, geometry) %>%
  inner_join(panel_year, by = c("code_muni" = "geocode_ibge"))

stopifnot("anim_sf: unexpected row count" = nrow(anim_sf) == N_PANEL)

# -----------------------------------------------------------------------------
#### Quick test on 3 years (RUN THIS FIRST)
# -----------------------------------------------------------------------------

test_years <- anim_sf %>% filter(year %in% c(2008, 2016, 2024))
p_test <- ggplot(test_years) +
  geom_sf(aes(fill = q_value), colour = "white", linewidth = 0.03) +
  scale_fill_manual(values = QUINTILE_PALETTE, name = paste0("Quintil\n", var_label)) +
  facet_wrap(~ year) +
  theme_map
ggsave(file.path(PATH_OUT, paste0("20_", out_slug, "_preview.png")), p_test,
       width = 12, height = 5, dpi = 130)

# -----------------------------------------------------------------------------
#### Full animation
# -----------------------------------------------------------------------------
# transition_manual() renders exactly ONE frame per year and hard-cuts between
# them — no tweening. This is what a year-by-year choropleth needs: with
# transition_states/transition_time, gganimate tries to interpolate the fills
# and fades polygons in/out during the transition window, which reads as
# flicker (the "blinking" between years). Manual transitions avoid it entirely.
#
# Two more anti-flicker details:
#   - group = code_muni gives each polygon a stable identity across frames.
#   - the label variable for transition_manual is {current_frame} (NOT
#     {closest_state}, which belongs to transition_states).

anim <- ggplot(anim_sf) +
  geom_sf(aes(fill = q_value, group = code_muni), colour = "white", linewidth = 0.03) +
  scale_fill_manual(values = QUINTILE_PALETTE, name = paste0("Quintil\n", var_label)) +
  labs(title = "{current_frame}") +
  theme_map +
  transition_manual(year)

# One frame per year (N_YEARS frames). fps controls how long each year is held
# on screen — 1.5 fps ≈ 0.67 s/year; lower it to linger, raise it to speed up.
anim_gif <- animate(anim, nframes = N_YEARS, fps = 1.5, width = 700, height = 650,
                    renderer = gifski_renderer())
anim_save(file.path(PATH_OUT, paste0("20_", out_slug, "_animated.gif")), anim_gif)
