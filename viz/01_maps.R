# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 01 static maps
# ranking x mesh
#
# Author: Diogo Grieco
#
# Purpose: Static maps (report figures 1 to 5), in the order that builds the
#          index: numerator, numerator normalised, denominator, ratio,
#          direction. All rank-quintiles over the SAME 552 municipalities.
# =============================================================================

source("viz/00_setup.R")

# -----------------------------------------------------------------------------
#### Join ranking onto the mesh (by geocode, never by name)
# -----------------------------------------------------------------------------

map_data <- muni_mesh %>%
  left_join(ranking, by = c("code_muni" = "geocode_ibge"))

stopifnot(
  "map_data: join did not return N_MUNI rows" = nrow(map_data) == N_MUNI,
  "map_data: some ranking geocode has no polygon" =
    sum(is.na(map_data$avg_egs_18y)) == 0
)

# -----------------------------------------------------------------------------
#### Rank-quintiles over one population, shared by figures 1, 2, 4 and 5
# -----------------------------------------------------------------------------
# The 220 without a year above the 1 km2 threshold are a category, not a low
# quintile.

N_NO_PRESSURE <- 220

q5_pressure <- function(x, has_pressure)
  factor(coalesce(q5(if_else(has_pressure, x, NA_real_)), 0L), levels = 0:5)

map_data <- map_data %>%
  mutate(
    has_pressure = n_years_pressure > 0,
    q_defor_abs  = q5_pressure(total_desmatado_km2, has_pressure),
    q_defor_pct  = q5_pressure(pct_desmatado, has_pressure),
    q_egs        = q5_pressure(avg_egs_18y, has_pressure)
  )

stopifnot(
  "no-pressure count changed" =
    sum(!map_data$has_pressure) == N_NO_PRESSURE,
  "no pressure and zero EGS are no longer the same set" =
    identical(!map_data$has_pressure, map_data$avg_egs_18y == 0),
  "the maps no longer share the partition" =
    all(vapply(list(map_data$q_defor_abs, map_data$q_defor_pct,
                    map_data$q_egs),
               function(q) sum(q == "0"), integer(1)) == N_NO_PRESSURE)
)

CAT_NONE <- unname(GAP_PALETTE["no_pressure"])
CAT_GAP  <- unname(GAP_PALETTE["absolute_gap"])
Q_LABELS <- c("0" = "sem pressão", "1" = "1", "2" = "2",
              "3" = "3", "4" = "4", "5" = "5")

# One ramp per quantity: brown for the numerator, blue for the denominator,
# plum for the ratio. A shared ramp would read as a shared scale.
DEFOR_PALETTE <- c("0" = CAT_NONE, QUINTILE_PALETTE)
EGS_PALETTE   <- c("0" = CAT_NONE, setNames(EGS_RAMP, as.character(1:5)))

# -----------------------------------------------------------------------------
#### State outlines (dissolved from the panel mesh)
# -----------------------------------------------------------------------------
# The Legal Amazon PORTION of each state: MA, TO and MT enter only in part.

uf_borders <- map_data %>%
  mutate(uf_code = substr(code_muni, 1, 2)) %>%
  group_by(uf_code) %>%
  summarise(.groups = "drop")

stopifnot("uf_borders: expected the 9 Legal Amazon states" =
            nrow(uf_borders) == 9)

state_layer <- geom_sf(data = uf_borders, fill = NA, colour = "#4a534c",
                       linewidth = 0.35, inherit.aes = FALSE)

# -----------------------------------------------------------------------------
#### Top-20 highlight (outline)
# -----------------------------------------------------------------------------

TOP_N <- 20
top20_codes <- ranking %>%
  slice_max(avg_egs_18y, n = TOP_N) %>%
  pull(geocode_ibge)
top20_shapes <- map_data %>% filter(code_muni %in% top20_codes)

stopifnot("top20: expected TOP_N shapes" = nrow(top20_shapes) == TOP_N)

outline_layer <- list(
  geom_sf(data = top20_shapes, fill = NA, colour = "#ffffff",
          linewidth = 1.1, inherit.aes = FALSE),
  geom_sf(data = top20_shapes, fill = NA, colour = "#1a3d2e",
          linewidth = 0.5, inherit.aes = FALSE)
)

# -----------------------------------------------------------------------------
#### 1: deforestation, absolute km2 (the raw numerator)
# -----------------------------------------------------------------------------

m_defor_abs <- ggplot(map_data) +
  geom_sf(aes(fill = q_defor_abs), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = DEFOR_PALETTE, labels = Q_LABELS,
                    name = "Quintil de\ndesmatamento acumulado") +
  state_layer +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### 2: share of the territory deforested (numerator normalised)
# -----------------------------------------------------------------------------

m_defor_pct <- ggplot(map_data) +
  geom_sf(aes(fill = q_defor_pct), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = DEFOR_PALETTE, labels = Q_LABELS,
                    name = "Quintil de\n% do território\ndesmatado") +
  state_layer +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### 3: the denominator (autos and fines, geometric mean)
# -----------------------------------------------------------------------------

N_NO_FINE_GAP <- 66
N_FINED       <- 486

map_data <- map_data %>%
  mutate(
    response = sqrt(log10(1 + n_infractions) * log10(1 + total_fines)),
    q_fines  = factor(case_when(
      !has_pressure    ~ "none",
      total_fines == 0 ~ "gap",
      TRUE             ~ as.character(
                           q5(if_else(has_pressure & total_fines > 0,
                                      response, NA_real_)))),
      levels = c("none", "gap", "1", "2", "3", "4", "5")))

stopifnot(
  "q_fines: absolute-gap count changed" =
    sum(map_data$q_fines == "gap") == N_NO_FINE_GAP,
  "q_fines: fined count changed" =
    sum(map_data$q_fines %in% as.character(1:5)) == N_FINED,
  "q_fines: the grey is no longer the shared no-pressure set" =
    identical(map_data$q_fines == "none", !map_data$has_pressure),
  "response: the geometric mean is no longer count-dominated" =
    round(cor(rank(map_data$response[map_data$q_fines %in% as.character(1:5)]),
              rank(map_data$n_infractions[map_data$q_fines %in%
                                            as.character(1:5)])), 3) == 0.993
)

FINES_PALETTE <- c(none = CAT_NONE, gap = CAT_GAP,
                   "1" = "#9fb9dd", "2" = "#7c9bca", "3" = "#5c7cb0",
                   "4" = "#405f92", "5" = "#26406e")
FINES_LABELS  <- c(none = "sem pressão", gap = "com pressão, sem multa",
                   "1" = "1", "2" = "2", "3" = "3", "4" = "4", "5" = "5")

m_fines <- ggplot(map_data) +
  geom_sf(aes(fill = q_fines), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = FINES_PALETTE, labels = FINES_LABELS,
                    name = "Quintil da resposta federal\n(autos x multas)") +
  state_layer +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### 4: mean 18y EGS (the ratio)
# -----------------------------------------------------------------------------

m_egs <- ggplot(map_data) +
  geom_sf(aes(fill = q_egs), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = EGS_PALETTE, labels = Q_LABELS,
                    name = "Quintil de\nEGS médio (18 anos)") +
  state_layer +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### 5: direction of travel (where the ratio is going)
# -----------------------------------------------------------------------------
# avg_egs_3y - avg_egs_18y, the quantity figure 8 splits on its identity line.

TREND_STABLE <- 0.05
TREND_STRONG <- 0.20

map_data <- map_data %>%
  mutate(egs_trend = factor(case_when(
    n_years_pressure == 0            ~ "no_pressure",
    abs(avg_egs_3y - avg_egs_18y) <
      TREND_STABLE                   ~ "stable",
    avg_egs_3y - avg_egs_18y <=
      -TREND_STRONG                  ~ "better_hi",
    avg_egs_3y < avg_egs_18y         ~ "better",
    avg_egs_3y - avg_egs_18y >=
      TREND_STRONG                   ~ "worse_hi",
    TRUE                             ~ "worse"),
    levels = c("worse_hi", "worse", "stable", "better", "better_hi",
               "no_pressure")))

N_TREND <- c(worse_hi = 35, worse = 72, stable = 149, better = 202,
             better_hi = 94, no_pressure = 220)

stopifnot("egs_trend: published band counts changed" =
            identical(as.integer(table(map_data$egs_trend)[names(N_TREND)]),
                      as.integer(N_TREND)))

# The two extremes are figure 8's two colours: same quantity, same vocabulary.
TREND_PALETTE <- c(worse_hi = "#a63d2f", worse = "#d19a8f",
                   stable = "#ece9e0", better = "#7fb096",
                   better_hi = "#2e6e54", no_pressure = CAT_NONE)
TREND_LABELS  <- c(worse_hi = "piorando muito", worse = "piorando",
                   stable = "estável", better = "melhorando",
                   better_hi = "melhorando muito",
                   no_pressure = "sem pressão")

m_egs_trend <- ggplot(map_data) +
  geom_sf(aes(fill = egs_trend), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = TREND_PALETTE, labels = TREND_LABELS,
                    name = "EGS recente (2023–2025)\ncontra o histórico") +
  state_layer +
  outline_layer +
  theme_map

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "01_deforestation_abs.png"), m_defor_abs,
       width = 8, height = 7, dpi = 150)
ggsave(file.path(PATH_OUT, "02_deforestation_pct.png"), m_defor_pct,
       width = 8, height = 7, dpi = 150)
ggsave(file.path(PATH_OUT, "03_fines_map.png"), m_fines,
       width = 8, height = 7, dpi = 150)
ggsave(file.path(PATH_OUT, "04_egs_mean18y.png"), m_egs,
       width = 8, height = 7, dpi = 150)

ggsave(file.path(PATH_OUT, "05_egs_trend.png"), m_egs_trend,
       width = 8, height = 7, dpi = 150)
