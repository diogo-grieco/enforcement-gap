# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Exploration Script
# IBAMA, PRODES & IPCA raw data
#
# Author: Diogo Grieco
#
# Purpose: Validate raw data quality, document the empirical basis of
#          analytical design (date column choice, join lag, filter logic),
#          and cross-check the DuckDB pipeline with an implementation in R.
#
# Structure:
#   Part I    Construction: raw files to analytical objects, mirroring the SQL
#             pipeline; every checkpoint pinned to a constant.
#   Part II   Description: what the constructed objects contain.
#   Part III  Design tests: what changes under alternative choices. Each
#             block names the report section that argues the decision.
# =============================================================================

# -----------------------------------------------------------------------------
#### Calling packages
# -----------------------------------------------------------------------------

library(tidyverse)

# -----------------------------------------------------------------------------
#### Setting paths and files
# -----------------------------------------------------------------------------

PATH_IBAMA    <- "data/data_ibama_public"
PATTERN_IBAMA <- "auto_infracao_ano_.*\\.csv"
PATH_PRODES   <- "data/data_prodes"
FILE_PRODES   <- "terrabrasilis_legal_amazon_25_04_2026_1777126839450.csv"
PATH_IPCA     <- "data/data_ipca"
FILE_IPCA     <- "sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv"

# -----------------------------------------------------------------------------
#### Data integrity checkpoints
# -----------------------------------------------------------------------------

# STAGING (raw)
NROW_IBAMA_RAW           <- 309116
NCOL_IBAMA_RAW           <- 13
NROW_PRODES_RAW          <- 14490
NCOL_PRODES_RAW          <- 5

# MARTS (cleaned)
NROW_IBAMA_FILTERED      <- 60707
TOTAL_IBAMA_FINES        <- 26814492927
NA_IBAMA_DATES           <- 0
NROW_PRODES_CLEAN        <- 13896
N_GEOCODES_PRODES_CLEAN  <- 772
N_OUT_OF_SCOPE_GEOCODES  <- 33
NROW_IPCA_LONG           <- 216

# ANALYTICS (EGS, ranking)
N_ABSOLUTE_GAP           <- 3063
N_RECOVERED_GAP_T1       <- 724
N_NO_PRESSURE            <- 7548
N_MEASURED_GAP           <- 3285
N_FLOOR_ACTIVE           <- 28
N_RECLASS_MATERIALITY    <- 3291
N_MUNI_WITH_PRESSURE     <- 552

# DESCRIPTION ONLY (no counterpart in the SQL pipeline)
NROW_IBAMA_LAG_BASE      <- 17642
N_IBAMA_LAG_NEGATIVE     <- 355
NROW_IBAMA_LAG           <- 17287


# #############################################################################
# PART I. CONSTRUCTION
# #############################################################################

# =============================================================================
#### I.1 IBAMA: read and filter
# =============================================================================

# -----------------------------------------------------------------------------
#### Encoding check (IBAMA)

# Result: UTF-8 (confidence 1.0)
# Confirmed 2026-05-03
# -----------------------------------------------------------------------------

readr::guess_encoding(
  list.files(PATH_IBAMA,
             PATTERN_IBAMA,
             full.names = TRUE)[[1]])

# -----------------------------------------------------------------------------
#### Aggregating IBAMA files

# Result: 309,116 rows | 13 columns (public release; the source has 84)
# Confirmed 2026-05-08
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
#   NAs concentrated 2008-2012
#   "Desmatamento e Queimada" (2,051 valid): 1,579/1,606 Flora records are
#   409999: excluded for same reason as main filter (see below)
#
# count(DES_STATUS_FORMULARIO)
#   Lavrado: 291,748 | Cancelado: 12,262 | NA: 4,201 | (others < 600)
#
# count(SIT_CANCELADO)
#   N: 293,104 | S: 16,012
#
# count(COD_INFRACAO)
#   356 distinct codes; 6 identified as deforestation-specific (see below)
#   409999 is the largest (77,872): generic code, excluded. Real deforestation
#   cases within it are already caught by Case 1/3; the rest (14,710) have no
#   recoverable signal (TIPO_INFRACAO and INFRACAO_AREA both NA)
#
# Sensitivity of the cut: extended report 2.1
# -----------------------------------------------------------------------------

DEFORESTATION_CODES <- c(
  "409907",  # Destroy, clear, or damage native forests or vegetation
  "409901",  # Destroy or damage forests in permanent preservation areas (APP)
  "452001",  # Destroy/clear forests in APP (art. 2, Law 4,771)
  "430001",  # Clear forests without IBAMA authorization
  "431003",  # Destroy or damage forests in specially protected areas
  "468001"   # Destroy native or planted mangrove-protecting forests
)

ibama_filtered <- ibama_raw %>%
  filter(
    SIT_CANCELADO         == "N",
    DES_STATUS_FORMULARIO == "Lavrado",
    (
      # Case 1: classic Flora + Desmatamento (58,051 records, pipeline v1)
      (TIPO_INFRACAO == "Flora" & INFRACAO_AREA == "Desmatamento") |

        # Case 2: Flora, unclassified area, deforestation code (2,129 records)
        # All concentrated in 2008-2012, INFRACAO_AREA not mandatory before
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
#### Date column choice

# NA rate in ibama_filtered, five candidate date columns, measured on the
# full 84-column source (the public release keeps only the first and third):
#   DAT_HORA_AUTO_INFRACAO       0%   selected: ISO 8601, parses with no NA
#   DAT_CIENCIA_AUTUACAO        12%
#   DT_FATO_INFRACIONAL         71%
#   DT_INICIO_ATO_INEQUIVOCO    71%
#   DT_FIM_ATO_INEQUIVOCO       71%
# -------------------------------------------------------------------------

ibama_filtered <- ibama_filtered %>%
  mutate(year = year(ymd(DAT_HORA_AUTO_INFRACAO)))

stopifnot(
  "unexpected year NAs" =
    sum(is.na(ibama_filtered$year)) == NA_IBAMA_DATES
)

# -----------------------------------------------------------------------------
#### Exploring fine values

# Distribution (n = 60,707):
#   total = R$26.8bn | median = R$75.3k | mean = R$444k |
#   p25=R$12.9k | p75 = R$290k | max = R$62.6M | n_0 = 5 |
#   n_na = 356 (0.6%) | n_negative = 0
# The NAs contribute zero to the fine sum (na.rm below): extended report 5.1
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

# =============================================================================
#### I.2 PRODES: read and scope filter
# =============================================================================

# -----------------------------------------------------------------------------
#### Encoding check (PRODES)

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

# SCOPE FILTER (Legal Amazon only), mirrors pipeline/02_marts.sql:prodes_clean
# The TerraBrasilis "legal_amazon" export ships 805 geocodes; 33 sit outside
# the Legal Amazon (area_km2 = 0 in all 18 years).

AL_STATE_PREFIXES <- c(
  "11","12","13","14","15","16","17",  # RO AC AM RR PA AP TO
  "21",                                # MA
  "51"                                 # MT
)

prodes_clean <- prodes_raw %>%
  mutate(
    year         = as.integer(year),
    area_km2     = as.numeric(str_replace(`area km²`, ",", "."))
  ) %>%
  filter(str_sub(geocode_ibge, 1, 2) %in% AL_STATE_PREFIXES) %>%
  select(geocode_ibge, mun, year, area_km2)

stopifnot(
  "prodes_clean: unexpected row count" =
    nrow(prodes_clean) == NROW_PRODES_CLEAN,
  "prodes_clean: unexpected out-of-scope geocode count dropped" =
    n_distinct(prodes_raw$geocode_ibge) -
      n_distinct(prodes_clean$geocode_ibge) == N_OUT_OF_SCOPE_GEOCODES,
  "prodes_clean: NAs in geocode_ibge" =
    sum(is.na(prodes_clean$geocode_ibge)) == 0,
  "prodes_clean: NAs in year" =
    sum(is.na(prodes_clean$year)) == 0,
  "prodes_clean: NAs in area_km2" =
    sum(is.na(prodes_clean$area_km2)) == 0,
  "prodes_clean: unique municipalities" =
    n_distinct(prodes_clean$geocode_ibge) == N_GEOCODES_PRODES_CLEAN,
  "prodes_clean: years out of range" =
    all(prodes_clean$year %in% 2008:2025)
)

# =============================================================================
#### I.3 IPCA: read and deflator
# =============================================================================

# IPCA: Sidra t.1737, v.2266, Brazil, Jan/2008-Dec/2025, download 2026-07-10
# Wide format with title and footnotes originally

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
  "ipca_raw: 216 lines"           = nrow(ipca_raw) == NROW_IPCA_LONG,
  "ipca_raw: 18 years"            = n_distinct(ipca_raw$year) == 18
)

ipca_deflator <- ipca_raw %>%
  group_by(year) %>%
  summarise(avg_index = mean(index), .groups = "drop") %>%
  mutate(deflator = avg_index[year == 2025] / avg_index) %>%
  select(year, deflator)

# =============================================================================
#### I.4 EGS panel
# =============================================================================

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
    denom_raw = sqrt(log10(1 + n_infractions) * log10(1 + fine_values)),
    egs       = if_else(area_km2 < 1, 0,
                        log10(1 + area_km2) / pmax(1, denom_raw))
  )

stopifnot(
  "egs_panel: unexpected row count" =
    nrow(egs_panel) == NROW_PRODES_CLEAN,
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
#### I.5 Municipality ranking
# =============================================================================

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
  "unexpected qualified-municipality count" =
    nrow(muni_qualified) == N_MUNI_WITH_PRESSURE
)

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


# #############################################################################
# PART II. DESCRIPTION
# #############################################################################

# =============================================================================
#### II.1 IBAMA: monthly distribution of notices
# =============================================================================

#   Jan = 2.6% | Feb = 5.3% | Mar = 7.2% | Apr = 8.4% | May = 9.8% |
#   Jun = 9.6% | Jul = 9.2% | Aug = 9.6% | Sep = 11.1% | Oct = 10.3% |
#   Nov = 9.8% | Dec = 7.1%
#   Sep-Oct peak aligns with dry season
#   Non-decisive evidence for join t + 0: extended report 4.2

ibama_filtered %>%
  mutate(month = month(ymd(DAT_HORA_AUTO_INFRACAO))) %>%
  count(month) %>%
  mutate(pct = round(n / sum(n) * 100, 1)) %>%
  arrange(month)

# =============================================================================
#### II.2 IBAMA: internal lag, fact to notice
# =============================================================================

# Base: n_lag = 17,642, 29% of the 60,707 filtered notices; 355 records with
# lag < 0 discarded (recorded before fact) -> n = 17,287 analyzed below
#   n = 17,287 | median = 6 days | mean = 278 days | p75 = 295 days |
#   p90 = 1,077 days | max = 7,984 days

ibama_lag <- ibama_filtered %>%
  transmute(
    lag_days = as.numeric(ymd(DAT_HORA_AUTO_INFRACAO) -
                            ymd(DT_FATO_INFRACIONAL)),
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
# Lag per fine range (n = 17,287)

#   range            n      median_fine
#   <=7 days       8,954      R$95k
#   8-30 days      1,326      R$154k
#   31-365 days    3,321      R$283.5k  (peak)
#   1-2 years      1,217      R$215k
#   >2 years       2,469      R$155k
#   Pattern: higher-value operations have longer lags. Partial sample:
#   extended report 8.10
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
#### II.3 PRODES: annual series and distribution
# =============================================================================

# years = 18 (2008-2025)

# quantiles(area_km2):
# min = 0 | p10 = 0 | p25 = 0 | median = 0.68 | p75 = 5.36 | p90 = 22.1 |
# max = 797

# Structural check against the consolidated INPE rate, 4 anchor years:
# 2008 +2.9% | 2012 -3.2% | 2024 -3.9% | 2025 -8.3% (cf. extended report 4.1).

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

# =============================================================================
#### II.4 Base coverage: IBAMA x PRODES geocodes
# =============================================================================

# ibama_geocode_ibge = 2,806 | prodes_geocode_ibge = 772 (Legal Amazon)
# 2,160 geocode_ibge present in ibama but not in prodes (outside Amazon)
# 126 geocode_ibge present in prodes but not in ibama (no enforcement)
# 646 geocode_ibge present in both ibama and prodes (enforcement)
# Coverage only: the 126 are not absolute_gap, which also requires materiality.

prodes_codes <- prodes_clean %>%
  distinct(geocode_ibge) %>%
  pull()

ibama_codes  <- ibama_filtered %>%
  distinct(COD_MUNICIPIO) %>%
  pull()

tibble(
  ibama_only   = length(setdiff(ibama_codes, prodes_codes)),
  prodes_only  = length(setdiff(prodes_codes, ibama_codes)),
  ibama_total  = length(ibama_codes),
  prodes_total = length(prodes_codes),
  both         = length(intersect(ibama_codes, prodes_codes))
)

# =============================================================================
#### II.5 Ranking: top 15
# =============================================================================

# Reference values for cross-checking the SQL implementation (deflated):
#   Cachoeira do Piriá (PA): avg18 = 1.179 | avg3y = 1.228 | slope = -0.010
#   Porto de Moz (PA):       avg18 = 1.175 | avg3y = 0.930 | slope = -0.014
#   Aveiro (PA):             avg18 = 1.109 | avg3y = 1.508 | slope = +0.042
#   (top 15 entirely 18/18 pressure years)

final_table %>% slice_head(n = 15)


# #############################################################################
# PART III. DESIGN TESTS
# #############################################################################

# =============================================================================
#### III.1 Join window: same year vs t+1            (extended report 4.2)
# =============================================================================

# Unit is the notice, not the municipality-year (n = 60,707).
# Expected: only_t 4.7% | only_t1 1.0% | both 59.2% | neither 35.1%

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

# -----------------------------------------------------------------------------
# Cost of the t+1 alternative (materiality area >= 1; response >= R$0.01)
# Expected: absolute_gap 3,063 (22.0% of 13,896) | recovered 724 | 23.6%
# -----------------------------------------------------------------------------

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

tibble(
  absolute_gap = nrow(absolute_gap_cases),
  recovered_t1 = nrow(recovered_gap_t1),
  pct_change   = round(nrow(recovered_gap_t1) /
                         nrow(absolute_gap_cases) * 100, 1)
)
stopifnot(
  "absolute_gap: divergent count" =
    nrow(absolute_gap_cases) == N_ABSOLUTE_GAP,
  "sensitivity t+1: divergent count" =
    nrow(recovered_gap_t1) == N_RECOVERED_GAP_T1
)

# =============================================================================
#### III.2 Denominator floor: how often does it bind?   (extended report 3.1)
# =============================================================================

# Expected: floor binds in 28 of 3,285 measured_gap years; raw denominator
# min 0.796 | p25 1.56 | median 2.07 | max 4.56

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

# =============================================================================
#### III.3 Materiality threshold: ranking sensitivity   (extended report 3.2)
# =============================================================================

# Expected: top 10/20/50 identical under 1 km2, 6.25 ha and no threshold;
# Spearman 0.987 (1 km2 vs 6.25 ha; 4-decimal values in report 3.2).
# 3,291 = rows between the two thresholds (report 3.2 counts all under 1 km2).

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

tibble(spearman_1km_vs_625ha = cor(rank_1km$rank, rank_625ha$rank,
                                   method = "spearman"))

stopifnot(
  "materiality: unexpected reclassification count" =
    egs_panel %>%
    filter(area_km2 >= 0.0625, area_km2 < 1) %>%
    nrow() == N_RECLASS_MATERIALITY
)

# =============================================================================
#### III.4 0-fill mean: severity x frequency            (extended report 3.3)
# =============================================================================

# Identity: mean_0fill == mean(EGS | pressure years) * frac(pressure years)
# Expected: 552 municipalities; Pearson 0.621 | Spearman 0.695

stopifnot(
  "0-fill identity broken" =
    isTRUE(all.equal(
      muni_qualified$avg_egs_18y,
      muni_qualified$avg_egs_pressure_years * muni_qualified$frac_pressure
    ))
)

muni_qualified %>%
  summarise(
    pearson  = cor(avg_egs_pressure_years, frac_pressure),
    spearman = cor(avg_egs_pressure_years, frac_pressure, method = "spearman")
  )

# =============================================================================
#### III.5 Slope fragility                              (extended report 3.4)
# =============================================================================

# Expected: Nova Nazaré slope -0.0172 (2 pressure years) |
# Palmeiras do Tocantins +0.00518 (1)

final_table %>%
  filter(mun %in% c("Palmeiras do Tocantins", "Nova Nazaré")) %>%
  select(mun, avg_egs_18y, avg_egs_3y, slope_egs, n_years_pressure)
