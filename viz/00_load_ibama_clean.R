# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite — 00 load raw IBAMA (shared)
#
# Author: Diogo Grieco
#
# Purpose: Single source of truth for reading + filtering the raw IBAMA CSVs,
#          shared by 04_raw_ibama.R (report figures 7-11) and 06_offender_network.R
#          (item 18) — both need the same deforestation-type filter over the
#          same raw notices, and keeping one copy of that filter means the two
#          scripts can't silently drift apart if it's ever revised.
#          Not sourced by 00_setup.R: reading the 18 yearly CSVs is the
#          slowest step in this suite, so only the two scripts that actually
#          need it pay the cost. load_ibama_clean() builds its own cache if
#          missing — call it directly, no run-order requirement on either
#          script that uses it.
# =============================================================================

library(readr)

FILE_RAW_CACHE <- "viz_ibama_amazon_raw.parquet"   # filtered raw notices (cache)

# Columns actually used downstream (of the 84 raw columns).
IBAMA_COLS <- c("COD_MUNICIPIO","UF","DAT_HORA_AUTO_INFRACAO","DT_FATO_INFRACIONAL",
                "CD_TERMOS_EMBARGOS","CD_TERMOS_APREENSAO","SIT_CANCELADO",
                "DES_STATUS_FORMULARIO","TIPO_INFRACAO","INFRACAO_AREA",
                "COD_INFRACAO","CPF_CNPJ_INFRATOR","VAL_AUTO_INFRACAO")

# Deforestation-type COD_INFRACAO set (mirrors marts.ibama_clean, case 2).
DEFORESTATION_CODES <- c("409907","409901","452001","430001","431003","468001")

# Returns list(ibama, defor, clean):
#   ibama - raw notices, filtered to the 772 panel municipalities
#   defor - ibama, filtered to deforestation-type (mirrors marts.ibama_clean, 3 cases)
#   clean - defor, filtered to SIT_CANCELADO == "N" & DES_STATUS_FORMULARIO == "Lavrado"
#           (same status filter as the pipeline; does NOT drop NA CPF_CNPJ_INFRATOR —
#           callers that need a valid offender id, e.g. 07, filter that locally)
load_ibama_clean <- function() {
  raw_cache_path <- file.path(PATH_CACHE, FILE_RAW_CACHE)
  panel_geocodes <- unique(ranking$geocode_ibge)

  if (file.exists(raw_cache_path)) {
    ibama <- arrow::read_parquet(raw_cache_path)
  } else {
    files <- list.files(PATH_IBAMA, pattern = PATTERN_IBAMA, full.names = TRUE)
    ibama <- purrr::map_dfr(files, function(f) {
      readr::read_delim(f, delim = ";", locale = locale(encoding = "UTF-8"),
                        col_types = cols(.default = "c"), show_col_types = FALSE) %>%
        select(any_of(IBAMA_COLS)) %>%
        filter(COD_MUNICIPIO %in% panel_geocodes)   # keep only the 772 panel munis
    })
    arrow::write_parquet(ibama, raw_cache_path)
  }

  stopifnot("ibama: unexpected Amazon row count" = nrow(ibama) == N_IBAMA_AMAZON)

  is_defor <-
    (ibama$TIPO_INFRACAO == "Flora" & ibama$INFRACAO_AREA == "Desmatamento") |
    (ibama$TIPO_INFRACAO == "Flora" & is.na(ibama$INFRACAO_AREA) &
       ibama$COD_INFRACAO %in% DEFORESTATION_CODES) |
    (is.na(ibama$TIPO_INFRACAO) & ibama$INFRACAO_AREA == "Desmatamento")
  is_defor[is.na(is_defor)] <- FALSE
  defor <- ibama[is_defor, ]

  defor <- defor %>%
    mutate(fine_value = suppressWarnings(as.numeric(str_replace(VAL_AUTO_INFRACAO, ",", "."))),
           dt_notice  = suppressWarnings(as.Date(DAT_HORA_AUTO_INFRACAO)),
           dt_fact    = suppressWarnings(as.Date(DT_FATO_INFRACIONAL)),
           year       = as.integer(format(dt_notice, "%Y")))

  clean <- defor %>% filter(SIT_CANCELADO == "N", DES_STATUS_FORMULARIO == "Lavrado")

  stopifnot(
    "defor: unexpected deforestation-type count"      = nrow(defor) == N_IBAMA_DEFOR_AMAZON,
    "clean: unexpected clean deforestation-type count" = nrow(clean) == N_IBAMA_DEFOR_CLEAN
  )

  list(ibama = ibama, defor = defor, clean = clean)
}
