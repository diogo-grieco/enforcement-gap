# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 04 panel effects
# panel grain (two-way FE)
#
# Author: Diogo Grieco
#
# Purpose: report figures 10 and 11, and the models behind them. Municipality
#          and year FE, municipality-clustered SEs.
#
# The one script in the suite that estimates before it draws: DuckDB has no
# fixed-effects estimator, so this cannot move upstream like gap_type,
# egs_trend or gap_dominant did. Declared exception; see viz/README.md.
# The PUB_* constants below are what replaces layer purity here.
# =============================================================================

source("viz/00_setup.R")
library(fixest)

# Read by figures 10 and 11. Lightness, not hue: it survives colour blindness.
OUTCOME_COLOURS <- c(autos  = unname(RESPONSE_RAMP[1]),
                     multas = unname(RESPONSE_RAMP[5]))

# -----------------------------------------------------------------------------
#### Build the panel with lags/leads WITHIN municipality
# -----------------------------------------------------------------------------
# log10(1+x) matches the EGS convention and keeps logs defined at zero.

panel <- final %>%
  arrange(geocode_ibge, year) %>%
  group_by(geocode_ibge) %>%
  mutate(log_area     = log10(1 + area_km2),
         log_infra    = log10(1 + n_infractions),
         log_fine     = log10(1 + fine_values),      # deflated fines
         log_area_l1  = lag(log_area, 1),            # t-1
         d_log_area   = log_area - log_area_l1,      # year-on-year change
         log_area_f1  = lead(log_area, 1),           # t+1
         log_area_f2  = lead(log_area, 2),           # t+2
         log_infra_f1 = lead(log_infra, 1),
         log_infra_f2 = lead(log_infra, 2),
         log_fine_f1  = lead(log_fine, 1),
         d_pos = pmax(d_log_area, 0),                # year-on-year increase
         d_neg = pmin(d_log_area, 0)) %>%            # year-on-year decrease
  ungroup()

stopifnot("panel: unexpected row count" = nrow(panel) == N_PANEL)


# -----------------------------------------------------------------------------
#### The four two-way FE models (municipality + year, clustered SEs)
# -----------------------------------------------------------------------------

m1 <- feols(log_infra ~ log_area + log_area_l1 | geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                 # level
m2 <- feols(log_infra_f1 ~ d_log_area + log_area | geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                 # H2 test
m3 <- feols(log_infra_f2 ~ d_log_area + log_area + log_area_f2 |
              geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                 # persistence
m4 <- feols(log_infra_f1 ~ d_pos + d_neg + log_area + log_area_f1 |
              geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                 # asymmetry

# Same specifications with the FINE as outcome. The two responses diverge:
# rank correlation 0.722 at the annual grain, not 0.99.
m1f <- feols(log_fine ~ log_area + log_area_l1 | geocode_ibge + year,
             data = panel, cluster = ~geocode_ibge)              # level, fines
m2f <- feols(log_fine_f1 ~ d_log_area + log_area | geocode_ibge + year,
             data = panel, cluster = ~geocode_ibge)                # H2, fines
m4f <- feols(log_fine_f1 ~ d_pos + d_neg + log_area + log_area_f1 |
               geocode_ibge + year,
             data = panel, cluster = ~geocode_ibge)          # asymmetry, fines

etable(m1, m1f, m2, m2f, m3, m4, m4f)   # full tables for the write-up

# Values PUBLISHED in section 5.5, at the precision the text uses. Compared on
# the ROUNDED value: what is protected is the sentence, not the coefficient.
PUB_M1_LOG_AREA    <-  0.080 ; PUB_M1_LOG_AREA_L1 <- 0.056
PUB_M2_D_LOG_AREA  <- -0.057
PUB_M2F_D_LOG_AREA <- -0.399
PUB_M1F_LOG_AREA   <-  0.382 ; PUB_M1F_LOG_AREA_L1 <- 0.323
PUB_M4F_D_POS      <- -0.501 ; PUB_M4F_D_NEG       <- -0.274
PUB_M3_D_LOG_AREA  <- -0.069   # raw -0.06852515, 2.5e-5 from the rounding
                               # boundary: if only THIS fails, read the raw
                               # value before assuming the data moved.
PUB_M4_D_POS       <- -0.114 ; PUB_M4_D_POS_SE    <- 0.032
PUB_M4_D_NEG       <- -0.005
PUB_N_OBS <- c(m1 = 13124, m1f = 13124, m2 = 12352, m2f = 12352,
               m3 = 11580, m4 = 12352, m4f = 12352, es = 10036)

.cf <- function(m, term) unname(coef(m)[term])
.se <- function(m, term) unname(summary(m)$coeftable[term, "Std. Error"])

stopifnot(
  "m1: published log_area changed"    = round(.cf(m1, "log_area"), 3) ==
    PUB_M1_LOG_AREA,
  "m1: published log_area_l1 changed" = round(.cf(m1, "log_area_l1"), 3) ==
    PUB_M1_LOG_AREA_L1,
  "m2: published d_log_area changed"  = round(.cf(m2, "d_log_area"), 3) ==
    PUB_M2_D_LOG_AREA,
  "m2f: published d_log_area changed" = round(.cf(m2f, "d_log_area"), 3) ==
    PUB_M2F_D_LOG_AREA,
  "m3: published d_log_area changed"  = round(.cf(m3, "d_log_area"), 3) ==
    PUB_M3_D_LOG_AREA,
  "m4: published d_pos changed"       = round(.cf(m4, "d_pos"), 3) ==
    PUB_M4_D_POS,
  "m4: published SE of d_pos changed" = round(.se(m4, "d_pos"), 3) ==
    PUB_M4_D_POS_SE,
  "m4: published d_neg changed"       = round(.cf(m4, "d_neg"), 3) ==
    PUB_M4_D_NEG,
  "m1f: published log_area changed"   = round(.cf(m1f, "log_area"), 3) ==
    PUB_M1F_LOG_AREA,
  "m1f: published log_area_l1 changed" =
    round(.cf(m1f, "log_area_l1"), 3) == PUB_M1F_LOG_AREA_L1,
  "m4f: published d_pos changed"      = round(.cf(m4f, "d_pos"), 3) ==
    PUB_M4F_D_POS,
  "m4f: published d_neg changed"      = round(.cf(m4f, "d_neg"), 3) ==
    PUB_M4F_D_NEG,
  "observation counts changed"        =
    all(vapply(list(m1, m1f, m2, m2f, m3, m4, m4f), nobs, numeric(1)) ==
          PUB_N_OBS[c("m1","m1f","m2","m2f","m3","m4","m4f")])
)

# #############################################################################
# SECOND HALF: FIGURES. Above, estimation and guards. Below, drawing only.
# #############################################################################

# -----------------------------------------------------------------------------
#### 10: coefficient plot
# -----------------------------------------------------------------------------

grab <- function(model, term, label, outcome) {
  ct <- summary(model)$coeftable
  data.frame(label = label, outcome = outcome,
             estimate = ct[term, "Estimate"],
             se       = ct[term, "Std. Error"], row.names = NULL)
}
# m3 is estimated and checked above but not plotted: it backs one sentence in
# the report, and d_log_area is autocorrelated enough to make a t+2 row cheap.
# Every row is a term of DEFORESTATION; the response is the colour.
ROWS <- c("Nível em t\n(resposta em t)",
          "Nível em t-1\n(resposta em t)",
          "Variação anual em t\n(resposta em t+1)",
          "Aumento em t\n(resposta em t+1)",
          "Redução em t\n(resposta em t+1)")
AUTOS  <- "autos"
MULTAS <- "multas"

coef_df <- bind_rows(
  grab(m1,  "log_area",    ROWS[1], AUTOS),
  grab(m1,  "log_area_l1", ROWS[2], AUTOS),
  grab(m2,  "d_log_area",  ROWS[3], AUTOS),
  grab(m4,  "d_pos",       ROWS[4], AUTOS),
  grab(m4,  "d_neg",       ROWS[5], AUTOS),
  grab(m1f, "log_area",    ROWS[1], MULTAS),
  grab(m1f, "log_area_l1", ROWS[2], MULTAS),
  grab(m2f, "d_log_area",  ROWS[3], MULTAS),
  grab(m4f, "d_pos",       ROWS[4], MULTAS),
  grab(m4f, "d_neg",       ROWS[5], MULTAS)
) %>%
  mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se,
         label   = factor(label, levels = rev(ROWS)),
         outcome = factor(outcome, levels = c(AUTOS, MULTAS)))

# Shared x axis, no rescaling: same log10-log10 units on both sides, so the
# money bars being longer is the finding, not a plotting artefact.
p_coef <- ggplot(coef_df, aes(x = estimate, y = label, colour = outcome)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_pointrange(aes(xmin = lo, xmax = hi), size = 0.45,
                  position = position_dodge(width = 0.55)) +
  scale_colour_manual(values = OUTCOME_COLOURS, name = NULL) +
  # dodge puts the first level lower, so the key has to be reversed to match.
  guides(colour = guide_legend(reverse = TRUE)) +
  scale_x_continuous(labels = number) +
  labs(x = "Coeficiente (IC 95%)", y = "Termo de desmatamento") +
  theme_chart

# -----------------------------------------------------------------------------
#### 11: event study around a year-on-year increase in deforestation
# -----------------------------------------------------------------------------
# Leads and lags of d_pos, controlling the contemporaneous level. The pre-event
# coefficients at -2 and -1 are the placebo test for pre-trends. Plotted with
# 95% CIs because the result weakens here and the fragility has to be visible.

es_panel <- panel %>%
  arrange(geocode_ibge, year) %>%
  group_by(geocode_ibge) %>%
  mutate(dpos_lead2 = lead(d_pos, 2),   # event time -2 (pre-event, placebo)
         dpos_lead1 = lead(d_pos, 1),   # event time -1 (pre-event, placebo)
         dpos_lag0  = d_pos,            # event time  0 (year of the increase)
         dpos_lag1  = lag(d_pos, 1),    # event time +1
         dpos_lag2  = lag(d_pos, 2)) %>%
  ungroup()

es_autos <- feols(log_infra ~ dpos_lead2 + dpos_lead1 + dpos_lag0 +
                    dpos_lag1 + dpos_lag2 + log_area | geocode_ibge + year,
                  data = es_panel, cluster = ~geocode_ibge)
es_fine  <- feols(log_fine ~ dpos_lead2 + dpos_lead1 + dpos_lag0 +
                    dpos_lag1 + dpos_lag2 + log_area | geocode_ibge + year,
                  data = es_panel, cluster = ~geocode_ibge)

EVENT_MAP <- c(dpos_lead2 = -2, dpos_lead1 = -1, dpos_lag0 = 0,
               dpos_lag1 = 1, dpos_lag2 = 2)
event_path <- function(model, outcome) {
  ct <- summary(model)$coeftable[names(EVENT_MAP), ]
  data.frame(outcome = outcome,
             event_time = EVENT_MAP,
             estimate = ct[, "Estimate"],
             se       = ct[, "Std. Error"], row.names = NULL)
}

# Table 4 of the extended report.
PUB_ES_TERMS  <- c("dpos_lead2", "dpos_lead1", "dpos_lag0",
                   "dpos_lag1", "dpos_lag2")
PUB_ES_AUTOS  <- c( 0.036, -0.001, -0.063, -0.034, -0.015)
PUB_ES_MULTAS <- c( 0.196,  0.071, -0.212,  0.000,  0.144)

stopifnot(
  "event study (autos): Table 4 does not come from this model" =
    all(round(unname(coef(es_autos)[PUB_ES_TERMS]), 3) == PUB_ES_AUTOS),
  "event study (fines): Table 4 does not come from this model" =
    all(round(unname(coef(es_fine)[PUB_ES_TERMS]), 3) == PUB_ES_MULTAS),
  "event study: observation count changed" = nobs(es_autos) == PUB_N_OBS[["es"]]
)

es_df <- bind_rows(event_path(es_autos, "autos"),
                   event_path(es_fine,  "multas")) %>%
  mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se)

p_event <- ggplot(es_df, aes(x = event_time, y = estimate, colour = outcome)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey75") +
  geom_pointrange(aes(ymin = lo, ymax = hi),
                  position = position_dodge(width = 0.25)) +
  geom_line(position = position_dodge(width = 0.25), alpha = 0.4) +
  scale_x_continuous(breaks = -2:2) +
  scale_colour_manual(values = OUTCOME_COLOURS, name = NULL) +
  guides(colour = guide_legend(reverse = TRUE)) +   # same key order as fig. 10
  scale_y_continuous(labels = number) +
  labs(x = "Tempo do evento (anos em relação ao aumento)",
       y = "Coeficiente (IC 95%)") +
  theme_chart

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "10_coefficient_plot.png"), p_coef,
       width = 8, height = 5, dpi = 150)
ggsave(file.path(PATH_OUT, "11_event_study.png"), p_event,
       width = 8, height = 5, dpi = 150)
