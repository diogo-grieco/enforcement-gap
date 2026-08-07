# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 00 setup
#
# Author: Diogo Grieco
#
# Purpose: Shared entry point for every viz_*.R script: load packages, declare
#          paths and files, declare data integrity checkpoints, load the feeds
#          with stopifnot() guards, and define the shared palette, theme and
#          quantile helper. Sourced by each downstream script, never run alone.
#          Run with the working directory at the PROJECT ROOT (project2.Rproj).
# =============================================================================

# -----------------------------------------------------------------------------
#### Calling packages
# -----------------------------------------------------------------------------

library(tidyverse)   # dplyr, tidyr, ggplot2, stringr, forcats, purrr, readr
library(sf)          # spatial geometries
library(arrow)       # read the .parquet feeds
library(scales)      # axis / label formatting

# Number formatting: Brazilian locale (comma decimal, dot thousands) on every
# axis/label so the figures match the ABNT text. Overrides the scales names
# used across the suite; call sites stay unchanged.
percent      <- function(x, ...) scales::percent(x, decimal.mark = ",", big.mark = ".", ...)
number       <- function(x, ...) scales::number(x, decimal.mark = ",", big.mark = ".", ...)
label_number <- function(...)    scales::label_number(decimal.mark = ",", big.mark = ".", ...)

# Sufixos de escala curta em português. scales::cut_short_scale() devolve
# K/M/B/T (inglês) e vazava para os eixos do log-log e para a legenda do mapa
# bivariado; cut_br_scale() é o equivalente pt-BR. Usar sempre este.
cut_br_scale <- function() c(" " = 0, "mil" = 1e3, "mi" = 1e6, "bi" = 1e9, "tri" = 1e12)

# -----------------------------------------------------------------------------
#### Setting paths and files
# -----------------------------------------------------------------------------

PATH_PARQUETS   <- "output/parquets"
FILE_RANKING    <- "egs_ranking.parquet"      # municipality grain
FILE_FINAL      <- "egs_final.parquet"        # municipality-year grain
FILE_ANNUAL     <- "annual_summary.parquet"   # year grain

PATH_IBGE       <- "data/data_ibge"
FILE_MESH       <- "malha_772_amazonia_legal_simplificada.geojson"

# Public release: 13 of 84 raw columns, CPF_CNPJ_INFRATOR replaced with a
# random surrogate id, NOME_INFRATOR dropped. See data/data_ibama_public/README.md.
PATH_IBAMA      <- "data/data_ibama_public"
PATTERN_IBAMA   <- "auto_infracao_ano_.*\\.csv"

PATH_OUT        <- "output/visualizations"        # where every plot is saved
PATH_CACHE      <- "output/parquets"              # viz_* intermediate parquets

# -----------------------------------------------------------------------------
#### Data integrity checkpoints
# -----------------------------------------------------------------------------

N_MUNI                <- 772       # municipalities in the panel (767 names; 5 homonyms)
N_PANEL               <- 13896     # municipality-years (772 x 18)
N_YEARS               <- 18        # 2008-2025
N_ANNUAL_ROWS         <- 18        # one row per year in annual_summary
N_MESH_FEATURES       <- 772       # polygons in the simplified mesh
N_IBAMA_RAW           <- 309116    # national infraction notices (all types)
N_IBAMA_AMAZON        <- 131196    # notices in the 772 panel munis (all types/status)
N_IBAMA_DEFOR_AMAZON  <- 48063     # deforestation-type notices, all statuses
N_IBAMA_DEFOR_CLEAN   <- 43576     # deforestation-type, not cancelled, "Lavrado"

# -----------------------------------------------------------------------------
#### Loading the feeds (with stopifnot guards)
# -----------------------------------------------------------------------------

ranking <- arrow::read_parquet(file.path(PATH_PARQUETS, FILE_RANKING))
final   <- arrow::read_parquet(file.path(PATH_PARQUETS, FILE_FINAL))
annual  <- arrow::read_parquet(file.path(PATH_PARQUETS, FILE_ANNUAL))

stopifnot(
  "ranking: unexpected row count"                 = nrow(ranking) == N_MUNI,
  "ranking: geocode_ibge not unique"              = n_distinct(ranking$geocode_ibge) == N_MUNI,
  "final: unexpected row count"                   = nrow(final) == N_PANEL,
  "final: unexpected number of years"             = n_distinct(final$year) == N_YEARS,
  "annual: unexpected row count"                  = nrow(annual) == N_ANNUAL_ROWS
)

# -----------------------------------------------------------------------------
#### Municipal mesh (for every map)
# -----------------------------------------------------------------------------
# code_muni comes out of the GeoJSON numeric; geocode_ibge in the parquets is
# text. Force both sides to the SAME type (character 7-digit) before any join;
# never join by name (5 homonym pairs in the panel).

muni_mesh <- st_read(file.path(PATH_IBGE, FILE_MESH), quiet = TRUE) %>%
  mutate(code_muni = as.character(as.integer(code_muni)))

stopifnot(
  "mesh: unexpected feature count"                = nrow(muni_mesh) == N_MESH_FEATURES,
  "mesh: some panel geocode has no polygon"       =
    length(setdiff(ranking$geocode_ibge, muni_mesh$code_muni)) == 0
)

# -----------------------------------------------------------------------------
#### Shared palette, themes and quantile helper
# -----------------------------------------------------------------------------
# Sequential single-hue quintile palette (darker = higher), matching the
# dashboard mockup. EGS and pct_desmatado are ORDINAL: always colour by
# rank-quintile, never by a continuous raw value.

QUINTILE_PALETTE <- c("1" = "#f5f0e1", "2" = "#e8d9a8", "3" = "#d9ae6a",
                      "4" = "#b9773a", "5" = "#7c4a20")

# Gap-type palette (absolute / measured / no-pressure), also from the mockup.
GAP_PALETTE <- c(absolute_gap = "#a63d2f", measured_gap = "#c98a3d",
                 no_pressure  = "#b9c2b6")

# Portuguese display labels for gap_type, for any chart that shows this
# category as axis text or a legend (values stay in English everywhere else;
# this is display-only, never used to filter/join/compare).
GAP_LABELS <- c(absolute_gap = "lacuna absoluta", measured_gap = "lacuna medida",
                no_pressure  = "sem pressão")

# Map theme: strip axes/grid for choropleths.
theme_map <- theme_minimal(base_size = 12) +
  theme(axis.text = element_blank(), axis.ticks = element_blank(),
        axis.title = element_blank(), panel.grid = element_blank())

# Chart theme: minimal, light grid for the non-spatial plots.
theme_chart <- theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(colour = "#5a655c"))

# Rank-quintile helper: ntile(x, 5) splits by RANK into 5 equal-sized groups
# (~161 municipalities each): the correct binning for the long-tailed
# variables (equal-width bins would crush everything into bin 1).
q5 <- function(x) ntile(x, 5)

# -----------------------------------------------------------------------------
#### Output folders
# -----------------------------------------------------------------------------

dir.create(PATH_OUT, showWarnings = FALSE, recursive = TRUE)

message("setup ok, ranking: ", nrow(ranking),
        " | final: ", nrow(final),
        " | annual: ", nrow(annual),
        " | mesh: ", nrow(muni_mesh))
