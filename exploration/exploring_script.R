# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Exploration Script
# IBAMA, PRODES & IPCA raw data
#
# Author:  Diogo Grieco
# Updated: v4.4-2026-07-20 (merged the redesign-validation additions --
#          formerly drafted as exploring_script_additions_proposal.R --
#          into this file: egs_panel (unified EGS with denominator
#          floor), ranking-design decisions 1-4 with their stopifnot()
#          checkpoints, and the corresponding integrity constants.
#          Previously v4.3-2026-07-15.)
# R version: 4.5.0 (2025-04-11 ucrt)
# RStudio version: 2026.07.0
#
# Purpose: Validate raw data quality, document analytical decisions (date
#          column choice, join lag, filter logic), produce inputs for the
#          DuckDB pipeline, and record the empirical basis of the v5
#          ranking redesign (decisions 1-4, end of file).
# =============================================================================

# -----------------------------------------------------------------------------
#### Calling packages
# -----------------------------------------------------------------------------

library(tidyverse)

# -----------------------------------------------------------------------------
#### Setting paths and files
# -----------------------------------------------------------------------------

PATH_IBAMA    <- "data_ibama"
PATTERN_IBAMA <- "auto_infracao_ano_.*\\.csv"
PATH_PRODES   <- "data_prodes"
FILE_PRODES   <- "terrabrasilis_legal_amazon_25_04_2026_1777126839450.csv"
PATH_IPCA     <- "data_ipca"
FILE_IPCA     <- "sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv"

# -----------------------------------------------------------------------------
#### Data integrity checkpoints
# -----------------------------------------------------------------------------

NROW_IBAMA_RAW       <- 309116
NCOL_IBAMA_RAW       <- 84
NROW_IBAMA_FILTERED  <- 60707
TOTAL_IBAMA_FINES    <- 26814492927
NA_IBAMA_DATES       <- 0
NROW_PRODES_RAW      <- 14490
NCOL_PRODES_RAW      <- 5
N_ABSOLUTE_GAP       <- 3063
N_RECOVERED_GAP_T1   <- 724
NROW_IPCA_RAW        <- 216
NROW_IBAMA_LAG_BASE  <- 17642  
N_IBAMA_LAG_NEGATIVE <- 355    
NROW_IBAMA_LAG       <- 17287  

N_NO_PRESSURE          <- 8142   # area_km2 < 1 (56.2% of panel)
N_MEASURED_GAP         <- 3285   # complements N_ABSOLUTE_GAP (3,063)
N_FLOOR_ACTIVE         <- 28     # measured_gap years where raw denominator < 1
# (deflated fines; 61 with nominal — corrected 2026-07-20, prototype
# comment said 62; production check n_floor_active_nominal confirms 61)
N_RECLASS_MATERIALITY  <- 3291   # panel rows with 0.0625 <= area_km2 < 1
N_MUNI_WITH_PRESSURE   <- 552    # municipalities with >= 1 pressure year


# =============================================================================
#### IBAMA DATA
#
# Aggregates multiple .csv files
# Explores infraction filters, dates, fines
# =============================================================================

# -----------------------------------------------------------------------------
#### Encoding check

# Result: UTF-8 (confidence 1.0)
# Confirmed 2026-05-03
# -----------------------------------------------------------------------------

readr::guess_encoding(
  list.files(PATH_IBAMA,
             PATTERN_IBAMA,
             full.names = TRUE)[[1]])

# -----------------------------------------------------------------------------
#### Aggregating IBAMA files
# -----------------------------------------------------------------------------

read_ibama_files <- function(path_ibama, pattern_ibama) {
  list.files(path_ibama,
             pattern_ibama,
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
#### Number of rows and columns

# Result:
# 309,116 rows
# 84 columns
# Confirmed 2026-05-08
# -----------------------------------------------------------------------------

nrow(ibama_raw)
ncol(ibama_raw)

# -----------------------------------------------------------------------------

#### Exploring infraction filters
# Empirical basis for filter decisions
#
# count(TIPO_INFRACAO)
#   Flora: 125,219 | Fauna: 50,855 | CTF: 36,249 | Controle Ambiental: 27,556
#   Pesca: 23,691 | NA: 11,895 | Outras: 11,282 | (others < 10k)
#
# count(INFRACAO_AREA)
#   NA: 110,313 | Desmatamento: 102,265 | Outros: 36,900 | Atividade: 28,377
#   Não se Aplica: 24,631 | Queimada: 3,019 | Desmatamento e Queimada: 2,462
#   NAs concentrated 2008–2012
#   "Desmatamento e Queimada" (2,051 valid): 1,579/1,606 Flora records are
#   409999 — excluded for same reason as main filter (see below)
#
# count(DES_STATUS_FORMULARIO)
#   Lavrado: 291,748 | Cancelado: 12,262 | NA: 4,201 | (others < 600)
#
# count(SIT_CANCELADO)
#   N: 293,104 | S: 16,012
#
# count(COD_INFRACAO)
#   356 distinct codes; 6 identified as deforestation-specific (see below)
#   409999 is the largest (77,872) — generic code, see exclusion rationale
# -----------------------------------------------------------------------------

DEFORESTATION_CODES <- c(
  "409907",  # Destroy, clear, or damage native forests or vegetation
  "409901",  # Destroy or damage forests in permanent preservation areas (APP)
  "452001",  # Destroy/clear forests in APP (art. 2, Law 4,771)
  "430001",  # Clear forests without IBAMA authorization
  "431003",  # Destroy or damage forests in specially protected areas (art. 225, Federal Constitution)
  "468001"   # Destroy native or planted mangrove-protecting forests
)

ibama_filtered <- ibama_raw %>%
  filter(
    SIT_CANCELADO         == "N",
    DES_STATUS_FORMULARIO == "Lavrado",
    (
      # Case 1: classic Flora + Desmatamento (58,051 records, pipeline v1)
      (TIPO_INFRACAO == "Flora" & INFRACAO_AREA == "Desmatamento") |
        
        # Case 2: Flora, unclassified area, explicit deforestation code (2,129 records)
        # All concentrated in 2008-2012, INFRACAO_AREA not mandatory in early years
        (TIPO_INFRACAO == "Flora" &
           is.na(INFRACAO_AREA) &
           COD_INFRACAO %in% DEFORESTATION_CODES) |
        
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
#### Exploring date filters

# Empirical basis for filter decisions
# NAs in ibama_filtered
# percent(sum(is.na(DAT_HORA_AUTO_INFRACAO))    = 0       selected
# percent(sum(is.na(DAT_CIENCIA_AUTUACAO))      = 12%
# percent(sum(is.na(DT_FATO_INFRACIONAL))       = 71%
# percent(sum(is.na(DT_INICIO_ATO_INEQUIVOCO))  = 71%
# percent(sum(is.na(DT_FIM_ATO_INEQUIVOCO))     = 71%
# DAT_HORA_AUTO_INFRACAO: ISO 8601 (YYYY-MM-DD)
# sum(is.na(ymd(DAT_HORA_AUTO_INFRACAO))        = 0
# -------------------------------------------------------------------------

ibama_filtered <- ibama_filtered %>%
  mutate(year = year(ymd(DAT_HORA_AUTO_INFRACAO)))

stopifnot(
  "unexpected year NAs" =
    sum(is.na(ibama_filtered$year)) == NA_IBAMA_DATES
)

# -----------------------------------------------------------------------------
#### Exploring fine values

# Empirical basis for filter decisions
# Distribution (n = 60,707):
#   total = R$26.8bn | median = R$75.3k | mean = R$444k |
#   p25=R$12.9k | p75 = R$290k | max = R$62.6M | n_0 = 5 |
#   n_na = 356 (0.6%) | n_negative = 0
# -----------------------------------------------------------------------------

ibama_filtered <- ibama_filtered %>%
  mutate(
    geocode_ibge = COD_MUNICIPIO,
    fine_value   = as.numeric(str_replace(VAL_AUTO_INFRACAO, ",", "."))
  )

stopifnot(
  "incorrect total fine value" =
    isTRUE(all.equal(sum(ibama_filtered$fine_value, na.rm = TRUE),
                     TOTAL_IBAMA_FINES))
)

# -----------------------------------------------------------------------------
#### Exploring IBAMA internal lags

# Analysis 1: monthly distribution of drafting deeds (n = 60,707)

#   Jan = 2.6% | Feb = 5.3% | Mar = 7.2% | Apr = 8.4% | May = 9.8% |
#   Jun = 9.6% | Jul = 9.2% | Aug = 9.6% | Sep = 11.1% | Oct = 10.3% |
#   Nov = 9.8% | Dec = 7.1%
#   Sep-Oct peak aligns with dry season
#   Non-decisive evidence for join t + 0
# -----------------------------------------------------------------------------

ibama_filtered %>%
  mutate(month = month(ymd(DAT_HORA_AUTO_INFRACAO))) %>%
  count(month) %>%
  mutate(pct = round(n / sum(n) * 100, 1)) %>%
  arrange(month)

# -----------------------------------------------------------------------------
# Analysis 2: internal lag IBAMA (DAT_HORA_AUTO_INFRACAO - DT_FATO)

# Base: n_lag = 17,642 (29% non-NA DT_FATO); 355 records with lag < 0
# discarded (recorded before fact) -> n = 17,287 analyzed below
#   n = 17,287 | median = 6 days | mean = 278 days | p75 = 295 days |
#   p90 = 1,077 days | max = 7,984 days
# -----------------------------------------------------------------------------

ibama_lag <- ibama_filtered %>%
  transmute(
    lag_days = as.numeric(ymd(DAT_HORA_AUTO_INFRACAO) - ymd(DT_FATO_INFRACIONAL)),
    fine_value
  ) %>%
  filter(!is.na(lag_days))

stopifnot(
  "ibama_lag: unexpected base row count" =
    nrow(ibama_lag) == NROW_IBAMA_LAG_BASE,
  "ibama_lag: unexpected negative-lag count" =
    sum(ibama_lag$lag_days < 0) == N_IBAMA_LAG_NEGATIVE
)

ibama_lag <- ibama_lag %>%
  filter(lag_days >= 0)

stopifnot(
  "ibama_lag: unexpected row count after discarding negatives" =
    nrow(ibama_lag) == NROW_IBAMA_LAG
)

ibama_lag %>%
  summarise(
    n      = n(),
    median = median(lag_days),
    mean   = round(mean(lag_days), 0),
    p75    = quantile(lag_days, .75),
    p90    = quantile(lag_days, .90),
    max    = max(lag_days)
  )

# -----------------------------------------------------------------------------
# Analysis 3: lag per fine range (n = 17,287)

#   range            n      median_fine
#   ≤7 days        8,954      R$95k
#   8–30 days      1,326      R$154k
#   31–365 days    3,321      R$283.5k  (peak)
#   1–2 years      1,217      R$215k
#   >2 years       2,469      R$155k
#   Pattern: higher-value operations have longer lags
# -----------------------------------------------------------------------------

ibama_lag %>%
  mutate(
    lag_bucket = case_when(
      lag_days <= 7   ~ "<=7 days",
      lag_days <= 30  ~ "8-30 days",
      lag_days <= 365 ~ "31-365 days",
      lag_days <= 730 ~ "1-2 years",
      TRUE            ~ ">2 years"
    ),
    lag_bucket = factor(lag_bucket, levels = c(
      "<=7 days", "8-30 days", "31-365 days", "1-2 years", ">2 years"
    ))
  ) %>%
  group_by(lag_bucket) %>%
  summarise(n = n(), median_fine = median(fine_value, na.rm = TRUE)) %>%
  arrange(lag_bucket)

# =============================================================================
#### PRODES DATA
#
# Aggregates  .csv file
# prodes_raw: 14,490 rows,  5 columns
# =============================================================================

# -----------------------------------------------------------------------------
#### Encoding check

# Result: UTF-8 (confidence 1.0)
# Confirmed 2026-05-07
# -----------------------------------------------------------------------------

readr::guess_encoding(
  file.path(PATH_PRODES, FILE_PRODES))

# -----------------------------------------------------------------------------
#### Importing PRODES file
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
#### Cleaning PRODES data
# -----------------------------------------------------------------------------

prodes_clean <- prodes_raw %>%
  mutate(
    year         = as.integer(year),
    area_km2     = as.numeric(str_replace(`area km²`, ",", "."))
  ) %>%
  select(geocode_ibge, mun, year, area_km2)

stopifnot(
  "prodes_clean: unexpected row count" =
    nrow(prodes_clean) == NROW_PRODES_RAW,
  "prodes_clean: NAs in geocode_ibge" =
    sum(is.na(prodes_clean$geocode_ibge)) == 0,
  "prodes_clean: NAs in year" =
    sum(is.na(prodes_clean$year)) == 0,
  "prodes_clean: NAs in area_km2" =
    sum(is.na(prodes_clean$area_km2)) == 0,
  "prodes_clean: unique municipalities" =
    n_distinct(prodes_clean$geocode_ibge) == 805,
  "prodes_clean: years out of range" =
    all(prodes_clean$year %in% 2008:2025)
)

# -----------------------------------------------------------------------------
#### General exploring

# municipalities = 800 | geocode_ibge = 805 | 5 municipalities with same name
# years = 18 (2008-2025)

# quantiles(area_km2):
# min = 0 | p10 = 0 | p25 = 0 | median = 0.56 | p75 = 4.89 | p90 = 21.1 |
# max = 797

# Structural check against the official INPE rate, 4 anchor years:
# 2008 +2.9% | 2012 -3.2% | 2024 -0.4% (all within ~3%); 2025 diverges
# -8.3% to -9.3% -- likely a preliminary (unconsolidated) PRODES figure
# for the in-progress year ("last year subject to revision", Fix S9).
# (Corrected 2026-07-20: this comment previously claimed "diff. <5%"
# for all four anchors, which the 2025 anchor does not meet.)
#   2008: 12,911 official vs 13,289 here | 2012: ~4,571 vs 4,427
#   2024: 6,288 vs 6,263 | 2025: 5,731-5,796 vs 5,258
# Median drop 2008->2009 (2.31 -> 0.87) coincides with CMN Resolution
# 3,545/2008 (rural credit restriction on embargoed areas), not with a
# change in INPE's sensor/methodology. Closed 2026-07-12 (Fix 15).
# -----------------------------------------------------------------------------

glimpse(prodes_clean)
prodes_clean %>%
  summarise(
    municipalities = n_distinct(mun),
    years          = n_distinct(year),
    IBGE           = n_distinct(geocode_ibge),
    total_rows     = n()
  )

prodes_clean %>%
  count(year) %>%
  arrange(year)

prodes_clean %>%
  group_by(year) %>%
  summarise(
    total_km2  = sum(area_km2),
    median_km2 = median(area_km2),
    mean_km2   = mean(area_km2)
  ) %>%
  arrange(year)

prodes_clean %>%
  summarise(
    n       = n(),
    min     = min(area_km2),
    p10     = quantile(area_km2, .10),
    p25     = quantile(area_km2, .25),
    median  = median(area_km2),
    p75     = quantile(area_km2, .75),
    p90     = quantile(area_km2, .90),
    max     = max(area_km2)
  )

# -----------------------------------------------------------------------------
#### Consistency checks

# ibama_geocode_ibge = 2,806 | prodes_geocode_ibge = 805 (Legal Amazon)
# 2,128 geocode_ibge present in ibama but not in prodes (outside Amazon)
# 127 geocode_ibge present in prodes but not in ibama (no enforcement)
# 678 geocode_ibge present in both ibama and prodes (enforcement)
# -----------------------------------------------------------------------------

# Coverage
prodes_codes <- prodes_clean %>%
  distinct(geocode_ibge) %>%
  pull()

ibama_codes  <- ibama_filtered %>%
  distinct(COD_MUNICIPIO) %>%
  pull()

# IBAMA but not PRODES
setdiff(ibama_codes, prodes_codes) %>%
  length()
# PRODES but no IBAMA
setdiff(prodes_codes, ibama_codes) %>%
  length()

ibama_codes %>% length()

prodes_codes %>% length()

# Intersection
intersect(ibama_codes, prodes_codes) %>%
  length()

# =============================================================================
#### Exploring lags between IBAMA and PRODES

# Each: deforestation in the same year (t) or in previous year (t - 1)
#
# Result (n = 60,707; materiality area >= 1):
#   only_t = 4.7% | only_t1 = 1.0% | both = 59.2% | neither = 35.1%
#   Same-year join confirmed. Confirmed 2026-07-10.
#
# pct_neither inflated by 2,128 geocodes outside Amazon
# =============================================================================

lag_check <- ibama_filtered %>%
  select(geocode_ibge, year) %>%
  left_join(
    prodes_clean %>% select(geocode_ibge, year, area_t = area_km2),
    by = c("geocode_ibge", "year")
  ) %>%
  left_join(
    # t-1 deforestation: PRODES t+1
    prodes_clean %>%
      mutate(year = year + 1L) %>%
      select(geocode_ibge, year, area_t1 = area_km2),
    by = c("geocode_ibge", "year")
  ) %>%
  mutate(
    match_t  = !is.na(area_t)  & area_t  >= 1,
    match_t1 = !is.na(area_t1) & area_t1 >= 1
  )

# Mutually exclusive categories - sum 100%
lag_check %>%
  summarise(
    n_total     = n(),
    pct_only_t  = round(mean(match_t  & !match_t1) * 100, 1),
    pct_only_t1 = round(mean(!match_t &  match_t1) * 100, 1),
    pct_both    = round(mean(match_t  &  match_t1) * 100, 1),
    pct_neither = round(mean(!match_t & !match_t1) * 100, 1)
  )

# =============================================================================
#### Exploring sensitivity

# How many municipalities recovered if t+1 event attributed to t
# deforestation?
# Result (materiality area >= 1; response = fine_value >= 0.01):
#   absolute_gap = 3,063 (21.1% of 14,490) | recovered = 724 | 23.6%
#   Confirmed 2026-07-10.
# =============================================================================

absolute_gap_cases <- prodes_clean %>%
  filter(area_km2 >= 1) %>%
  anti_join(ibama_filtered %>%
              filter(fine_value >= 0.01) %>%
              distinct(geocode_ibge, year),
            by = c("geocode_ibge", "year"))

recovered_gap_t1 <- absolute_gap_cases %>%
  semi_join(
    ibama_filtered %>%
      filter(fine_value >= 0.01) %>%
      transmute(geocode_ibge, year = year - 1L) %>%
      distinct(),
    by = c("geocode_ibge", "year")
  )

cat("Absolute gap (join t):        ", nrow(absolute_gap_cases), "\n")
cat("Recovered with t+1 join:      ", nrow(recovered_gap_t1), "\n")
cat("Percent that would change:    ",
    round(nrow(recovered_gap_t1) / nrow(absolute_gap_cases) * 100, 1), "%\n")
stopifnot(
  "absolute_gap: divergent count" =
    nrow(absolute_gap_cases) == N_ABSOLUTE_GAP,
  "sensitivity t+1: divergent count" =
    nrow(recovered_gap_t1) == N_RECOVERED_GAP_T1
)

# =============================================================================
#### Exploring IPCA

# IPCA: Sidra t.1737, v.2266, Brazil, Jan/2008-Dec/2025, download 2026-07-10
# Wide format with title and footnotes originally
# =============================================================================

ipca_raw <- read_delim(
  file.path(PATH_IPCA, FILE_IPCA),
  delim = ";", skip = 3, n_max = 1,
  col_types = cols(.default = "c"), show_col_types = FALSE
) %>%
  pivot_longer(-1, names_to = "month", values_to = "index") %>%
  mutate(
    year  = as.integer(str_extract(month, "\\d{4}$")),
    index = as.numeric(str_replace(index, ",", "."))
  )

stopifnot(
  "ipca_raw: NAs"                 = sum(is.na(ipca_raw$index)) == 0,
  "ipca_raw: years out range"     = all(ipca_raw$year %in% 2008:2025),
  "ipca_raw: 12 months"           = all(count(ipca_raw, year)$n == 12),
  "ipca_raw: 216 lines"           = nrow(ipca_raw) == NROW_IPCA_RAW,
  "ipca_raw: 18 years"            = n_distinct(ipca_raw$year) == 18)
  
ipca_deflator <- ipca_raw %>%
  group_by(year) %>%
  summarise(avg_index = mean(index), .groups = "drop") %>%
  mutate(deflator = avg_index[year == 2025] / avg_index) %>%
  select(year, deflator)
  
  egs_panel <- prodes_clean %>%
    left_join(
      ibama_filtered %>%
        group_by(geocode_ibge, year) %>%
        summarise(
          n_infractions       = n(),
          fine_values_nominal = sum(fine_value, na.rm = TRUE),
          .groups = "drop"
        ),
      by = c("geocode_ibge", "year")
    ) %>%
    mutate(
      n_infractions       = coalesce(n_infractions, 0L),
      fine_values_nominal = coalesce(fine_values_nominal, 0)
    ) %>%
    left_join(ipca_deflator, by = "year") %>%
    mutate(
      fine_values = fine_values_nominal * deflator,
      gap_type = case_when(
        area_km2    < 1    ~ "no_pressure",
        fine_values < 0.01 ~ "absolute_gap",
        TRUE               ~ "measured_gap"
      ),
      # NEW unified EGS: floored denominator; materiality years contribute 0.
      # For absolute_gap the raw denominator is 0 -> floored to 1 -> EGS
      # collapses to log10(1 + area): the old two-branch CASE is now a
      # mathematical consequence, not a rule.
      denom_raw = sqrt(log10(1 + n_infractions) * log10(1 + fine_values)),
      egs       = if_else(area_km2 < 1, 0,
                          log10(1 + area_km2) / pmax(1, denom_raw))
    )
  
  stopifnot(
    "egs_panel: unexpected row count" =
      nrow(egs_panel) == NROW_PRODES_RAW,
    "egs_panel: no_pressure count" =
      sum(egs_panel$gap_type == "no_pressure") == N_NO_PRESSURE,
    "egs_panel: absolute_gap count" =
      sum(egs_panel$gap_type == "absolute_gap") == N_ABSOLUTE_GAP,
    "egs_panel: measured_gap count" =
      sum(egs_panel$gap_type == "measured_gap") == N_MEASURED_GAP,
    "egs_panel: EGS NAs" =
      sum(is.na(egs_panel$egs)) == 0
  )

# =============================================================================
#### Empirical basis for ranking design
# =============================================================================

  # -----------------------------------------------------------------------------
  #### Decision 1 — denominator floor: how often does it bind?
  
  # Result (deflated fines): floor binds in 28/3,285 measured_gap years (0.9%);
  # raw denominator in measured_gap: min = 0.796 | p25 = 1.55 | median = 2.06 |
  # max = 4.56. The floor is inert for the mass of the data and only clips the
  # R$0.01-boundary instability cases (fix S10). With nominal fines it binds
  # 61 times (corrected 2026-07-20; the prototype comment said 62 — never
  # asserted, now fixed by the SQL check n_floor_active_nominal = 61) —
  # deflation itself moves half the cases out of the unstable
  # zone. Confirmed 2026-07-20.
  # -----------------------------------------------------------------------------
  
  egs_panel %>%
    filter(gap_type == "measured_gap") %>%
    summarise(
      n_floor_active = sum(denom_raw < 1),
      min    = min(denom_raw),
      p25    = quantile(denom_raw, .25),
      median = median(denom_raw),
      max    = max(denom_raw)
    )
  
  stopifnot(
    "floor: unexpected active count" =
      egs_panel %>%
      filter(gap_type == "measured_gap", denom_raw < 1) %>%
      nrow() == N_FLOOR_ACTIVE
  )





  # -----------------------------------------------------------------------------
  #### Decision 2 — materiality threshold: ranking sensitivity
  
  # Result: ranking by 0-fill mean EGS computed under three thresholds
  # (1 km2 | 6.25 ha = PRODES minimum mapping unit | none) gives IDENTICAL
  # top 10/20/50 and Spearman = 0.985 across all 805 municipalities — although
  # 3,291 rows (22.7%) are reclassified between thresholds. The threshold
  # affects the descriptive statistic (56.2% no_pressure), not the ranking.
  # Citable as a robustness result. Confirmed 2026-07-20.
  # -----------------------------------------------------------------------------
  
  rank_by_threshold <- function(panel, threshold) {
    panel %>%
      mutate(egs_t = if_else(area_km2 < threshold, 0,
                             log10(1 + area_km2) / pmax(1, denom_raw))) %>%
      group_by(geocode_ibge) %>%
      summarise(avg_egs = mean(egs_t), .groups = "drop") %>%
      mutate(rank = min_rank(desc(avg_egs)))
  }
  
  rank_1km   <- rank_by_threshold(egs_panel, 1)
  rank_625ha <- rank_by_threshold(egs_panel, 0.0625)
  rank_none  <- rank_by_threshold(egs_panel, 0)
  
  overlap_top_n <- function(a, b, n) {
    length(intersect(
      a %>% slice_min(rank, n = n, with_ties = FALSE) %>% pull(geocode_ibge),
      b %>% slice_min(rank, n = n, with_ties = FALSE) %>% pull(geocode_ibge)
    ))
  }
  
  tibble(
    top_n           = c(10, 20, 50),
    vs_625ha        = map_int(top_n, ~ overlap_top_n(rank_1km, rank_625ha, .x)),
    vs_no_threshold = map_int(top_n, ~ overlap_top_n(rank_1km, rank_none, .x))
  )
  
  cor(rank_1km$rank, rank_625ha$rank, method = "spearman")
  
  stopifnot(
    "materiality: unexpected reclassification count" =
      egs_panel %>%
      filter(area_km2 >= 0.0625, area_km2 < 1) %>%
      nrow() == N_RECLASS_MATERIALITY
  )
  
  
 # -----------------------------------------------------------------------------
    #### Decision 3 — 0-fill mean as main ordering
    
    # Identity: mean_0fill == mean(EGS | pressure years) * frac(pressure years).
    # The 0-fill mean IS the severity x frequency composite, written as one
    # formula — the design choice is explicit here, not hidden.
    #
    # Result (552 municipalities with >= 1 pressure year, deflated):
    #   Pearson(severity, frequency) = 0.621 | Spearman = 0.696
    #   -> the two dimensions largely co-move; top-10 overlap between pure
    #      severity and 0-fill = 9/10.
    #   Only divergent case: Nova Nazare (MT) — highest pure severity of the
    #   dataset (1.384; isolated episodes of 11 km2 in 2008 and 63 km2 in 2017,
    #   2/18 pressure years) drops to 0.154 under 0-fill and leaves the top 10.
    #   EDITORIAL DECISION, kept: a persistent-gap monitoring system demotes
    #   point events; documented as the worked example of the metric's limits
    #   (same register as the Barra do Bugres case).
    #   Confirmed 2026-07-20.
    # -----------------------------------------------------------------------------
  
  muni_ranking <- egs_panel %>%
    group_by(geocode_ibge, mun) %>%
    summarise(
      avg_egs_18y     = mean(egs),
      n_years_pressure = sum(gap_type != "no_pressure"),
      total_area_km2  = sum(area_km2),
      n_infractions   = sum(n_infractions),
      total_fines     = sum(fine_values),
      .groups = "drop"
    ) %>%
    mutate(frac_pressure = n_years_pressure / n_distinct(egs_panel$year))
  
  muni_qualified <- muni_ranking %>%
    filter(n_years_pressure > 0) %>%
    mutate(avg_egs_pressure_years = avg_egs_18y / frac_pressure)
  
  stopifnot(
    "0-fill identity broken" =
      isTRUE(all.equal(
        muni_qualified$avg_egs_18y,
        muni_qualified$avg_egs_pressure_years * muni_qualified$frac_pressure
      )),
    "unexpected qualified-municipality count" =
      nrow(muni_qualified) == N_MUNI_WITH_PRESSURE
  )
  
  muni_qualified %>%
    summarise(
      pearson  = cor(avg_egs_pressure_years, frac_pressure),
      spearman = cor(avg_egs_pressure_years, frac_pressure, method = "spearman")
    )
  

  #### Decision 4 — current situation: recent mean AND OLS slope
  
  # Result: slope alone is a weak recency signal when few years are non-zero —
  # Palmeiras do Tocantins (single event, 2024): slope = +0.005
  # Nova Nazare (events 2008/2017):              slope = -0.017
  # The "new problem" vs "old, closed problem" distinction lives in the second
  # decimal place. Both columns kept BUT read alongside n_years_pressure as a
  # reliability indicator; recent mean (2023-2025) is the legible companion.
  # NOTE: window includes 2025 — last panel year subject to revision (PRODES
  # estimate not consolidated at download date). Confirmed 2026-07-20.
  # -----------------------------------------------------------------------------
  
  muni_current <- egs_panel %>%
    group_by(geocode_ibge, mun) %>%
    summarise(
      avg_egs_3y = mean(egs[year >= 2023]),
      slope_egs  = cov(year, egs) / var(year),   # OLS slope, full 18-year panel
      .groups = "drop"
    )
  
  final_table <- muni_ranking %>%
    left_join(muni_current, by = c("geocode_ibge", "mun")) %>%
    arrange(desc(avg_egs_18y))
  
  # Top of final table (deflated), for cross-checking the SQL implementation:
  #   Cachoeira do Piria (PA): avg18 = 1.179 | avg3y = 1.228 | slope = -0.010
  #   Porto de Moz (PA):       avg18 = 1.175 | avg3y = 0.930 | slope = -0.014
  #   Aveiro (PA):             avg18 = 1.109 | avg3y = 1.508 | slope = +0.042
  #   (top 15 entirely 18/18 pressure years; see egms_tabela_final_prototipo.csv)
  
  final_table %>% slice_head(n = 15)
