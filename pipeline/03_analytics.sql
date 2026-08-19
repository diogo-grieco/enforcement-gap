----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 03_analytics.sql: index, classification, and ranking
--
-- Author: Diogo Grieco
--
-- METHODOLOGICAL DECISIONS (full rationale and validation in the
-- extended report's methodology section, not restated here):
-- (a) MATERIALITY: area_km2 >= 1 km2. Sensitivity-tested against
--     6.25 ha and no threshold: top 10/20/50 of egs_ranking unchanged.
-- (b) DENOMINATOR FLOOR: GREATEST(1, SQRT(LOG(1+n_infractions)
--     * LOG(1+fine_values))): a single formula, no branching by
--     gap_type. absolute_gap is what this formula produces whenever
--     the response side is at or near zero (denominator floors to 1,
--     egs = LOG(1+area_km2)).
-- (c) NO_PRESSURE = 0, not NULL: egs is never NULL, so the 0-fill
--     mean (see egs_ranking) is a single, auditable average.
-- (d) gap_type is a per-year descriptive label (annotation, not
--     logic) and not a partition for separate rankings: a single
--     municipality can mix absolute_gap and measured_gap years in
--     the same average.
-- (e) No consecutiveness/streak rule, and no separate rankings by
--     gap_type: the 0-fill mean already dilutes isolated point events.
-- (f) SLOPE computed manually via COVAR_POP/VAR_POP, not DuckDB's
--     native REGR_SLOPE(); mirrors exploration/exploring_script.R's
--     cov(year, egs)/var(year) exactly. Weak recency signal on its
--     own when few years are non-zero; read alongside n_years_pressure.
-- (g) pct_desmatado: total deforested area over the 18-year panel as
--     a % of the municipality's own territory. Context column, not a
--     ranking criterion (captures a different axis than avg_egs_18y).
-- (h) uf/municipality_name: sourced from marts.municipality_ref.
--     fine_value is already deflated (2025 base) via analytics.ipca_deflator.
-- (i) CALENDAR MISMATCH (not corrected): the join below (p.year =
--     i.year) compares PRODES's official year (Aug 1, year t-1 to
--     Jul 31, year t) against IBAMA's calendar year (Jan-Dec). They
--     overlap for only ~7 of 12 months.
-- (j) EGS_TREND: direction of travel, avg_egs_3y against avg_egs_18y,
--     with a stable band at |difference| < 0.05 and a strong band at
--     >= 0.20. Classified here and not in the figures that draw it:
--     the bands are a methodological choice, and two figures read the
--     same column. The grey band is avg_egs_3y = 0, NOT
--     n_years_pressure = 0: the 0-fill zeroes the recent mean of a
--     municipality whose pressure stopped, which makes the difference
--     negative, and a direction needs pressure at both ends of the
--     window. Thresholds apply to the ROUNDED columns above, so the
--     band is decided on the value the parquet stores.
-- (k) GAP_DOMINANT: which of the three annual situations a municipality
--     spends most of its 18 years in. Classified here and not in the figure
--     that colours by it, because the precedence that breaks ties is a
--     choice, not a drawing detail: it runs from the most severe category to
--     the least (absolute_gap, then measured_gap, then no_pressure), and it
--     decides the category of 23 of the 772.
----------------------------------------------------------

----------------------------------------------------------
-- ipca_deflator: rebasing index (2025 = 1.0)
-- A derived index (avg_index[2025] / avg_index[year]), not a typing
-- or filtering operation.
-- Expected: 18 rows | deflator(2025) = 1.0 | deflator(2008) = 2.5826
-- (reproduced identically in Python, R, and DuckDB against the Sidra file)
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.ipca_deflator AS
SELECT
    year,
    (SELECT avg_index FROM project2.marts.ipca_annual WHERE year = 2025) / avg_index AS deflator
FROM project2.marts.ipca_annual
ORDER BY year;

----------------------------------------------------------
-- egs_base: municipality-year panel with pressure and response
-- Expected: 13,896 rows (inherits the PRODES panel)
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
-- gap_type. Expected: 13,896 rows, egs never NULL.
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
-- One row per municipality (772), no consecutiveness filter, no
-- separate absolute/measured populations.
--
-- avg_egs_18y (main ordering): mean of the yearly egs (0-filled for
-- no_pressure) over the full 18-year panel. Algebraically identical
-- to mean(egs | pressure years) * fraction(pressure years).
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
    ROUND(SUM(e.fine_values), 2)                                  AS total_fines,
    ROUND(LOG(1 + total_desmatado_km2), 4)                        AS numerador_18y,
    -- SUM spelled out: the alias n_infractions collides with e.n_infractions,
    -- and the source column wins, which leaves it outside the GROUP BY.
    ROUND(GREATEST(1, SQRT(LOG(1 + SUM(e.n_infractions))
                         * LOG(1 + total_fines))), 4)             AS denominador_18y,
    CASE
        WHEN avg_egs_3y = 0                            THEN 'no_recent_pressure'
        WHEN ABS(avg_egs_3y - avg_egs_18y) < 0.05      THEN 'stable'
        WHEN avg_egs_3y - avg_egs_18y <= -0.20         THEN 'better_hi'
        WHEN avg_egs_3y < avg_egs_18y                  THEN 'better'
        WHEN avg_egs_3y - avg_egs_18y >= 0.20          THEN 'worse_hi'
        ELSE                                                'worse'
    END                                                           AS egs_trend,
    -- Ties: 23 of the 772. Precedence runs from the most severe category to
    -- the least, so a municipality split evenly between absolute and measured
    -- is called absolute.
    CASE
        WHEN n_absolute_gap >= n_measured_gap
         AND n_absolute_gap >= n_no_pressure        THEN 'absolute_gap'
        WHEN n_measured_gap >= n_no_pressure        THEN 'measured_gap'
        ELSE                                             'no_pressure'
    END                                                           AS gap_dominant
FROM project2.analytics.egs_final e
LEFT JOIN project2.marts.municipality_area a
    ON e.geocode_ibge = a.geocode_ibge
GROUP BY e.geocode_ibge, e.mun, e.uf, e.municipality_name, a.area_municipio_km2
-- Deterministic tiebreak: order by the UNROUNDED mean, then geocode.
-- Ordering by the rounded column alone creates artificial ties (Monte
-- Alegre 1.10893 vs Aveiro 1.10870, both "1.109") resolved wrong by a
-- geocode tiebreak against the true order.
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
----------------------------------------------------------

WITH checks AS (
    SELECT '01_missing_years_ipca_deflator' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '0' AS expected
        FROM (SELECT UNNEST(RANGE(2008,2026)) AS year) years LEFT JOIN project2.analytics.ipca_deflator d USING(year) WHERE d.year IS NULL
    UNION ALL SELECT '02_invalid_deflator', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.ipca_deflator WHERE deflator IS NULL OR deflator <= 0
    UNION ALL SELECT '03_deflator_2025', CAST(ROUND(deflator, 1) AS VARCHAR), '1.0' FROM project2.analytics.ipca_deflator WHERE year = 2025
    -- Pins the deflator VALUE against the real Sidra series; deflator_2025 = 1.0 holds by construction for any series and wouldn't catch a wrong download.
    UNION ALL SELECT '04_deflator_2008', CAST(ROUND(deflator, 4) AS VARCHAR), '2.5826' FROM project2.analytics.ipca_deflator WHERE year = 2008
    UNION ALL SELECT '05_n_egs_final', CAST(COUNT(*) AS VARCHAR), '13896' FROM project2.analytics.egs_final
    UNION ALL SELECT '06_n_no_pressure', CAST(COUNT(*) AS VARCHAR), '7548' FROM project2.analytics.egs_final WHERE gap_type = 'no_pressure'
    UNION ALL SELECT '07_n_absolute_gap', CAST(COUNT(*) AS VARCHAR), '3063' FROM project2.analytics.egs_final WHERE gap_type = 'absolute_gap'
    UNION ALL SELECT '08_n_measured_gap', CAST(COUNT(*) AS VARCHAR), '3285' FROM project2.analytics.egs_final WHERE gap_type = 'measured_gap'
    UNION ALL SELECT '09_null_egs', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_final WHERE egs IS NULL
    -- The R$0.01-boundary instability cases the denominator floor was built to absorb.
    UNION ALL SELECT '10_n_floor_active', CAST(COUNT(*) AS VARCHAR), '28' FROM project2.analytics.egs_final WHERE gap_type = 'measured_gap' AND SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values)) < 1
    -- Same floor-activation count using nominal (undeflated) fine values.
    UNION ALL SELECT '11_n_floor_active_nominal', CAST(COUNT(*) AS VARCHAR), '61' FROM project2.analytics.egs_final WHERE gap_type = 'measured_gap' AND SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values_nominal)) < 1
    UNION ALL SELECT '12_missing_uf_egs_final', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_final WHERE uf IS NULL
    UNION ALL SELECT '13_n_egs_ranking', CAST(COUNT(*) AS VARCHAR), '772' FROM project2.analytics.egs_ranking
    UNION ALL SELECT '14_mismatched_year_counts', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_ranking WHERE n_absolute_gap + n_measured_gap + n_no_pressure != 18
    UNION ALL SELECT '15_n_muni_with_pressure', CAST(COUNT(*) AS VARCHAR), '552' FROM project2.analytics.egs_ranking WHERE n_years_pressure > 0
    -- 0-fill identity: avg_egs_18y == mean(egs | pressure years) * frac(pressure years).
    UNION ALL SELECT '16_identity_mismatches', CAST(COUNT(*) AS VARCHAR), '0'
        FROM project2.analytics.egs_ranking r
        JOIN (SELECT geocode_ibge, AVG(egs) AS avg_egs_pressure_years FROM project2.analytics.egs_final WHERE gap_type != 'no_pressure' GROUP BY geocode_ibge) p
            ON r.geocode_ibge = p.geocode_ibge
        WHERE r.n_years_pressure > 0
          AND ABS(r.avg_egs_18y - p.avg_egs_pressure_years * (r.n_years_pressure / 18.0)) > 0.01
    UNION ALL SELECT '17_missing_area_egs_ranking', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.analytics.egs_ranking WHERE area_municipio_km2 IS NULL
    UNION ALL SELECT '18_median_pct_desmatado', CAST(ROUND(MEDIAN(pct_desmatado), 2) AS VARCHAR), '1.1' FROM project2.analytics.egs_ranking
    UNION ALL SELECT '19_p75_pct_desmatado', CAST(ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY pct_desmatado), 2) AS VARCHAR), '3.38' FROM project2.analytics.egs_ranking
    UNION ALL SELECT '20_max_pct_desmatado', CAST(ROUND(MAX(pct_desmatado), 2) AS VARCHAR), '29.79' FROM project2.analytics.egs_ranking
)
SELECT check_name, actual, expected,
       CASE WHEN actual = expected THEN 'OK' ELSE 'failed' END AS status
FROM checks
ORDER BY status DESC, check_name;   -- 'failed' > 'OK' na colação binária: falhas no topo
