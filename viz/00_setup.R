# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 00 setup
#
# Author: Diogo Grieco
#
# Purpose: Shared entry point for every viz script: packages, paths, integrity
#          checkpoints, the three parquet feeds and the mesh (with stopifnot
#          guards), the EGS direction bands, and the shared palette, themes
#          and quantile helper. Sourced by each script, never run alone.
#          Run with the working directory at the PROJECT ROOT (project2.Rproj).
# =============================================================================

# -----------------------------------------------------------------------------
#### Calling packages
# -----------------------------------------------------------------------------

library(tidyverse)
library(sf)
library(arrow)
library(scales)

# Brazilian locale (comma decimal, dot thousands) on every axis and label, so
# the figures match the ABNT text. These shadow the scales:: names
percent <- function(x, ...)
  scales::percent(x, decimal.mark = ",", big.mark = ".", ...)
number <- function(x, ...)
  scales::number(x, decimal.mark = ",", big.mark = ".", ...)
label_number <- function(...)
  scales::label_number(decimal.mark = ",", big.mark = ".", ...)

# Short-scale suffixes in pt-BR. scales::cut_short_scale() returns K/M/B/T
cut_br_scale <- function()
  c(" " = 0, "mil" = 1e3, "mi" = 1e6, "bi" = 1e9, "tri" = 1e12)

# -----------------------------------------------------------------------------
#### Setting paths and files
# -----------------------------------------------------------------------------

PATH_PARQUETS   <- "output/parquets"
FILE_RANKING    <- "egs_ranking.parquet"
FILE_FINAL      <- "egs_final.parquet"
FILE_ANNUAL     <- "annual_summary.parquet"

PATH_IBGE       <- "data/data_ibge"
FILE_MESH       <- "malha_772_amazonia_legal_simplificada.geojson"

PATH_OUT        <- "output/visualizations"

# -----------------------------------------------------------------------------
#### Data integrity checkpoints
# -----------------------------------------------------------------------------

N_MUNI               <- 772
N_PANEL              <- 13896
N_YEARS              <- 18
N_MESH_FEATURES      <- 772

# -----------------------------------------------------------------------------
#### Loading the feeds (with stopifnot guards)
# -----------------------------------------------------------------------------

ranking <- arrow::read_parquet(file.path(PATH_PARQUETS, FILE_RANKING))
final   <- arrow::read_parquet(file.path(PATH_PARQUETS, FILE_FINAL))
annual  <- arrow::read_parquet(file.path(PATH_PARQUETS, FILE_ANNUAL))

stopifnot(
  "ranking: unexpected row count"     = nrow(ranking) == N_MUNI,
  "ranking: geocode_ibge not unique"  =
    n_distinct(ranking$geocode_ibge) == N_MUNI,
  "final: unexpected row count"       = nrow(final) == N_PANEL,
  "final: unexpected number of years" = n_distinct(final$year) == N_YEARS,
  "annual: unexpected row count"      = nrow(annual) == N_YEARS
)

# -----------------------------------------------------------------------------
#### Municipal mesh (for every map)
# -----------------------------------------------------------------------------

muni_mesh <- st_read(file.path(PATH_IBGE, FILE_MESH), quiet = TRUE) %>%
  mutate(code_muni = as.character(as.integer(code_muni)))

stopifnot(
  "mesh: unexpected feature count" = nrow(muni_mesh) == N_MESH_FEATURES,
  "mesh: some panel geocode has no polygon" =
    length(setdiff(ranking$geocode_ibge, muni_mesh$code_muni)) == 0
)

# -----------------------------------------------------------------------------
#### Shared palette, themes and quantile helper
# -----------------------------------------------------------------------------

QUINTILE_PALETTE <- c("1" = "#f5f0e1", "2" = "#e8d9a8", "3" = "#d9ae6a",
                      "4" = "#b9773a", "5" = "#7c4a20")

# One ramp per quantity across the suite: brown for deforestation, blue for
# the response, plum for the EGS. Hue is the only channel left to separate
# them, since lightness already encodes the quintile. Cf. viz/01_maps.R.
EGS_RAMP <- c("#d9b8cd", "#bd8fa9", "#996a86", "#734a64", "#4c2c42")

# Gold, not the former ochre: brown is the deforestation ramp across the whole
# suite, and an ochre gap line collided with ramp levels 3 and 4 (CIEDE2000
# 10.7 and 7.1). The gold also separates better from absolute_gap.
GAP_PALETTE <- c(absolute_gap = "#a63d2f", measured_gap = "#d4a017",
                 no_pressure  = "#b9c2b6")

GAP_LABELS <- c(absolute_gap = "lacuna absoluta",
                measured_gap = "lacuna medida",
                no_pressure  = "sem pressão")

theme_map <- theme_minimal(base_size = 12) +
  theme(axis.text = element_blank(), axis.ticks = element_blank(),
        axis.title = element_blank(), panel.grid = element_blank())

theme_chart <- theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

q5 <- function(x) ntile(x, 5)

# -----------------------------------------------------------------------------
#### EGS direction bands (figures 5 and 8 read the SAME column)
# -----------------------------------------------------------------------------
# egs_trend is computed in pipeline/03_analytics.sql, beside the definition of
# the index it derives from. Here it only gets its level order, which drives
# the legend, and a count check that the feed is the expected vintage.

TREND_LEVELS <- c("worse_hi", "worse", "stable", "better", "better_hi",
                  "no_recent_pressure")
N_TREND <- c(worse_hi = 35, worse = 72, stable = 83, better = 126,
             better_hi = 75, no_recent_pressure = 381)

ranking <- ranking %>%
  mutate(egs_trend = factor(egs_trend, levels = TREND_LEVELS))

stopifnot(
  "egs_trend: band counts changed" =
    identical(as.integer(table(ranking$egs_trend)[names(N_TREND)]),
              as.integer(N_TREND))
)

TREND_PALETTE <- c(worse_hi = "#a63d2f", worse = "#d19a8f",
                   stable = "#ece9e0", better = "#7fb096",
                   better_hi = "#2e6e54",
                   no_recent_pressure = unname(GAP_PALETTE["no_pressure"]))
TREND_LABELS  <- c(worse_hi = "piorando muito", worse = "piorando",
                   stable = "estável", better = "melhorando",
                   better_hi = "melhorando muito",
                   no_recent_pressure = "sem pressão recente")

# -----------------------------------------------------------------------------
#### Output folders
# -----------------------------------------------------------------------------

dir.create(PATH_OUT, showWarnings = FALSE, recursive = TRUE)

message("setup ok, ranking: ", nrow(ranking),
        " | final: ", nrow(final),
        " | annual: ", nrow(annual),
        " | mesh: ", nrow(muni_mesh))
