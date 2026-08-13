# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 00 setup
#
# Author: Diogo Grieco
#
# Purpose: Shared entry point for every viz script: packages, paths, integrity
#          checkpoints, the three parquet feeds and the mesh (with stopifnot
#          guards), the raw IBAMA loader, and the shared palette, themes and
#          quantile helper. Sourced by each downstream script, never run alone.
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

# Public release: 13 of 84 raw columns, CPF_CNPJ_INFRATOR replaced with a
# random surrogate id, NOME_INFRATOR dropped. Cf. data/data_ibama_public.
PATH_IBAMA      <- "data/data_ibama_public"
PATTERN_IBAMA   <- "auto_infracao_ano_.*\\.csv"

PATH_OUT        <- "output/visualizations"

# -----------------------------------------------------------------------------
#### Data integrity checkpoints
# -----------------------------------------------------------------------------

N_MUNI               <- 772      
N_PANEL              <- 13896    
N_YEARS              <- 18       
N_MESH_FEATURES      <- 772      
N_IBAMA_AMAZON       <- 131196   
N_IBAMA_DEFOR_AMAZON <- 48063    
N_IBAMA_DEFOR_CLEAN  <- 43576    

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
#### Raw IBAMA loader (used by 04_raw_ibama.R and 06_offender_network.R)
# -----------------------------------------------------------------------------

FILE_RAW_CACHE <- "viz_ibama_amazon_raw.parquet"   # filtered notices (cache)

# The 13 columns of the public release.
IBAMA_COLS <- c("COD_MUNICIPIO", "UF", "DAT_HORA_AUTO_INFRACAO",
                "DT_FATO_INFRACIONAL", "CD_TERMOS_EMBARGOS",
                "CD_TERMOS_APREENSAO", "SIT_CANCELADO",
                "DES_STATUS_FORMULARIO", "TIPO_INFRACAO", "INFRACAO_AREA",
                "COD_INFRACAO", "CPF_CNPJ_INFRATOR", "VAL_AUTO_INFRACAO")

# Deforestation-type COD_INFRACAO set (mirrors marts.ibama_clean, case 2).
DEFORESTATION_CODES <- c("409907","409901","452001","430001","431003","468001")

load_ibama_clean <- function() {
  raw_cache_path <- file.path(PATH_PARQUETS, FILE_RAW_CACHE)
  panel_geocodes <- ranking$geocode_ibge   # asserted unique above

  if (file.exists(raw_cache_path)) {
    ibama <- arrow::read_parquet(raw_cache_path)
  } else {
    files <- list.files(PATH_IBAMA, pattern = PATTERN_IBAMA, full.names = TRUE)
    ibama <- purrr::map_dfr(files, function(f) {
      readr::read_delim(f, delim = ";",
                        locale = locale(encoding = "UTF-8"),
                        col_types = cols(.default = "c"),
                        show_col_types = FALSE) %>%
        select(all_of(IBAMA_COLS)) %>%   # all_of: fail here if one is renamed
        filter(COD_MUNICIPIO %in% panel_geocodes)   # the 772 panel munis
    })
    arrow::write_parquet(ibama, raw_cache_path)
  }

  stopifnot("ibama: unexpected row count" = nrow(ibama) == N_IBAMA_AMAZON)

  is_defor <-
    (ibama$TIPO_INFRACAO == "Flora" & ibama$INFRACAO_AREA == "Desmatamento") |
    (ibama$TIPO_INFRACAO == "Flora" & is.na(ibama$INFRACAO_AREA) &
       ibama$COD_INFRACAO %in% DEFORESTATION_CODES) |
    (is.na(ibama$TIPO_INFRACAO) & ibama$INFRACAO_AREA == "Desmatamento")
  is_defor[is.na(is_defor)] <- FALSE
  defor <- ibama[is_defor, ]

  defor <- defor %>%
    mutate(fine_value = suppressWarnings(
             as.numeric(str_replace(VAL_AUTO_INFRACAO, ",", "."))),
           dt_notice  = suppressWarnings(as.Date(DAT_HORA_AUTO_INFRACAO)),
           dt_fact    = suppressWarnings(as.Date(DT_FATO_INFRACIONAL)),
           year       = as.integer(format(dt_notice, "%Y")))

  clean <- defor %>%
    filter(SIT_CANCELADO == "N", DES_STATUS_FORMULARIO == "Lavrado")

  stopifnot(
    "defor: unexpected row count" = nrow(defor) == N_IBAMA_DEFOR_AMAZON,
    "clean: unexpected row count" = nrow(clean) == N_IBAMA_DEFOR_CLEAN
  )

  list(ibama = ibama, defor = defor, clean = clean)
}

# -----------------------------------------------------------------------------
#### Shared palette, themes and quantile helper
# -----------------------------------------------------------------------------

QUINTILE_PALETTE <- c("1" = "#f5f0e1", "2" = "#e8d9a8", "3" = "#d9ae6a",
                      "4" = "#b9773a", "5" = "#7c4a20")

# One ramp per quantity across the suite: brown for deforestation, blue for
# the response, plum for the EGS. Hue is the only channel left to separate
# them, since lightness already encodes the quintile. Cf. viz/01_maps.R.
EGS_RAMP <- c("#d9b8cd", "#bd8fa9", "#996a86", "#734a64", "#4c2c42")

GAP_PALETTE <- c(absolute_gap = "#a63d2f", measured_gap = "#c98a3d",
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
#### Output folders
# -----------------------------------------------------------------------------

dir.create(PATH_OUT, showWarnings = FALSE, recursive = TRUE)

message("setup ok, ranking: ", nrow(ranking),
        " | final: ", nrow(final),
        " | annual: ", nrow(annual),
        " | mesh: ", nrow(muni_mesh))
