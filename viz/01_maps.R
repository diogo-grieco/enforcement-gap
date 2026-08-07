# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 01 static maps
# ranking x mesh
#
# Author: Diogo Grieco
#
# Purpose: Static choropleth maps (report figures 1-3).
#            1  choropleth: deforestation in absolute km2 (quintiles)
#            2  choropleth: mean 18y EGS (quintiles)
#            3  bivariate map: colour = pct quintile, bubble = total fines,
#                outline = top 20 by avg_egs_18y  (the dashboard's map)
# =============================================================================

source("viz/00_setup.R")

# -----------------------------------------------------------------------------
#### Join ranking onto the mesh (by geocode, never by name)
# -----------------------------------------------------------------------------

map_data <- muni_mesh %>%
  left_join(ranking, by = c("code_muni" = "geocode_ibge"))

stopifnot(
  "map_data: join did not return N_MUNI rows"      = nrow(map_data) == N_MUNI,
  "map_data: some ranking geocode has no polygon"  =
    sum(is.na(map_data$avg_egs_18y)) == 0
)

# -----------------------------------------------------------------------------
#### Rank-quintiles for each mapped variable
# -----------------------------------------------------------------------------

map_data <- map_data %>%
  mutate(
    q_defor_pct = factor(q5(pct_desmatado)),
    q_defor_abs = factor(q5(total_desmatado_km2)),
    q_egs       = factor(q5(avg_egs_18y))
  )

# -----------------------------------------------------------------------------
#### Top-20 highlight (outline)
# -----------------------------------------------------------------------------
# One highlight for all three maps: the municipality boundary drawn thick, not
# a pin on the centroid. A pin marks a point where the object is an area, and
# it hid the fill of the very municipalities the reader is being pointed to.

TOP_N <- 20
top20_codes <- ranking %>% slice_max(avg_egs_18y, n = TOP_N) %>% pull(geocode_ibge)
top20_shapes <- map_data %>% filter(code_muni %in% top20_codes)

stopifnot("top20: expected TOP_N shapes" = nrow(top20_shapes) == TOP_N)

outline_layer <- geom_sf(data = top20_shapes, fill = NA, colour = "#1a3d2e",
                         linewidth = 0.6, inherit.aes = FALSE)

# -----------------------------------------------------------------------------
#### 1: deforestation (absolute km2)
# -----------------------------------------------------------------------------
# Best match to the EGS pattern (Spearman 0.97 with EGS): the EGS numerator
# uses absolute area, not the area ratio.

m_defor_abs <- ggplot(map_data) +
  geom_sf(aes(fill = q_defor_abs), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = QUINTILE_PALETTE, name = "Quintil de\ndesmatamento (km²)") +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### 2: mean 18y EGS
# -----------------------------------------------------------------------------

m_egs <- ggplot(map_data) +
  geom_sf(aes(fill = q_egs), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = QUINTILE_PALETTE, name = "Quintil de\nEGS médio (18 anos)") +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### 3: bivariate map (colour = pct quintile, bubble = total fines)
# -----------------------------------------------------------------------------
# The dashboard's central map, in ggplot: choropleth of pct_desmatado quintile
# + bubbles with AREA proportional to total fines (scale_size_area) + top-20
# outline. Bubbles sit on municipality centroids.

bubble_pts <- suppressWarnings(st_centroid(map_data))

m_bivariate <- ggplot(map_data) +
  geom_sf(aes(fill = q_defor_pct), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = QUINTILE_PALETTE, name = "Quintil de\n% desmatado") +
  # bolhas mais visiveis: o preenchimento a 18% sumia sobre os quintis
  # escuros. 40% de opacidade e contorno mais firme mantem a leitura dupla
  # (a cor do municipio continua visivel por baixo) sem que a bolha se perca.
  geom_sf(data = bubble_pts, aes(size = total_fines),
          shape = 21, fill = "#4a5d8a66", colour = "#2f3f63",
          stroke = 0.8, inherit.aes = FALSE) +
  scale_size_area(max_size = 14, name = "Total de multas (R$, deflacionado)",
                  labels = label_number(scale_cut = cut_br_scale())) +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "01_deforestation_abs.png"), m_defor_abs, width = 8, height = 7, dpi = 150)
ggsave(file.path(PATH_OUT, "02_egs_mean18y.png"),       m_egs,        width = 8, height = 7, dpi = 150)
ggsave(file.path(PATH_OUT, "03_bivariate_map.png"),     m_bivariate,  width = 9, height = 7, dpi = 150)
