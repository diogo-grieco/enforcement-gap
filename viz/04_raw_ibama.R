# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite — 04 raw IBAMA visuals
# IBAMA raw data (84 columns)
#
# Author: Diogo Grieco
#
# Purpose: Visuals from the RAW IBAMA CSVs (items 11-14, 17), and the cached
#          intermediate that the offender network (07) also reads.
#            11 Lorenz curve of fine concentration across offenders
#            12 cancellation-rate series (2017-2019 spike) + by state
#            13 histogram of the fact -> notice lag (long tail; axis label
#               uses the arrow glyph, not ASCII "->")
#            14 embargo/apreensão share by EGS quintile
#            17 choropleth: auto cancellation rate by municipality
#          Slowest script (reads the 18 yearly CSVs via load_ibama_clean(),
#          see 00_load_ibama_clean.R); caches a filtered parquet on first run
#          and reuses it afterwards. Independent of 07_offender_network.R —
#          either can run first, each builds the cache if it's missing.
# =============================================================================

source("viz/00_setup.R")
source("viz/00_load_ibama_clean.R")
library(ineq)      # Gini / Lorenz

# -----------------------------------------------------------------------------
#### Setting local files (viz caches, under PATH_CACHE)
# -----------------------------------------------------------------------------

FILE_CANCEL <- "viz_muni_cancellation.parquet"   # per-muni cancel rate (map 17)
cancel_path <- file.path(PATH_CACHE, FILE_CANCEL)

# -----------------------------------------------------------------------------
#### Read + filter the raw IBAMA files (shared loader, cached)
# -----------------------------------------------------------------------------

ibama_clean <- load_ibama_clean()
ibama <- ibama_clean$ibama
defor <- ibama_clean$defor
clean <- ibama_clean$clean

# -----------------------------------------------------------------------------
#### 11 — Lorenz curve of fine concentration across offenders
# -----------------------------------------------------------------------------

offender_totals <- clean %>%
  filter(!is.na(CPF_CNPJ_INFRATOR), fine_value > 0) %>%
  group_by(CPF_CNPJ_INFRATOR) %>%
  summarise(total_fine = sum(fine_value, na.rm = TRUE), .groups = "drop") %>%
  arrange(total_fine)

lorenz <- offender_totals %>%
  mutate(cum_offenders = row_number() / n(),
         cum_fine      = cumsum(total_fine) / sum(total_fine))

gini <- ineq::ineq(offender_totals$total_fine, type = "Gini")

p_lorenz <- ggplot(lorenz, aes(x = cum_offenders, y = cum_fine)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60") +
  geom_line(colour = "#7c4a20", linewidth = 1) +
  scale_x_continuous(labels = percent) +
  scale_y_continuous(labels = percent) +
  annotate("text", x = 0.05, y = 0.9, hjust = 0,
           label = paste0("Gini = ", number(gini, accuracy = 0.001))) +
  labs(x = "Fração acumulada de infratores", y = "Fração acumulada do valor de multas") +
  theme_chart

# -----------------------------------------------------------------------------
#### 12 — cancellation-rate series + by state
# -----------------------------------------------------------------------------

cancel_year <- defor %>%
  filter(!is.na(year)) %>%
  group_by(year) %>%
  summarise(rate = mean(SIT_CANCELADO == "S", na.rm = TRUE), n = n(), .groups = "drop")

p_cancel_year <- ggplot(cancel_year, aes(x = year, y = rate)) +
  annotate("rect", xmin = 2016.5, xmax = 2019.5, ymin = -Inf, ymax = Inf,
           fill = "#f3e9df", alpha = 0.7) +
  geom_line(colour = "#a63d2f", linewidth = 1) +
  geom_point(colour = "#a63d2f") +
  scale_y_continuous(labels = percent) +
  annotate("text", x = 2018, y = max(cancel_year$rate),
           label = "2017-2019\npico de cancelamento", size = 3, colour = "#6b756d") +
  labs(x = NULL, y = "Taxa de cancelamento") +
  theme_chart

cancel_uf <- defor %>%
  group_by(UF) %>%
  summarise(rate = mean(SIT_CANCELADO == "S", na.rm = TRUE), n = n(), .groups = "drop") %>%
  filter(n >= 100) %>%
  mutate(UF = fct_reorder(UF, rate))

p_cancel_uf <- ggplot(cancel_uf, aes(x = rate, y = UF)) +
  geom_col(fill = "#a63d2f", width = 0.7) +
  scale_x_continuous(labels = percent) +
  labs(x = "Taxa de cancelamento", y = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### 13 — fact -> notice lag histogram
# -----------------------------------------------------------------------------
# Only ~28% of clean autos carry DT_FATO_INFRACIONAL — partial, possibly
# non-random sample (better-staffed units may fill it more often).

lag_df <- clean %>%
  filter(!is.na(dt_fact), !is.na(dt_notice)) %>%
  mutate(lag_days = as.integer(dt_notice - dt_fact)) %>%
  filter(lag_days >= -30, lag_days <= 3650)   # trim clear data-entry outliers

p_lag <- ggplot(lag_df, aes(x = lag_days)) +
  geom_histogram(binwidth = 30, fill = "#c98a3d", colour = "white") +
  geom_vline(xintercept = median(lag_df$lag_days), linetype = "dashed") +
  annotate("text", x = median(lag_df$lag_days), y = Inf, vjust = 2, hjust = -0.1,
           label = paste0("mediana = ", median(lag_df$lag_days), " dias"), size = 3) +
  scale_x_continuous(labels = number) +
  scale_y_continuous(labels = number) +
  labs(x = "Dias (fato \u2192 autuação)", y = "Autos") +
  theme_chart

# -----------------------------------------------------------------------------
#### 14 — embargo / apreensão share by EGS quintile
# -----------------------------------------------------------------------------

muni_instr <- clean %>%
  group_by(COD_MUNICIPIO) %>%
  summarise(n_autos     = n(),
            pct_embargo  = mean(!is.na(CD_TERMOS_EMBARGOS)),
            pct_seizure  = mean(!is.na(CD_TERMOS_APREENSAO)), .groups = "drop") %>%
  filter(n_autos >= 5) %>%
  inner_join(ranking %>% select(geocode_ibge, avg_egs_18y),
             by = c("COD_MUNICIPIO" = "geocode_ibge")) %>%
  mutate(egs_quintile = factor(q5(avg_egs_18y)))

instr_long <- muni_instr %>%
  select(egs_quintile, pct_embargo, pct_seizure) %>%
  pivot_longer(-egs_quintile, names_to = "instrument", values_to = "share") %>%
  mutate(instrument = recode(instrument, pct_embargo = "embargo", pct_seizure = "apreensão"))

p_instrument <- ggplot(instr_long, aes(x = egs_quintile, y = share, fill = instrument)) +
  geom_boxplot(outlier.size = 0.5) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = c(embargo = "#b9773a", `apreensão` = "#2e6e54"), name = "Instrumento") +
  labs(x = "Quintil de EGS", y = "Fração dos autos") +
  theme_chart

# -----------------------------------------------------------------------------
#### Cache the per-municipality cancellation rate (for map 17)
# -----------------------------------------------------------------------------

muni_cancellation <- defor %>%
  group_by(COD_MUNICIPIO) %>%
  summarise(cancel_rate = mean(SIT_CANCELADO == "S", na.rm = TRUE), n = n(), .groups = "drop") %>%
  filter(n >= 5) %>%
  rename(geocode_ibge = COD_MUNICIPIO)
arrow::write_parquet(muni_cancellation, cancel_path)

# -----------------------------------------------------------------------------
#### 17 — cancellation rate by municipality (choropleth)
# -----------------------------------------------------------------------------
# Lives here, not in 01_maps.R: muni_cancellation only exists once this script
# has run, and it's already in memory above — no need to round-trip it through
# the parquet cache just written. muni_mesh comes from 00_setup.R, sourced by
# every viz/*.R script including this one.

map_cancel <- muni_mesh %>%
  left_join(muni_cancellation, by = c("code_muni" = "geocode_ibge")) %>%
  mutate(q_cancel = factor(q5(cancel_rate)))

p_cancel_map <- ggplot(map_cancel) +
  geom_sf(aes(fill = q_cancel), colour = "white", linewidth = 0.05) +
  scale_fill_manual(values = QUINTILE_PALETTE, name = "Quintil\ntaxa de cancelamento",
                    na.value = "grey90") +
  theme_map

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "11_lorenz_offenders.png"),      p_lorenz,      width = 6, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "12a_cancel_by_year.png"),       p_cancel_year, width = 8, height = 4, dpi = 150)
ggsave(file.path(PATH_OUT, "12b_cancel_by_state.png"),      p_cancel_uf,   width = 6, height = 4, dpi = 150)
ggsave(file.path(PATH_OUT, "13_fact_notice_lag.png"),       p_lag,         width = 7, height = 4, dpi = 150)
ggsave(file.path(PATH_OUT, "14_instrument_by_quintile.png"),p_instrument,  width = 7, height = 4, dpi = 150)
ggsave(file.path(PATH_OUT, "17_cancellation_map.png"),      p_cancel_map,  width = 8, height = 7, dpi = 150)
