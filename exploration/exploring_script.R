

# =============================================================================
# Enforcement Gap Monitoring System
# Exploration Script
# IBAMA, PRODES & IPCA raw data
#
# Author:  Diogo Grieco
# Updated: v4-2026-07-10
# R version: 4.5.0 (2025-04-11 ucrt)
# RStudio version: 2026.06.0
#
# Purpose: Validate raw data quality, document analytical decisions (date 
#          column choice, join lag, filter logic), and produce inputs for the 
#          DuckDB pipeline.
# =============================================================================

# -----------------------------------------------------------------------------
# Calling packages
# -----------------------------------------------------------------------------

library(tidyverse)
library(scales)

# -----------------------------------------------------------------------------
# Setting paths and files
# -----------------------------------------------------------------------------

PATH_IBAMA    <- "data_ibama"
PATTERN_IBAMA <- "auto_infracao_ano_.*\\.csv"

PATH_PRODES   <- "data_prodes"
FILE_PRODES   <- "terrabrasilis_legal_amazon_25_04_2026_1777126839450.csv"

PATH_IPCA     <- "data_ipca"
FILE_IPCA     <- "sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv"

# -----------------------------------------------------------------------------
# Data integrity checkpoints
# -----------------------------------------------------------------------------

NROW_IBAMA_RAW      <- 309116
NCOL_IBAMA_RAW      <- 84
NROW_IBAMA_FILTERED <- 60707
TOTAL_IBAMA_MULTAS  <- 26814492927
NA_IBAMA_DATES      <- 0

NROW_PRODES_RAW     <- 14490
NCOL_PRODES_RAW     <- 5

N_GAP_ABSOLUTO      <- 3063
N_GAP_RECUPERADO_T1 <- 724
PCT_SENSIBILIDADE   <- 23.6

NROW_IPCA_RAW <- 216

# =============================================================================
# IBAMA DATA
#
# Aggregates multiple .csv files
# Explores infraction filters, dates, fines
# =============================================================================

# -----------------------------------------------------------------------------
# Encoding check
# -----------------------------------------------------------------------------

readr::guess_encoding(
  list.files(PATH_IBAMA, 
             PATTERN_IBAMA, 
             full.names = TRUE)[[1]])

# Result: UTF-8 (confidence 1.0) 
# Confirmed 2026-05-03

# -----------------------------------------------------------------------------
## Aggregating IBAMA files
# -----------------------------------------------------------------------------

read_ibama_files <- function(PATH_IBAMA, PATTERN_IBAMA) {
  list.files(PATH_IBAMA, 
             PATTERN_IBAMA, 
             full.names = TRUE) %>%
    map(read_delim,
        delim = ";",
        locale = locale(encoding = "UTF-8"),
        col_types = cols(.default = "c"),
        show_col_types = FALSE) %>%
    list_rbind()
}

ibama_raw <- read_ibama_files(PATH_IBAMA, PATTERN_IBAMA)

stopifnot(
  "ibama_raw: unexpected row count" =
    nrow(ibama_raw) == NROW_IBAMA_RAW,
  "ibama_raw: unexpected column count" =
    ncol(ibama_raw) == NCOL_IBAMA_RAW
  )

# -----------------------------------------------------------------------------
# Number of rows and columns
# -----------------------------------------------------------------------------

nrow(ibama_raw)
ncol(ibama_raw)

# Result: 
# 309.116 rows
# 84 columns
# Confirmed 2026-05-08

# -----------------------------------------------------------------------------
## Exploring infraction filters
# -----------------------------------------------------------------------------

# Empirical basis for filter decisions
#
# count(TIPO_INFRACAO)
#   Flora: 125,219 | Fauna: 50,855 | CTF: 36,249 | Controle Ambiental: 27,556
#   Pesca: 23,691 | NA: 11,895 | Outras: 11,282 | (outros < 10k)
#
# count(INFRACAO_AREA)
#   NA: 110,313 | Desmatamento: 102,265 | Outros: 36,900 | Atividade: 28,377
#   Não se Aplica: 24,631 | Queimada: 3,019 | Desmatamento e Queimada: 2,462
#   NAs concentrated 2008–2012
#   "Desmatamento e Queimada" (2,051 valid): 1,579/1,606 Flora records are
#   409999 — excluded for same reason as main filter (see below)
#
# count(DES_STATUS_FORMULARIO)
#   Lavrado: 291,748 | Cancelado: 12,262 | NA: 4,201 | (outros < 600)
#
# count(SIT_CANCELADO)
#   N: 293,104 | S: 16,012
#
# count(COD_INFRACAO)
#   356 distinct codes; 6 identified as deforestation-specific (see below)
#   409999 is the largest (77,872) — generic code, see exclusion rationale


CODIGOS_DESMATAMENTO <- c(
  "409907",  # Destruir, desmatar, danificar florestas ou vegetação nativa
  "409901",  # Destruir ou danificar florestas em APP
  "452001",  # Destruir/desmatar florestas em APP (art. 2º Lei 4.771)
  "430001",  # Desmatar florestas sem autorização IBAMA
  "431003",  # Destruir ou danificar florestas em áreas especiais (art. 225 CF)
  "468001"   # Destruir florestas nativas ou plantadas protetoras de mangues
)

ibama_filtered <- ibama_raw %>%
  filter(
    SIT_CANCELADO         == "N",
    DES_STATUS_FORMULARIO == "Lavrado",
    (
# Case 1: classic Flora + Desmatamento (58.051 records, pipeline v1)
      (TIPO_INFRACAO == "Flora" & INFRACAO_AREA == "Desmatamento") |
        
# Case 2: Flora, unclassified area, explicit deforestation code (2.129 records)
# All concentrated in 2008-2012, INFRACAO_AREA not mandatory in early years
        (TIPO_INFRACAO == "Flora" & 
           is.na(INFRACAO_AREA) &
           COD_INFRACAO %in% CODIGOS_DESMATAMENTO) |
        
# Case 3: unclassified type, area = Desmatamento (527 records)
# Same historical filling pattern as Case 2
        (is.na(TIPO_INFRACAO) & 
           INFRACAO_AREA == "Desmatamento")
  )
)

stopifnot(
  "ibama_filtered: unexpected row count" = 
    nrow(ibama_filtered) == NROW_IBAMA_FILTERED
)

# -----------------------------------------------------------------------------
## Exploring date filters
# -----------------------------------------------------------------------------

# Empirical basis for filter decisions

# NAs in ibama_filtered
# percent(sum(is.na(DAT_HORA_AUTO_INFRACAO))    = 0       selected
# percent(sum(is.na(DAT_CIENCIA_AUTUACAO))      = 12%
# percent(sum(is.na(DT_FATO_INFRACIONAL))       = 71%
# percent(sum(is.na(DT_INICIO_ATO_INEQUIVOCO))  = 71%
# percent(sum(is.na(DT_FIM_ATO_INEQUIVOCO))     = 71%

# -------------------------------------------------------------------------


# DAT_HORA_AUTO_INFRACAO: ISO 8601 (YYYY-MM-DD)

# sum(is.na(ymd(DAT_HORA_AUTO_INFRACAO))        = 0

ibama_filtered <- ibama_filtered %>%
  mutate(ano = year(ymd(DAT_HORA_AUTO_INFRACAO)))

stopifnot(
  "unexpected year NAs" = 
    sum(is.na(ibama_filtered$ano)) == NA_IBAMA_DATES
  )

# -----------------------------------------------------------------------------
## Exploring fine values
# -----------------------------------------------------------------------------

# Empirical basis for filter decisions

# Distribution (n = 60.707):
#   val_total = R$26,8bi | median = R$75.3k | mean = R$444k | 
#   p25=R$12.9k | p75 = R$290k | max = R$62,6M | n_0 = 5 | 
#   n_na = 356 (0,6%) | n_negative = 0

ibama_filtered <- ibama_filtered %>%
  mutate(
    geocode_ibge = COD_MUNICIPIO,
    val_multa    = as.numeric(str_replace(VAL_AUTO_INFRACAO, ",", "."))
  )

stopifnot(
  "incorrect total fine value" =
    isTRUE(all.equal(sum(ibama_filtered$val_multa, na.rm = TRUE), 
                     TOTAL_IBAMA_MULTAS))
)

# -----------------------------------------------------------------------------
## Exploring IBAMA internal lags
# -----------------------------------------------------------------------------

# Analysis 1: monthly distribution of drafting deeds (n = 60.707)
#   jan = 2.6% | fev = 5.3% | mar = 7.2% | abr = 8.4% | mai = 9.8% | 
#   jun = 9.6% | jul = 9.2% | ago = 9.6% | set = 11.1% | out = 10.3% | 
#   nov = 9.8% | dez = 7.1%
#   set-oct peak aligns with dry season
#   Non-decisive evidence for join t + 0 

# Analysis 2: internal lag IBAMA (DAT_HORA_AUTO_INFRACAO - DT_FATO)
# Base: n_lag = 17.642 (29% filtered); DT_FATO not excluded

#   n = 17.642 | median = 6 days | mean = 271 days | p75 = 285 days | 
#   p90 = 1.060 days | max = 7.984 days
#   355 records with lag < 0 discarded (recorded before fact)
#
# Analysis 3: lag per fine range (same n = 17.642)
#   range            n      median_fine
#   ≤7 days        8.954      R$95k
#   8–30 days      1.326      R$154k
#   31–365 days    3.321      R$284k   (peak)
#   1–2 years      1.217      R$215k
#   >2 years       2.469      R$155k
#   Pattern: higher-value operations have longer lags


# =============================================================================
# PRODES DATA
#
# Aggregates  .csv file
#
# prodes_raw: 14.490 rows,  5 columns
# =============================================================================

# Encoding check: 
# readr::guess_encoding(
#    file.path(PATH_PRODES, FILE_PRODES))

# Result: UTF-8 (confidence 1.0) confirmed 2026-05-07

# -----------------------------------------------------------------------------
## Importing PRODES file
# -----------------------------------------------------------------------------

prodes_raw <- read_delim(
  file.path(PATH_PRODES, FILE_PRODES),
  delim = ";",
  col_types      = cols(.default = "c"),
  show_col_types = FALSE
)

stopifnot(
  "prodes_raw: unexpected row count" =
    nrow(prodes_raw) == NROW_PRODES_RAW,
  "prodes_raw: unexpected column count" =
    ncol(prodes_raw) == NCOL_PRODES_RAW
)

# -----------------------------------------------------------------------------
# Cleaning PRODES data
# -----------------------------------------------------------------------------

prodes_clean <- prodes_raw %>%
  mutate(
    ano          = as.integer(year),
    area_km2     = as.numeric(str_replace(`area km²`, ",", "."))
  ) %>%
  select(geocode_ibge, mun, ano, area_km2)

stopifnot(
  "prodes_clean: row count alterado"    
  = nrow(prodes_clean)                     == NROW_PRODES_RAW,
  "prodes_clean: NAs em geocode_ibge"   
  = sum(is.na(prodes_clean$geocode_ibge))  == 0,
  "prodes_clean: NAs em ano"            
  = sum(is.na(prodes_clean$ano))           == 0,
  "prodes_clean: NAs em area_km2"       
  = sum(is.na(prodes_clean$area_km2))      == 0,
  "prodes_clean: municípios únicos"     
  = n_distinct(prodes_clean$geocode_ibge)  == 805,
  "prodes_clean: anos fora do range"    
  = all(prodes_clean$ano %in% 2008:2025)
)

# -----------------------------------------------------------------------------
# General exploring 
# -----------------------------------------------------------------------------

# municipios = 800 | geocode_ibge = 805 | 5 municipalities with same name
# years = 18 (2008-2025)

# quantiles(area_km2):
# min = 0 | p10 = 0 | p25 = 0 | median = 0.56 | p75 = 4.89 | p90 = 21.1 |
# max = 797


glimpse(prodes_clean)

# how many unique municipalities
prodes_clean %>%
  summarise(
    municipios = n_distinct(mun),
    anos       = n_distinct(ano),
    IBGE = n_distinct(geocode_ibge),
    total_rows = n()
  )

# distribution by year
prodes_clean %>%
  count(ano) %>%
  arrange(ano)

prodes_clean %>%
  summarise(
    n       = n(),
    min     = min(area_km2),
    p10     = quantile(area_km2, .10),
    p25     = quantile(area_km2, .25),
    mediana = median(area_km2),
    p75     = quantile(area_km2, .75),
    p90     = quantile(area_km2, .90),
    max     = max(area_km2)
  )

# =============================================================================
# Consistency checks 

# ibama_geocode_ibge = 2806 | prodes_geocode_ibge = 805 (Amazônia Legal)
# 2128 geocode_ibge presentes em ibama, mas não em prodes (outside Amazon)
# 127 geocode_ibge presente em prodes, mas não em ibama (no enforcement)
# 678 geocode_ibge presentes em ibama e prodes (enforcement)

# =============================================================================

# Coverage
codigos_prodes <- prodes_clean %>% distinct(geocode_ibge) %>% pull()
codigos_ibama  <- ibama_filtered %>% distinct(COD_MUNICIPIO) %>% pull()

# IBAMA but not PRODES
setdiff(codigos_ibama, codigos_prodes) %>% length()

# PRODES but no IBAMA
setdiff(codigos_prodes, codigos_ibama) %>% length()

codigos_ibama %>% length()
codigos_prodes %>% length()

# Intersection
intersect(codigos_ibama, codigos_prodes) %>% length()


# =============================================================================
# Exploring lags between IBAMA and PRODES

# Each: deforestation in the same year (t) or in previous year (t -)
#
# Resultado (n = 60.707; materialidade area >= 1):
#   só_t = 4.7% | só_t1 = 1.0% | ambos = 59.2% | nenhum = 35.1%
#   Same-year join confirmado. Confirmed 2026-07-10.
#
# pct_nenhum inflated by 2.128 geocodes outside Amazon

# =============================================================================

lag_check <- ibama_filtered %>%
  select(geocode_ibge, ano) %>%
  left_join(
    prodes_clean %>% select(geocode_ibge, ano, area_t = area_km2),
    by = c("geocode_ibge", "ano")
  ) %>%
  left_join(
    # t-1 deforestation: PRODES t+1
    prodes_clean %>%
      mutate(ano = ano + 1L) %>%
      select(geocode_ibge, ano, area_t1 = area_km2),
    by = c("geocode_ibge", "ano")
  ) %>%
  mutate(
    match_t  = !is.na(area_t)  & area_t  >= 1,
    match_t1 = !is.na(area_t1) & area_t1 >= 1
  )

# mutually exclusive categories - sum 100%
lag_check %>%
  summarise(
    n_total    = n(),
    pct_so_t   = round(mean(match_t  & !match_t1) * 100, 1),
    pct_so_t1  = round(mean(!match_t &  match_t1) * 100, 1),
    pct_ambos  = round(mean(match_t  &  match_t1) * 100, 1),
    pct_nenhum = round(mean(!match_t & !match_t1) * 100, 1)
  )

# =============================================================================
# Exploring sensitivity

# How many municipalities recovered if t+1 event were attibuted to t 
# deforestation?

# Resultado (materialidade area >= 1; resposta = val_multa >= 0.01):
#   gap = 3.063 (21.1% de 14.490) | recuperados = 724 | 23.6%
#   Confirmed 2026-07-10.
#
# Streaks >= 3 are robust; sohrt isolated cases are not.
# =============================================================================

municipios_gap <- prodes_clean %>%
  filter(area_km2 >= 1) %>%
  anti_join(ibama_filtered %>%
              filter(val_multa >= 0.01) %>%
              distinct(geocode_ibge, ano),
            by = c("geocode_ibge", "ano"))

gap_recuperado_t1 <- municipios_gap %>%
  semi_join(
    ibama_filtered %>%
      filter(val_multa >= 0.01) %>%
      transmute(geocode_ibge, ano = ano - 1L) %>%  
      distinct(),
    by = c("geocode_ibge", "ano")
  )

cat("Gap_absoluto (join t):        ", nrow(municipios_gap), "\n")
cat("Recuperados com join t+1:     ", nrow(gap_recuperado_t1), "\n")
cat("Percentual que mudaria:       ",
    round(nrow(gap_recuperado_t1) / nrow(municipios_gap) * 100, 1), "%\n")

stopifnot(
  "gap_absoluto: divergent count" =
    nrow(municipios_gap) == N_GAP_ABSOLUTO,
  "sensitivity t+1: divergent count" =
    nrow(gap_recuperado_t1) == N_GAP_RECUPERADO_T1
)

# =============================================================================
# Exploring IPCA

# IPCA: Sidra t.1737, v.2266, Brasil, jan/2008-dez/2025, download 2026-07-10
# Wide format with title and footnotes originally
# =============================================================================

ipca_raw <- read_delim(
  file.path(PATH_IPCA, FILE_IPCA),
  delim = ";", skip = 3, n_max = 1,
  col_types = cols(.default = "c"), show_col_types = FALSE
) %>%
  pivot_longer(-1, names_to = "mes", values_to = "indice") %>%
  mutate(
    ano    = as.integer(str_extract(mes, "\\d{4}$")),
    indice = as.numeric(str_replace(indice, ",", "."))
  )

stopifnot(
  "ipca_raw: NAs"                 = sum(is.na(ipca_raw$indice)) == 0,
  "ipca_raw: years out range"     = all(ipca_raw$ano %in% 2008:2025),
  "ipca_raw: 12 months"           = all(count(ipca_raw, ano)$n == 12),
  "ipca_raw: 216 lines"           = nrow(ipca_raw) == NROW_IPCA_RAW,
  "ipca_raw: 18 years"            = n_distinct(ipca_raw$ano) == 18
)

