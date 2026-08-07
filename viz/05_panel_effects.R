# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 05 panel effects
# panel grain (two-way FE)
#
# Author: Diogo Grieco
#
# Purpose: The panel-regression findings, in R/fixest to match the thesis
#          methodology (report figures 12, 13 and 15).
#            12 coefficient plot summarising the five two-way FE models
#            13 event study around a deforestation surge (autos & fines,
#               with placebo pre-period); the honest test of the "hangover":
#               directional for autos, fragile (CIs cross zero)
#            15 ridgeline of the EGS distribution by year
#          Reproduces the Python/linearmodels pilot (ACHADOS_VARREDURA...md)
#          with municipality + year FE and municipality-clustered SEs: the
#          exact estimator planned for the dissertation.
# =============================================================================

source("viz/00_setup.R")
library(fixest)
library(ggridges)

# -----------------------------------------------------------------------------
#### Build the panel with lags/leads WITHIN municipality
# -----------------------------------------------------------------------------
# Panel is balanced (772 x 18); still lag/lead within geocode to be safe.
# log10(1+x) matches the EGS convention and keeps logs defined at zero.

panel <- final %>%
  arrange(geocode_ibge, year) %>%
  group_by(geocode_ibge) %>%
  mutate(log_area     = log10(1 + area_km2),
         log_infra    = log10(1 + n_infractions),
         log_fine     = log10(1 + fine_values),      # deflated fines
         log_area_l1  = lag(log_area, 1),            # t-1
         d_log_area   = log_area - log_area_l1,       # year-on-year change
         log_area_f1  = lead(log_area, 1),            # t+1
         log_area_f2  = lead(log_area, 2),            # t+2
         log_infra_f1 = lead(log_infra, 1),
         log_infra_f2 = lead(log_infra, 2),
         log_fine_f1  = lead(log_fine, 1),
         d_pos = pmax(d_log_area, 0),                 # abrupt surge
         d_neg = pmin(d_log_area, 0)) %>%             # abrupt drop
  ungroup()

stopifnot("panel: unexpected row count" = nrow(panel) == N_PANEL)

# Pre-period capacity proxy: mean autos 2008-2016, split at the median.
# Defined BEFORE the tested window to limit (not remove) endogeneity.
baseline_capacity <- final %>%
  filter(year <= 2016) %>%
  group_by(geocode_ibge) %>%
  summarise(cap = mean(n_infractions), .groups = "drop")
panel <- panel %>%
  left_join(baseline_capacity, by = "geocode_ibge") %>%
  mutate(high_capacity = as.integer(cap > median(cap, na.rm = TRUE)))

# -----------------------------------------------------------------------------
#### The five two-way FE models (municipality + year, clustered SEs)
# -----------------------------------------------------------------------------

m1 <- feols(log_infra ~ log_area + log_area_l1 | geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                       # level
m2 <- feols(log_infra_f1 ~ d_log_area + log_area | geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                       # H2 test
m3 <- feols(log_infra_f2 ~ d_log_area + log_area + log_area_f2 | geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                       # persistence
m4 <- feols(log_infra_f1 ~ d_pos + d_neg + log_area + log_area_f1 | geocode_ibge + year,
            data = panel, cluster = ~geocode_ibge)                       # asymmetry
m5 <- feols(log_infra_f1 ~ d_pos + d_pos:high_capacity + d_neg + log_area + log_area_f1 |
              geocode_ibge + year,
            data = panel %>% filter(year >= 2017), cluster = ~geocode_ibge)  # capacity

# m2f: same specification as m2 with the FINE as the outcome instead of the
# notice count. The extended report cites its coefficient (-0.399) alongside
# m2's (-0.057); until the sixth audit this model existed only in the write-up,
# not in the code: log_fine_f1 was built above and never used, so the published
# number could not be reproduced from this repository. It is not plotted (item
# 15 shows the notice-count models only); it exists so the citation is auditable.
m2f <- feols(log_fine_f1 ~ d_log_area + log_area | geocode_ibge + year,
             data = panel, cluster = ~geocode_ibge)                      # H2, fines

etable(m1, m2, m2f, m3, m4, m5)   # full tables to console for the write-up

# ---------------------------------------------------------------------------
# Valores PUBLICADOS no relatorio estendido, secao 5.5, na precisao em que o
# texto os publica. Ate a setima auditoria esta camada nao tinha guarda nenhuma,
# e por isso um coeficiente do piloto anterior em Python sobreviveu a migracao
# para o fixest e foi publicado: o modo de falha que a secao 7 do relatorio
# nomeia ("numeros em prosa derivam; numeros em checks, nao"). A comparacao e
# por igualdade sobre o valor ARREDONDADO, porque o que se protege e a frase
# publicada, nao o coeficiente.
# ---------------------------------------------------------------------------
PUB_M1_LOG_AREA    <-  0.080 ; PUB_M1_LOG_AREA_L1 <- 0.056
PUB_M2_D_LOG_AREA  <- -0.057
PUB_M2F_D_LOG_AREA <- -0.399
PUB_M3_D_LOG_AREA  <- -0.069   # valor bruto -0.06852515: a 2.5e-5 da fronteira de
                               # arredondamento. Se ESTE check falhar sozinho, confira
                               # o valor bruto antes de concluir que o dado mudou.
PUB_M4_D_POS       <- -0.114 ; PUB_M4_D_POS_SE    <- 0.032
PUB_M4_D_NEG       <- -0.005
PUB_M5_D_POS_HICAP <- -0.121
PUB_N_OBS <- c(m1 = 13124, m2 = 12352, m2f = 12352, m3 = 11580,
               m4 = 12352, m5 = 6176, es = 10036)

.cf <- function(m, term) unname(coef(m)[term])
.se <- function(m, term) unname(summary(m)$coeftable[term, "Std. Error"])

stopifnot(
  "m1: log_area publicado mudou"     = round(.cf(m1, "log_area"),    3) == PUB_M1_LOG_AREA,
  "m1: log_area_l1 publicado mudou"  = round(.cf(m1, "log_area_l1"), 3) == PUB_M1_LOG_AREA_L1,
  "m2: d_log_area publicado mudou"   = round(.cf(m2, "d_log_area"),  3) == PUB_M2_D_LOG_AREA,
  "m2f: d_log_area publicado mudou"  = round(.cf(m2f,"d_log_area"),  3) == PUB_M2F_D_LOG_AREA,
  "m3: d_log_area publicado mudou"   = round(.cf(m3, "d_log_area"),  3) == PUB_M3_D_LOG_AREA,
  "m4: d_pos publicado mudou"        = round(.cf(m4, "d_pos"),       3) == PUB_M4_D_POS,
  "m4: EP de d_pos publicado mudou"  = round(.se(m4, "d_pos"),       3) == PUB_M4_D_POS_SE,
  "m4: d_neg publicado mudou"        = round(.cf(m4, "d_neg"),       3) == PUB_M4_D_NEG,
  "m5: interacao publicada mudou"    = round(.cf(m5, "d_pos:high_capacity"), 3) == PUB_M5_D_POS_HICAP,
  "observacoes de m1-m5 mudaram"     =
    all(vapply(list(m1, m2, m2f, m3, m4, m5), nobs, numeric(1)) ==
        PUB_N_OBS[c("m1","m2","m2f","m3","m4","m5")])
)

# -----------------------------------------------------------------------------
#### 12: coefficient plot
# -----------------------------------------------------------------------------

grab <- function(model, term, label) {
  ct <- summary(model)$coeftable
  data.frame(label = label,
             estimate = ct[term, "Estimate"],
             se       = ct[term, "Std. Error"], row.names = NULL)
}
coef_df <- bind_rows(
  grab(m1, "log_area",           "Desmatamento(t) \u2192 autos(t)"),
  grab(m1, "log_area_l1",        "Desmatamento(t-1) \u2192 autos(t)"),
  grab(m2, "d_log_area",         "Mudança abrupta(t) \u2192 autos(t+1)"),
  grab(m3, "d_log_area",         "Mudança abrupta(t) \u2192 autos(t+2)"),
  grab(m4, "d_pos",              "Surto(t) \u2192 autos(t+1)"),
  grab(m4, "d_neg",              "Queda(t) \u2192 autos(t+1)"),
  grab(m5, "d_pos:high_capacity","Surto \u00d7 alta capacidade \u2192 autos(t+1)")
) %>%
  mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se,
         label = factor(label, levels = rev(label)))

p_coef <- ggplot(coef_df, aes(x = estimate, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_pointrange(aes(xmin = lo, xmax = hi, colour = estimate < 0), size = 0.5) +
  scale_colour_manual(values = c("TRUE" = "#a63d2f", "FALSE" = "#2e6e54"), guide = "none") +
  scale_x_continuous(labels = number) +
  labs(x = "Coeficiente (IC 95%)", y = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### 13: event study around a deforestation surge (the honest version)
# -----------------------------------------------------------------------------
# A raw 3-municipality time series CANNOT show the "hangover": it is a partial,
# average effect (net of the deforestation level), not a raw-series phenomenon
# in any single unit. The correct object is an event study: leads and lags of
# the surge magnitude (d_pos), controlling the contemporaneous deforestation
# level, with municipality + year FE. This is also the estimator the thesis
# proposes (sec. 8.7).
#
# Reading: the single-lag result in the coefficient plot above is the
# strongest cut. Distributed across event time it WEAKENS: for autos the
# path is directionally consistent (flat placebos, negative at 0/+1/+2) but
# not individually significant; for fines it does not hold. Both outcomes
# are plotted with 95% CIs so the fragility is visible, not hidden. Placebos
# (event time -2, -1) check for pre-trends.

# Leads/lags of the surge magnitude, within municipality.
es_panel <- panel %>%
  arrange(geocode_ibge, year) %>%
  group_by(geocode_ibge) %>%
  mutate(dpos_lead2 = lead(d_pos, 2),   # surge 2y ahead  -> event time -2 (placebo)
         dpos_lead1 = lead(d_pos, 1),   # event time -1 (placebo)
         dpos_lag0  = d_pos,            # event time  0 (surge year)
         dpos_lag1  = lag(d_pos, 1),    # event time +1
         dpos_lag2  = lag(d_pos, 2)) %>%# event time +2
  ungroup()

# Distributed-lag models for each outcome, controlling contemporaneous level.
es_autos <- feols(log_infra ~ dpos_lead2 + dpos_lead1 + dpos_lag0 + dpos_lag1 +
                    dpos_lag2 + log_area | geocode_ibge + year,
                  data = es_panel, cluster = ~geocode_ibge)
es_fine  <- feols(log_fine  ~ dpos_lead2 + dpos_lead1 + dpos_lag0 + dpos_lag1 +
                    dpos_lag2 + log_area | geocode_ibge + year,
                  data = es_panel, cluster = ~geocode_ibge)

# Extract the event-time path (coefficient + 95% CI) from a fitted model.
EVENT_MAP <- c(dpos_lead2 = -2, dpos_lead1 = -1, dpos_lag0 = 0,
               dpos_lag1 = 1, dpos_lag2 = 2)
event_path <- function(model, outcome) {
  ct <- summary(model)$coeftable[names(EVENT_MAP), ]
  data.frame(outcome = outcome,
             event_time = EVENT_MAP,
             estimate = ct[, "Estimate"],
             se       = ct[, "Std. Error"], row.names = NULL)
}
# Valores PUBLICADOS na Tabela 4 do relatorio estendido. Esta e a guarda que
# teria pego o erro: seis dos dez coeficientes publicados nao saiam deste modelo.
PUB_ES_TERMS  <- c("dpos_lead2","dpos_lead1","dpos_lag0","dpos_lag1","dpos_lag2")
PUB_ES_AUTOS  <- c( 0.036, -0.001, -0.063, -0.034, -0.015)
PUB_ES_MULTAS <- c( 0.196,  0.071, -0.212,  0.000,  0.144)

stopifnot(
  "event study (autos): a Tabela 4 nao sai deste modelo" =
    all(round(unname(coef(es_autos)[PUB_ES_TERMS]), 3) == PUB_ES_AUTOS),
  "event study (multas): a Tabela 4 nao sai deste modelo" =
    all(round(unname(coef(es_fine)[PUB_ES_TERMS]),  3) == PUB_ES_MULTAS),
  "event study: observacoes mudaram" = nobs(es_autos) == PUB_N_OBS[["es"]]
)

es_df <- bind_rows(event_path(es_autos, "autos"),
                   event_path(es_fine,  "multas (deflacionadas)")) %>%
  mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se)

p_event <- ggplot(es_df, aes(x = event_time, y = estimate, colour = outcome)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey75") +
  geom_pointrange(aes(ymin = lo, ymax = hi), position = position_dodge(width = 0.25)) +
  geom_line(position = position_dodge(width = 0.25), alpha = 0.4) +
  scale_x_continuous(breaks = -2:2,
                     labels = c("-2\n(placebo)","-1\n(placebo)","0\n(surto)","+1","+2")) +
  scale_colour_manual(values = c("autos" = "#2e6e54", "multas (deflacionadas)" = "#a63d2f"),
                      name = "Variável") +
  scale_y_continuous(labels = number) +
  labs(x = "Tempo do evento (anos em relação ao surto)", y = "Coeficiente (IC 95%)") +
  theme_chart

# -----------------------------------------------------------------------------
#### 15: ridgeline of EGS distribution by year
# -----------------------------------------------------------------------------
# Whole distribution shifting over 2008-2025, not just the mean. EGS is
# ordinal; a ridgeline reads shape/spread (legitimate), whereas comparing
# mean gaps in raw units would not be.

p_ridge <- ggplot(final %>% filter(egs > 0),   # drop the no-pressure zero mass
                  aes(x = egs, y = factor(year), fill = after_stat(x))) +
  geom_density_ridges_gradient(scale = 2.2, rel_min_height = 0.01, colour = "white") +
  scale_fill_gradientn(colours = QUINTILE_PALETTE, name = "EGS", labels = number) +
  scale_x_continuous(labels = number) +
  labs(x = "EGS (anual, > 0)", y = NULL) +
  theme_chart

# -----------------------------------------------------------------------------
#### Save
# -----------------------------------------------------------------------------

ggsave(file.path(PATH_OUT, "12_coefficient_plot.png"), p_coef,     width = 8, height = 5, dpi = 150)
ggsave(file.path(PATH_OUT, "13_event_study.png"),      p_event,    width = 8, height = 5, dpi = 150)
ggsave(file.path(PATH_OUT, "15_egs_ridgeline.png"),    p_ridge,    width = 7, height = 7, dpi = 150)
