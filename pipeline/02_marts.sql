----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 02_marts.sql — clean, typed tables
--
-- Author: Diogo Grieco
--
-- Purpose: filter, type, and standardize the columns consumed
--          by the downstream layers (no SELECT *).
----------------------------------------------------------

----------------------------------------------------------
-- ibama_clean
-- Filter: 3 cases, mirrors exploration/exploring_script.R (independent
-- R implementation of the same filter, for cross-checking).
-- DECISION (date column): DAT_HORA_AUTO_INFRACAO (notice drafted,
--   0% NA) instead of DT_FATO_INFRACIONAL (71% NA in the filtered
--   base). Same-year join validated in exploration: 59.2% of
--   infraction records (n = 60,707; unit is the notice, not the
--   municipality-year) match BOTH windows (material pressure in year
--   t AND t-1); only_t (same-year only) = 4.7% — total same-year
--   match: 63.9% (59.2 + 4.7); only_t1 (would match ONLY with a
--   one-year lag) = 1.0%.
-- KNOWN LIMITATION: the PRODES "year" is not a calendar year — INPE's
--   official rate covers Aug 1 (year t-1) to Jul 31 (year t) — while
--   IBAMA's `year` here is calendar (Jan-Dec), from
--   DAT_HORA_AUTO_INFRACAO. The same-year join (p.year = i.year in
--   03_analytics.sql) therefore compares windows that only fully
--   overlap for ~7 of 12 months; the lag validation cited above was
--   run on this same calendar-year basis, not against the true
--   Aug-Jul PRODES window. Not corrected — documented so no reader
--   assumes the two "year" columns mean the same thing.
-- TRY_CAST (not CAST) on the date parse: a malformed value becomes
--   NULL, caught by the null_year check below, instead of aborting
--   the script before that check ever runs.
-- Expected: 60,707 rows
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.ibama_clean AS
SELECT
    COD_MUNICIPIO AS geocode_ibge,
    EXTRACT(YEAR FROM TRY_CAST(DAT_HORA_AUTO_INFRACAO AS DATE)) AS year,
    CAST(REPLACE(VAL_AUTO_INFRACAO, ',', '.') AS DOUBLE)        AS fine_value
FROM project2.staging.ibama_raw
WHERE
    SIT_CANCELADO         = 'N'
    AND DES_STATUS_FORMULARIO = 'Lavrado'
    AND (
        -- Case 1: Flora + Desmatamento (58,051; pipeline v1)
        (TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA = 'Desmatamento')
        -- Case 2: Flora, null area, specific deforestation code
        -- (2,129; concentrated 2008-2012, field not mandatory back then)
        OR (TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA IS NULL
            AND COD_INFRACAO IN (
                '409907', -- Destroy, clear, or damage native forests or vegetation
                '409901', -- Destroy or damage forests in permanent preservation areas (APP)
                '452001', -- Destroy/clear forests in APP (art. 2, Law 4,771)
                '430001', -- Clear forests without IBAMA authorization
                '431003', -- Destroy or damage forests in specially protected areas (art. 225, Federal Constitution)
                '468001'  -- Destroy native or planted mangrove-protecting forests
            ))
        -- Case 3: null type, area = Desmatamento (527; same historical pattern)
        OR (TIPO_INFRACAO IS NULL AND INFRACAO_AREA = 'Desmatamento')
    );

----------------------------------------------------------
-- prodes_clean
-- Expected: 13,896 rows | 772 geocodes (767 names; 5 homonyms)
-- geocode_ibge is already a clean 7-digit string in the raw data
--
-- SCOPE FILTER (Legal Amazon only): the TerraBrasilis municipal export
--   labelled "legal_amazon" ships 805 geocodes, but 33 of them are in
--   states OUTSIDE the Legal Amazon — GO (18), PI (6), MS (5), BA (4) —
--   each with area_km2 = 0 in every one of the 18 years (they carry no
--   PRODES-mapped deforestation). 805 - 33 = 772, exactly the official
--   Legal Amazon municipality count. We keep only the 9 Legal Amazon
--   state prefixes so the panel matches its declared universe; the 33
--   zero-deforestation out-of-scope rows were inflating the descriptive
--   "no pressure" share (and surfaced non-Legal-Amazon states in the
--   by-state cancellation chart). The ranking is unaffected (all 33 are
--   EGS 0 at the bottom). This is a filtering decision — belongs in marts.
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.prodes_clean AS
SELECT
    geocode_ibge,
    mun,
    CAST(year AS INTEGER) AS year,
    CAST(REPLACE("area km²", ',', '.') AS DOUBLE) AS area_km2
FROM project2.staging.prodes_raw
WHERE SUBSTR(geocode_ibge, 1, 2) IN (
    '11','12','13','14','15','16','17',  -- RO, AC, AM, RR, PA, AP, TO (fully in the Legal Amazon)
    '21',                                 -- MA (the panel's 181 MA munis are the Legal Amazon set)
    '51'                                  -- MT (fully in the Legal Amazon)
);  -- drops GO(52)/PI(22)/MS(50)/BA(29): outside the Legal Amazon, zero deforestation

----------------------------------------------------------
-- municipality_ref
-- Extracts name/uf from the raw nested JSON. Source of truth for
-- name/state in every category, including absolute_gap (no record
-- in ibama_clean).
--
-- Actual JSON structure (confirmed, not assumed):
--   id (int, 7 digits) | nome (string) |
--   microrregiao.mesorregiao.UF.sigla  -- fails for 1 record
--     (Boa Esperança do Norte/MT, no microrregiao on file)
--   "regiao-imediata"."regiao-intermediaria".UF.sigla  -- 0 failures,
--     path used below for full coverage
-- The two UF paths never diverge across the 5,570 records where
-- both exist. Choosing between them is a standardization decision —
-- this is why this table lives in marts, not staging.
-- Expected: 5,571 rows.
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.municipality_ref AS
SELECT
    CAST(id AS VARCHAR)                                AS geocode_ibge,
    nome                                                AS municipality_name,
    "regiao-imediata"."regiao-intermediaria".UF.sigla   AS uf
FROM project2.staging.municipality_ref_raw;

----------------------------------------------------------
-- municipality_area
-- Casts area to DOUBLE and drops the 2 trailing garbage rows (one
-- blank, one an OBS footnote) from the raw file — a filtering
-- decision, which is why this belongs in marts, not staging.
-- Expected: 5,573 rows | all 772 PRODES geocodes match (100% coverage,
-- no duplicates). Note: the IBGE localities API returns 5,571
-- municipalities while this area file has 5,573 — a 2-record
-- divergence between IBGE sources, not investigated further; it does
-- not affect the 772 PRODES municipalities (100% coverage in both).
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.municipality_area AS
SELECT
    CD_MUN                                          AS geocode_ibge,
    CAST(REPLACE(AR_MUN_2025, ',', '.') AS DOUBLE)  AS area_municipio_km2
FROM project2.staging.municipality_area_raw
WHERE LENGTH(CD_MUN) = 7;   -- drops the trailing blank/OBS footer rows

----------------------------------------------------------
-- ipca_annual (the deflator ratio itself lives in 03_analytics.sql)
-- UNPIVOTs the wide month-columns format into long, filters out the
-- Sidra footer/legend rows that null_padding leaked into the month
-- columns (only values shaped like an index pass the regex), casts
-- to DOUBLE, and averages to one row per year. This is filter + type
-- + standardize — the same category of work as ibama_clean/
-- prodes_clean, not a derived index (that's the deflator ratio,
-- analytics-layer).
-- DECISION: 2025 base = average of the year's monthly indices
--           (infraction notices are drafted throughout the year;
--           peak in Sep-Oct) — the averaging itself happens here;
--           analytics.ipca_deflator only divides by it.
-- Expected: 18 rows.
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.ipca_annual AS
WITH long AS (
    UNPIVOT project2.staging.ipca_raw ON COLUMNS('\d{4}$') INTO NAME month VALUE index
)
SELECT
    CAST(regexp_extract(month, '(\d{4})$', 1) AS INTEGER) AS year,
    AVG(CAST(REPLACE(index, ',', '.') AS DOUBLE))         AS avg_index
FROM long
-- Sidra's legend footer leaks strings into the month columns via
-- null_padding; only values shaped like an index ('2746.37...') pass
WHERE regexp_matches(index, '^\d+(,\d+)?$')
GROUP BY year
ORDER BY year;

----------------------------------------------------------
-- == MARTS CHECKS ==
-- Single consolidated query, one result grid instead of one tab per
-- check. Run after all five CREATE TABLE blocks above.
----------------------------------------------------------

WITH checks AS (
    SELECT 'n_ibama_clean' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '60707' AS expected FROM project2.marts.ibama_clean
    UNION ALL SELECT 'null_year_ibama_clean', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.ibama_clean WHERE year IS NULL
    UNION ALL SELECT 'min_year_ibama_clean', CAST(MIN(year) AS VARCHAR), '2008' FROM project2.marts.ibama_clean
    UNION ALL SELECT 'max_year_ibama_clean', CAST(MAX(year) AS VARCHAR), '2025' FROM project2.marts.ibama_clean
    UNION ALL SELECT 'negative_fine_ibama_clean', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.ibama_clean WHERE fine_value < 0
    UNION ALL SELECT 'total_fines_ibama_clean', CAST(CAST(ROUND(SUM(fine_value)) AS BIGINT) AS VARCHAR), '26814492927' FROM project2.marts.ibama_clean
    UNION ALL SELECT 'n_rows_prodes_clean', CAST(COUNT(*) AS VARCHAR), '13896' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'n_geocodes_prodes_clean', CAST(COUNT(DISTINCT geocode_ibge) AS VARCHAR), '772' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'n_years_prodes_clean', CAST(COUNT(DISTINCT year) AS VARCHAR), '18' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'na_geocode_prodes_clean', CAST(SUM(CASE WHEN geocode_ibge IS NULL THEN 1 ELSE 0 END) AS VARCHAR), '0' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'na_year_prodes_clean', CAST(SUM(CASE WHEN year IS NULL THEN 1 ELSE 0 END) AS VARCHAR), '0' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'na_area_prodes_clean', CAST(SUM(CASE WHEN area_km2 IS NULL THEN 1 ELSE 0 END) AS VARCHAR), '0' FROM project2.marts.prodes_clean
    -- n_years_prodes_clean counts 18 DISTINCT years but does not guarantee
    -- the range, hence the min/max checks alongside it.
    UNION ALL SELECT 'negative_area_prodes_clean', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.prodes_clean WHERE area_km2 < 0
    UNION ALL SELECT 'min_year_prodes_clean', CAST(MIN(year) AS VARCHAR), '2008' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'max_year_prodes_clean', CAST(MAX(year) AS VARCHAR), '2025' FROM project2.marts.prodes_clean
    -- total_area_prodes_clean: a magnitude check on the PRODES side, mirroring
    -- total_fines_ibama_clean. Without it, a swapped/corrupted CSV with the
    -- right shape (counts, years, non-negativity OK) would pass every other
    -- check with wrong areas. Value is the panel's 2008-2025 sum, km2 rounded.
    UNION ALL SELECT 'total_area_prodes_clean', CAST(CAST(ROUND(SUM(area_km2)) AS BIGINT) AS VARCHAR), '140019' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'n_municipality_ref', CAST(COUNT(*) AS VARCHAR), '5571' FROM project2.marts.municipality_ref
    UNION ALL SELECT 'duplicate_geocodes_ref', CAST(COUNT(*) AS VARCHAR), '0' FROM (SELECT geocode_ibge FROM project2.marts.municipality_ref GROUP BY geocode_ibge HAVING COUNT(*) > 1) d
    UNION ALL SELECT 'invalid_ref_geocode', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.municipality_ref WHERE LENGTH(geocode_ibge) != 7
    UNION ALL SELECT 'missing_uf_ref', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.municipality_ref WHERE uf IS NULL
    UNION ALL SELECT 'missing_reference_prodes_to_ref', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.staging.prodes_raw p LEFT JOIN project2.marts.municipality_ref r ON p.geocode_ibge = r.geocode_ibge WHERE r.geocode_ibge IS NULL
    UNION ALL SELECT 'n_municipality_area', CAST(COUNT(*) AS VARCHAR), '5573' FROM project2.marts.municipality_area
    UNION ALL SELECT 'duplicate_area_geocodes', CAST(COUNT(*) AS VARCHAR), '0' FROM (SELECT geocode_ibge FROM project2.marts.municipality_area GROUP BY geocode_ibge HAVING COUNT(*) > 1) d
    UNION ALL SELECT 'missing_area_prodes_to_area', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.staging.prodes_raw p LEFT JOIN project2.marts.municipality_area a ON p.geocode_ibge = a.geocode_ibge WHERE a.geocode_ibge IS NULL
    UNION ALL SELECT 'n_ipca_annual', CAST(COUNT(*) AS VARCHAR), '18' FROM project2.marts.ipca_annual
    -- ipca_months_not_12 mirrors a check the R side already runs
    -- (exploration/exploring_script.R: stopifnot(all(count(ipca_raw, year)$n
    -- == 12))). A malformed month silently dropped by ignore_errors/the regex
    -- filter would shrink AVG(avg_index) to 11 months without tripping
    -- n_ipca_annual (the year would still be present) or invalid_deflator
    -- (still positive) — a silent, undetected skew.
    UNION ALL SELECT 'ipca_months_not_12', CAST(COUNT(*) AS VARCHAR), '0' FROM (
        SELECT CAST(regexp_extract(month, '(\d{4})$', 1) AS INTEGER) AS year, COUNT(*) AS n_months
        FROM (UNPIVOT project2.staging.ipca_raw ON COLUMNS('\d{4}$') INTO NAME month VALUE index) long
        WHERE regexp_matches(index, '^\d+(,\d+)?$')
        GROUP BY year
    ) x WHERE n_months != 12
)
SELECT check_name, actual, expected,
       CASE WHEN actual = expected THEN 'OK' ELSE 'failed' END AS status
FROM checks
ORDER BY status DESC, check_name;   -- 'failed' > 'OK' na colação binária: falhas no topo
