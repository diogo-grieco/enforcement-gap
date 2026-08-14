# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 04 raw IBAMA visuals
# IBAMA raw data (public release, 13 columns)
#
# Author: Diogo Grieco
#
# Purpose: Visuals from the raw IBAMA CSVs (report figures 9 and 10): Lorenz
#          curve of fine concentration across offenders, and the
#          cancellation-rate series with its 2017-2019 spike.
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
#### 10: cancellation-rate series
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

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "09_lorenz_offenders.png"), p_lorenz,
       width = 6, height = 6, dpi = 150)
ggsave(file.path(PATH_OUT, "10_cancel_by_year.png"), p_cancel_year,
       width = 8, height = 4, dpi = 150)
