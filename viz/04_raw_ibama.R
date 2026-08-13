# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 04 raw IBAMA visuals
# IBAMA raw data (public release, 13 columns)
#
# Author: Diogo Grieco
#
# Purpose: Visuals from the raw IBAMA CSVs (report figures 9 to 13).
#            9      Lorenz curve of fine concentration across offenders
#            10, 11 cancellation-rate series (2017-2019 spike) and by state
#            12     histogram of the fact to notice lag
#            13     embargo/apreensão share by EGS quintile
#          Slowest script: calls load_ibama_clean() (00_setup.R), which caches
#          a filtered parquet on first run. Independent of 06; either can run
#          first, each builds the cache if it is missing.
# =============================================================================

source("viz/00_setup.R")
library(ineq)      # Gini / Lorenz

# -----------------------------------------------------------------------------
#### Read + filter the raw IBAMA files (shared loader, cached)
# -----------------------------------------------------------------------------

ibama_clean <- load_ibama_clean()
ibama <- ibama_clean$ibama
defor <- ibama_clean$defor
clean <- ibama_clean$clean

# -----------------------------------------------------------------------------
#### 9: Lorenz curve of fine concentration across offenders
# -----------------------------------------------------------------------------
# The population is not obvious from the caption: `clean` (deforestation
# notices in the 772 municipalities, not cancelled, "Lavrado"), with a non-null
# offender id and a fine above zero. Pinning n here is what keeps the caption
# from describing one population while the number comes from another.

offender_totals <- clean %>%
  filter(!is.na(CPF_CNPJ_INFRATOR), fine_value > 0) %>%
  group_by(CPF_CNPJ_INFRATOR) %>%
  summarise(total_fine = sum(fine_value, na.rm = TRUE), .groups = "drop") %>%
  arrange(total_fine)

lorenz <- offender_totals %>%
  mutate(cum_offenders = row_number() / n(),
         cum_fine      = cumsum(total_fine) / sum(total_fine))

gini <- ineq::ineq(offender_totals$total_fine, type = "Gini")

PUB_N_OFFENDERS <- 32836
PUB_GINI        <- 0.801

stopifnot(
  "lorenz: offender count changed" = nrow(offender_totals) == PUB_N_OFFENDERS,
  "lorenz: published Gini does not match" = round(gini, 3) == PUB_GINI
)

p_lorenz <- ggplot(lorenz, aes(x = cum_offenders, y = cum_fine)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              colour = "grey60") +
  geom_line(colour = "#7c4a20", linewidth = 1) +
  scale_x_continuous(labels = percent) +
  scale_y_continuous(labels = percent) +
  annotate("text", x = 0.05, y = 0.9, hjust = 0,
           label = paste0("Gini = ", number(gini, accuracy = 0.001))) +
  labs(x = "Fração acumulada de infratores",
       y = "Fração acumulada do valor de multas") +
  theme_chart

# -----------------------------------------------------------------------------
#### 10 and 11: cancellation-rate series + by state
# -----------------------------------------------------------------------------
# Base is `defor`, in ANY status: the rate requires the cancelled notices, which
# is why it is not comparable to the pipeline's 60,707. The 2017-2019 spike is
# asserted in prose in both documents; the guard pins the SET of the three
# years, not the rate.

cancel_year <- defor %>%
  filter(!is.na(year)) %>%
  group_by(year) %>%
  summarise(rate = mean(SIT_CANCELADO == "S", na.rm = TRUE), n = n(),
            .groups = "drop")

PUB_N_CANCEL_BASE <- 48063
PUB_CANCEL_PEAK   <- c(2017, 2018, 2019)

stopifnot(
  "cancellation: published base changed" = nrow(defor) == PUB_N_CANCEL_BASE,
  "cancellation: the peak is no longer 2017-2019" =
    setequal(cancel_year$year[order(-cancel_year$rate)][1:3], PUB_CANCEL_PEAK)
)

p_cancel_year <- ggplot(cancel_year, aes(x = year, y = rate)) +
  annotate("rect", xmin = 2016.5, xmax = 2019.5, ymin = -Inf, ymax = Inf,
           fill = "#f3e9df", alpha = 0.7) +
  geom_line(colour = "#a63d2f", linewidth = 1) +
  geom_point(colour = "#a63d2f") +
  scale_y_continuous(labels = percent) +
  # anchored left of the band and at the top: over the series it collided with
  # the 2017-2019 points.
  annotate("text", x = 2016.2, y = max(cancel_year$rate), hjust = 1,
           vjust = 0.5, label = "2017-2019\npico de cancelamento", size = 3,
           colour = "#6b756d") +
  labs(x = NULL, y = "Taxa de cancelamento") +
  theme_chart

cancel_uf <- defor %>%
  group_by(UF) %>%
  summarise(rate = mean(SIT_CANCELADO == "S", na.rm = TRUE), n = n(),
            .groups = "drop") %>%
  filter(n >= 100) %>%
  mutate(UF = fct_reorder(UF, rate))

# Only UFs with >= 100 notices. The 9 are exactly the Legal Amazon states; up
# to the fifth audit, states from outside appeared here.
PUB_N_UF_CANCEL <- 9
stopifnot("cancellation by UF: state count changed" =
            nrow(cancel_uf) == PUB_N_UF_CANCEL)

p_cancel_uf <- ggplot(cancel_uf, aes(x = rate, y = UF)) +
  geom_col(fill = "#a63d2f", width = 0.7) +
  scale_x_continuous(labels = percent) +
  labs(x = "Taxa de cancelamento", y = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### 12: fact to notice lag histogram
# -----------------------------------------------------------------------------
# Only ~28% of `clean` carries DT_FATO_INFRACIONAL: a partial and possibly
# non-random sample, so the denominator of the published share is 43,576, not
# the pipeline's 60,707.

lag_df <- clean %>%
  filter(!is.na(dt_fact), !is.na(dt_notice)) %>%
  mutate(lag_days = as.integer(dt_notice - dt_fact)) %>%
  filter(lag_days >= -30, lag_days <= 3650)   # trim data-entry outliers

PUB_LAG_MEDIAN <- 7
PUB_N_LAG_PLOT <- 12136

stopifnot(
  "lag: published median changed"   = median(lag_df$lag_days) == PUB_LAG_MEDIAN,
  "lag: partial-sample size changed" = nrow(lag_df) == PUB_N_LAG_PLOT
)

p_lag <- ggplot(lag_df, aes(x = lag_days)) +
  geom_histogram(binwidth = 30, fill = "#c98a3d", colour = "white") +
  geom_vline(xintercept = median(lag_df$lag_days), linetype = "dashed") +
  annotate("text", x = median(lag_df$lag_days), y = Inf, vjust = 2,
           hjust = -0.1,
           label = paste0("mediana = ", median(lag_df$lag_days), " dias"),
           size = 3) +
  scale_x_continuous(labels = number) +
  scale_y_continuous(labels = number) +
  labs(x = "Dias (fato \u2192 autuação)", y = "Autos") +
  theme_chart

# -----------------------------------------------------------------------------
#### 13: embargo / apreensão share by EGS quintile
# -----------------------------------------------------------------------------

muni_instr <- clean %>%
  group_by(COD_MUNICIPIO) %>%
  summarise(n_autos     = n(),
            pct_embargo = mean(!is.na(CD_TERMOS_EMBARGOS)),
            pct_seizure = mean(!is.na(CD_TERMOS_APREENSAO)),
            .groups = "drop") %>%
  filter(n_autos >= 5) %>%
  inner_join(ranking %>% select(geocode_ibge, avg_egs_18y),
             by = c("COD_MUNICIPIO" = "geocode_ibge")) %>%
  mutate(egs_quintile = factor(q5(avg_egs_18y)))

instr_long <- muni_instr %>%
  select(egs_quintile, pct_embargo, pct_seizure) %>%
  pivot_longer(-egs_quintile, names_to = "instrument", values_to = "share") %>%
  mutate(instrument = recode(instrument, pct_embargo = "embargo",
                             pct_seizure = "apreensão"))

p_instrument <- ggplot(instr_long,
                       aes(x = egs_quintile, y = share, fill = instrument)) +
  geom_boxplot(outlier.size = 0.5) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = c(embargo = "#b9773a", `apreensão` = "#2e6e54"),
                    name = "Instrumento") +
  labs(x = "Quintil de EGS", y = "Fração dos autos") +
  theme_chart

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "09_lorenz_offenders.png"), p_lorenz,
       width = 6, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "10_cancel_by_year.png"), p_cancel_year,
       width = 8, height = 4, dpi = 150)
ggsave(file.path(PATH_OUT, "11_cancel_by_state.png"), p_cancel_uf,
       width = 6, height = 4, dpi = 150)
ggsave(file.path(PATH_OUT, "12_fact_notice_lag.png"), p_lag,
       width = 7, height = 4, dpi = 150)
ggsave(file.path(PATH_OUT, "13_instrument_by_quintile.png"), p_instrument,
       width = 7, height = 4, dpi = 150)
