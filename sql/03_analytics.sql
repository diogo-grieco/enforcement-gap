----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 03_analytics.sql — index, classification, and ranking
--
-- Author:  Diogo Grieco
-- Updated: 2026-07-20 (fixes-review pass — documented the PRODES/IBAMA
--          calendar mismatch (Fix S8, decision i below); added a
--          deterministic tiebreak to egs_ranking's ORDER BY (Fix S16.1).
--          No values change; see sql_technical_fixes.md.)
--          Previously v5-2026-07-20 (layer purity pass — ipca_deflator (the
--          rebasing RATIO, avg_index[2025]/avg_index[year]) moved
--          here from staging: it's a derived index, the same category
--          of computation as egs, not raw ingestion or column
--          typing. Reads from marts.ipca_annual. egs_base and
--          egs_ranking updated to join analytics.ipca_deflator,
--          marts.municipality_ref, and marts.municipality_area
--          (previously all three lived in staging). Checks
--          consolidated into a single UNION ALL query, same pattern
--          as 01_staging.sql/02_marts.sql. See sql_technical_fixes.md.
--          Previously v4-2026-07-20 — ranking redesign, replaces
--          ranking_absolute_gap/ranking_measured_gap with
--          egs_ranking, denominator floor, municipality-area
--          normalization; v3-2026-07-15 — translated to English,
--          Fix 16 in p2_technical_fixes.txt.)
--
-- SCALE NOTE: LOG() in DuckDB is base 10 (R's log() is
-- natural). The scale is monotonic: rankings don't change, but
-- absolute EGS values are on a log10 scale.
--
-- METHODOLOGICAL DECISIONS (2026-07-20, ranking redesign):
-- (a) MATERIALITY: area_km2 >= 1 km² unchanged from v3 — an order of
--     magnitude above PRODES's minimum mapping area (6.25 ha).
--     Sensitivity-tested 2026-07-20: top 10/20/50 of egs_ranking are
--     IDENTICAL under thresholds of 1 km², 6.25 ha, and no threshold
--     at all (Spearman 0.985, 1 km² vs 6.25 ha rankings, across all 805
--     municipalities — the pair actually computed in R; the no-threshold
--     comparison was verified by top-N overlap only). The
--     threshold affects only the no_pressure descriptive share
--     (56.2%), not the ranking. Kept as a robustness result, not
--     merely an assumption.
-- (b) DENOMINATOR FLOOR: GREATEST(1, SQRT(LOG(1+n_infractions)
--     * LOG(1+fine_values))) replaces the old three-branch CASE.
--     absolute_gap is no longer a separate formula — it is what this
--     single formula produces whenever the response side is at or
--     near zero (denominator floors to 1, egs = LOG(1+area_km2)).
--     Validated 2026-07-20: reproduces the old CASE exactly in 100%
--     of former absolute_gap and 99.1% of former measured_gap rows
--     (deflated fines); the 0.9% divergent (28/3,285) are exactly the
--     R$0.01-boundary instability cases this floor was built to fix
--     (Fix S10, resolved).
-- (c) NO_PRESSURE = 0, not NULL: egs is never NULL now. Materiality
--     years contribute exactly 0 to any average — this is what makes
--     the 0-fill mean (see egs_ranking) a single, auditable formula
--     instead of a hidden two-step average.
-- (d) gap_type is KEPT as a per-year descriptive label (same three
--     thresholds as v3) but no longer drives the egs formula — it is
--     annotation, not logic. It is also no longer a partition for
--     separate rankings: a single municipality can (and in the
--     current top of egs_ranking, usually does) mix absolute_gap and
--     measured_gap years, and both contribute to the same average.
--     absolute_gap years score systematically HIGHER on average than
--     measured_gap years (0.723 vs 0.582 mean, deflated) because the
--     floor never discounts them — a municipality chronically without
--     any monetary response is not penalized by this design, it is
--     favored, consistent with the project's stated reading that zero
--     response is a more severe gap than disproportionate response.
-- (e) STREAKS, priority_score, and the two separate rankings are
--     REMOVED (Fix S2/S3/S7, superseded). No consecutiveness rule.
--     The 0-fill mean already dilutes isolated point events without
--     an arbitrary "N consecutive years" cutoff — see the Nova Nazaré
--     (MT) worked example in sql_technical_fixes.md: highest raw
--     severity in the dataset, 2/18 pressure years, correctly
--     demoted out of the top 10 by the 0-fill mean alone.
-- (f) SLOPE computed manually via COVAR_POP/VAR_POP, not DuckDB's
--     native REGR_SLOPE() — mirrors exploring_script.R's
--     cov(year, egs)/var(year) exactly (same numeric result either
--     way, since the ratio cancels the N-normalization; the manual
--     form avoids relying on an aggregate whose behavior here was
--     never independently verified, see Fix S7 note). Read alongside
--     n_years_pressure: with few non-zero years the slope is driven
--     by the position of one or two points and is a weak recency
--     signal on its own (validated: single 2024 event -> slope
--     +0.005; two events 2008/2017 -> slope -0.017 — the "new" vs.
--     "old, closed" distinction lives in the second decimal place).
-- (g) pct_desmatado (resolves Fix S12): total deforested area over
--     the 18-year panel as a % of the municipality's own territory
--     (IBGE, Malha Municipal Digital 2025, via marts.municipality_area).
--     Context column, not a ranking criterion — captures a different
--     axis than avg_egs_18y (proportion of the municipality already
--     lost, not disproportion of the response). Validated 2026-07-20:
--     distinct top list from avg_egs_18y (e.g. Cujubim/RO: 29.8% of
--     its territory deforested in the panel, but avg_egs_18y = 0.578,
--     well below the top 15 by severity).
-- (h) uf/municipality_name: sourced from marts.municipality_ref.
-- fine_value is already deflated (2025 base) via analytics.ipca_deflator.
-- (i) CALENDAR MISMATCH (Fix S8, documented 2026-07-20, not corrected):
--     the join below (p.year = i.year) compares PRODES's official year
--     (Aug 1, year t-1 - Jul 31, year t) against IBAMA's calendar year
--     (Jan-Dec, from DAT_HORA_AUTO_INFRACAO) as if they were the same
--     window. They overlap for only ~7 of 12 months. The same-year-join
--     lag validation in exploring_script.R (59.2% same-year / 4.7%
--     only_t / 1.0% only_t1 / 35.1% never — shares of the 60,707
--     infraction records, not of municipality-years) was run on this calendar-year
--     basis, not against the true PRODES window — the lag figures may
--     partly reflect this mismatch rather than genuine reporting delay.
--     Not corrected in v5; a reader with remote-sensing background will
--     likely notice, so it is named here rather than left implicit.
----------------------------------------------------------

----------------------------------------------------------
-- ipca_deflator: rebasing index (2025 = 1.0)
-- A derived index (avg_index[2025] / avg_index[year]), not a typing
-- or filtering operation — this is why it lives here and not in
-- marts, even though its input (marts.ipca_annual) is fully clean.
-- Same category of computation as egs below.
-- Expected: 18 rows | deflator(2025) = 1.0 | deflator(2008) ~ 2.6
-- (confirmed 2026-07-20 against the real Sidra file: deflator(2008)
-- = 2.5826, reproduced identically in Python and R)
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.ipca_deflator AS
SELECT
    year,
    (SELECT avg_index FROM project2.marts.ipca_annual WHERE year = 2025) / avg_index AS deflator
FROM project2.marts.ipca_annual
ORDER BY year;

----------------------------------------------------------
-- egs_base: municipality-year panel with pressure and response
-- Expected: 14,490 rows (inherits the PRODES panel)
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.egs_base AS
SELECT
    p.geocode_ibge,
    p.mun,
    r.uf,
    r.municipality_name,
    p.year,
    p.area_km2,
    COUNT(i.geocode_ibge)                        AS n_infractions,
    COALESCE(SUM(i.fine_value), 0)                AS fine_values_nominal,
    -- real values (2025 base) via IPCA deflator;
    -- the deflator is per year, so multiplying the aggregate is equivalent
    COALESCE(SUM(i.fine_value), 0) * d.deflator   AS fine_values
FROM project2.marts.prodes_clean p
LEFT JOIN project2.marts.ibama_clean i
    ON  p.geocode_ibge = i.geocode_ibge
    AND p.year         = i.year
LEFT JOIN project2.analytics.ipca_deflator d
    ON  p.year = d.year
LEFT JOIN project2.marts.municipality_ref r
    ON  p.geocode_ibge = r.geocode_ibge
GROUP BY p.geocode_ibge, p.mun, r.uf, r.municipality_name, p.year, p.area_km2, d.deflator;

----------------------------------------------------------
-- egs_final: unified index (floor) + descriptive classification
-- gap_type is computed independently (annotation only, see decision
-- d); egs is a single formula for every row, no branching on
-- gap_type. Expected: 14,490 rows, egs never NULL.
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.egs_final AS
SELECT
    geocode_ibge,
    mun,
    uf,
    municipality_name,
    year,
    area_km2,
    n_infractions,
    fine_values_nominal,
    fine_values,
    CASE
        WHEN area_km2 < 1 THEN 0
        ELSE LOG(1 + area_km2)
             / GREATEST(1, SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values)))
    END AS egs,
    CASE
        WHEN area_km2 < 1       THEN 'no_pressure'
        WHEN fine_values < 0.01 THEN 'absolute_gap'
        ELSE                         'measured_gap'
    END AS gap_type
FROM project2.analytics.egs_base;

----------------------------------------------------------
-- egs_ranking: municipality-level historical, recent, and trend view
-- One row per municipality (805), no consecutiveness filter, no
-- separate absolute/measured populations.
--
-- avg_egs_18y (main ordering): mean of the yearly egs (0-filled for
-- no_pressure) over the full 18-year panel. Algebraically identical
-- to mean(egs | pressure years) * fraction(pressure years) — the
-- severity x frequency composite, computed as one direct average
-- instead of a hidden two-step formula.
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.egs_ranking AS
SELECT
    e.geocode_ibge,
    e.mun,
    e.uf,
    e.municipality_name,
    ROUND(AVG(e.egs), 3)                                          AS avg_egs_18y,
    ROUND(AVG(e.egs) FILTER (WHERE e.year >= 2023), 3)            AS avg_egs_3y,
    ROUND(COVAR_POP(e.egs, e.year) / VAR_POP(e.year), 5)          AS slope_egs,
    SUM(CASE WHEN e.gap_type != 'no_pressure' THEN 1 ELSE 0 END)  AS n_years_pressure,
    SUM(CASE WHEN e.gap_type = 'absolute_gap' THEN 1 ELSE 0 END)  AS n_absolute_gap,
    SUM(CASE WHEN e.gap_type = 'measured_gap' THEN 1 ELSE 0 END)  AS n_measured_gap,
    SUM(CASE WHEN e.gap_type = 'no_pressure'  THEN 1 ELSE 0 END)  AS n_no_pressure,
    ROUND(SUM(e.area_km2), 1)                                     AS total_desmatado_km2,
    a.area_municipio_km2,
    ROUND(SUM(e.area_km2) / a.area_municipio_km2 * 100, 2)        AS pct_desmatado,
    SUM(e.n_infractions)                                          AS n_infractions,
    ROUND(SUM(e.fine_values), 2)                                  AS total_fines
FROM project2.analytics.egs_final e
LEFT JOIN project2.marts.municipality_area a
    ON e.geocode_ibge = a.geocode_ibge
GROUP BY e.geocode_ibge, e.mun, e.uf, e.municipality_name, a.area_municipio_km2
-- Fix S16.1 (2026-07-20; revisado na auditoria de 2026-07-20): tiebreak
-- determinístico pela média NÃO-arredondada, depois geocode. Ordenar pela
-- coluna arredondada criava empates artificiais (Monte Alegre 1,10893 vs
-- Aveiro 1,10870, ambos "1.109") que o geocode resolvia contra a ordem
-- verdadeira. AVG(e.egs) preserva a ordem real; o geocode só desempata
-- empates exatos (ex.: municípios com egs todo zero).
ORDER BY AVG(e.egs) DESC, e.geocode_ibge;

----------------------------------------------------------
-- annual_summary: dashboard overview
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.annual_summary AS
SELECT
    year,
    COUNT(*)                                                       AS n_municipalities,
    SUM(CASE WHEN gap_type = 'absolute_gap' THEN 1 ELSE 0 END)     AS n_absolute_gap,
    SUM(CASE WHEN gap_type = 'measured_gap' THEN 1 ELSE 0 END)     AS n_measured_gap,
    SUM(CASE WHEN gap_type = 'no_pressure'  THEN 1 ELSE 0 END)     AS n_no_pressure,
    ROUND(SUM(area_km2), 1)                                        AS total_deforested_km2,
    ROUND(AVG(CASE WHEN gap_type = 'measured_gap' THEN egs END), 3) AS avg_egs_measured_gap
FROM project2.analytics.egs_final
GROUP BY year
ORDER BY year;

----------------------------------------------------------
-- == ANALYTICS CHECKS ==
-- Single consolidated query, one result grid instead of one tab per
-- check, same pattern as 01_staging.sql/02_marts.sql.
----------------------------------------------------------

WITH checks AS (
    SELECT 'missing_years_ipca_deflator' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '0' AS expected
        FROM (SELECT UNNEST(RANGE(2008,2026)) AS year) years LEFT JOIN project2.analytics.ipca_deflator d USING(year) WHERE d.year IS NULL
    UNION ALL SELECT 'invalid_deflator', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.ipca_deflator WHERE deflator IS NULL OR deflator <= 0
    UNION ALL SELECT 'deflator_2025', CAST(ROUND(deflator, 1) AS VARCHAR), '1.0' FROM project2.analytics.ipca_deflator WHERE year = 2025
    -- deflator_2008 (terceira auditoria, 2026-07-20): pina o VALOR do deflator
    -- contra o Sidra real (2,5826, reproduzido identicamente em Python, R e
    -- DuckDB — Fix S5). deflator_2025 = 1.0 vale por construção para QUALQUER
    -- série; um download errado do Sidra com a mesma estrutura (outra
    -- variável, outra base) passaria por todos os checks estruturais sem
    -- este aqui.
    UNION ALL SELECT 'deflator_2008', CAST(ROUND(deflator, 4) AS VARCHAR), '2.5826' FROM project2.analytics.ipca_deflator WHERE year = 2008
    UNION ALL SELECT 'n_egs_final', CAST(COUNT(*) AS VARCHAR), '14490' FROM project2.analytics.egs_final
    UNION ALL SELECT 'n_no_pressure', CAST(COUNT(*) AS VARCHAR), '8142' FROM project2.analytics.egs_final WHERE gap_type = 'no_pressure'
    UNION ALL SELECT 'n_absolute_gap', CAST(COUNT(*) AS VARCHAR), '3063' FROM project2.analytics.egs_final WHERE gap_type = 'absolute_gap'
    UNION ALL SELECT 'n_measured_gap', CAST(COUNT(*) AS VARCHAR), '3285' FROM project2.analytics.egs_final WHERE gap_type = 'measured_gap'
    UNION ALL SELECT 'null_egs', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_final WHERE egs IS NULL
    -- n_floor_active (Fix S10): validated 2026-07-20 with deflated fines.
    -- These are the R$0.01-boundary instability cases the denominator
    -- floor was built to fix — the floor makes them more conservative
    -- (lower egs) instead of letting the denominator approach 0.
    UNION ALL SELECT 'n_floor_active', CAST(COUNT(*) AS VARCHAR), '28' FROM project2.analytics.egs_final WHERE gap_type = 'measured_gap' AND SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values)) < 1
    -- n_floor_active_nominal (auditoria 2026-07-20): a contraparte nominal do
    -- piso, agora reprodutível porque fine_values_nominal passou a ser
    -- persistida em egs_final. ATENÇÃO: a réplica independente da auditoria
    -- deu 61, não os "62" citados em exploring_script.R e
    -- sql_technical_fixes.md (cifra de comentário, nunca assertada — provável
    -- drift do protótipo). Se este check falhar com actual=62, investigar
    -- antes de mudar o esperado; se passar com 61, corrigir os dois
    -- comentários (ver AUDIT_PATCH, Bloco C).
    UNION ALL SELECT 'n_floor_active_nominal', CAST(COUNT(*) AS VARCHAR), '61' FROM project2.analytics.egs_final WHERE gap_type = 'measured_gap' AND SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values_nominal)) < 1
    UNION ALL SELECT 'missing_uf_egs_final', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_final WHERE uf IS NULL
    UNION ALL SELECT 'n_egs_ranking', CAST(COUNT(*) AS VARCHAR), '805' FROM project2.analytics.egs_ranking
    UNION ALL SELECT 'mismatched_year_counts', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_ranking WHERE n_absolute_gap + n_measured_gap + n_no_pressure != 18
    UNION ALL SELECT 'n_muni_with_pressure', CAST(COUNT(*) AS VARCHAR), '552' FROM project2.analytics.egs_ranking WHERE n_years_pressure > 0
    -- 0-fill identity: avg_egs_18y == mean(egs | pressure years) * frac(pressure years)
    UNION ALL SELECT 'identity_mismatches', CAST(COUNT(*) AS VARCHAR), '0'
        FROM project2.analytics.egs_ranking r
        JOIN (SELECT geocode_ibge, AVG(egs) AS avg_egs_pressure_years FROM project2.analytics.egs_final WHERE gap_type != 'no_pressure' GROUP BY geocode_ibge) p
            ON r.geocode_ibge = p.geocode_ibge
        WHERE r.n_years_pressure > 0
          AND ABS(r.avg_egs_18y - p.avg_egs_pressure_years * (r.n_years_pressure / 18.0)) > 0.01
    UNION ALL SELECT 'missing_area_egs_ranking', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_ranking WHERE area_municipio_km2 IS NULL
    UNION ALL SELECT 'median_pct_desmatado', CAST(ROUND(MEDIAN(pct_desmatado), 2) AS VARCHAR), '0.97' FROM project2.analytics.egs_ranking
    UNION ALL SELECT 'p75_pct_desmatado', CAST(ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY pct_desmatado), 2) AS VARCHAR), '3.19' FROM project2.analytics.egs_ranking
    UNION ALL SELECT 'max_pct_desmatado', CAST(ROUND(MAX(pct_desmatado), 2) AS VARCHAR), '29.79' FROM project2.analytics.egs_ranking
)
SELECT check_name, actual, expected,
       CASE WHEN actual = expected THEN 'OK' ELSE 'failed' END AS status
FROM checks
ORDER BY status DESC, check_name;   -- 'failed' > 'OK' na colação binária: falhas no topo
