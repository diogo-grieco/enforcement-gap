----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 02_marts.sql: clean, typed tables
--
-- Author: Diogo Grieco
--
-- Purpose: filter, type, and standardize the columns consumed
--          by the downstream layers.
----------------------------------------------------------

----------------------------------------------------------
-- ibama_clean
-- Filter: 3 cases, mirrors exploration/exploring_script.R.
-- DECISION (date column): DAT_HORA_AUTO_INFRACAO, not DT_FATO_INFRACIONAL
--   (NA rates compared in exploring_script.R).
-- Note: year here is calendar (Jan-Dec), not PRODES's Aug-Jul window;
--   cf. 03_analytics.sql and the extended report (decision table, item 6).
-- TRY_CAST (not CAST): malformed dates become NULL, caught by the
--   null_year check below, not an aborted script.
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
-- Source of truth for name/uf, including absolute_gap.
-- UF path used: "regiao-imediata"."regiao-intermediaria".UF.sigla
-- (0 failures; alternate microrregiao path fails for Boa Esperança do Norte/MT).
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
-- Drops the 2 trailing garbage rows (blank + OBS footnote) from the raw file.
-- Expected: 5,573 rows | all 772 PRODES geocodes match (100% coverage).
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.municipality_area AS
SELECT
    CD_MUN                                          AS geocode_ibge,
    CAST(REPLACE(AR_MUN_2025, ',', '.') AS DOUBLE)  AS area_municipio_km2
FROM project2.staging.municipality_area_raw
WHERE LENGTH(CD_MUN) = 7;   -- drops the trailing blank/OBS footer rows

----------------------------------------------------------
-- ipca_annual
-- Averages the 12 monthly indices into one value per year, since
-- infraction notices are drafted throughout the year, not concentrated
-- in one month (cf. exploring_script.R monthly distribution). Base for
-- analytics.ipca_deflator.
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
----------------------------------------------------------

WITH checks AS (
    SELECT '01_n_ibama_clean' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '60707' AS expected FROM project2.marts.ibama_clean
    UNION ALL SELECT '02_null_year_ibama_clean', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.ibama_clean WHERE year IS NULL
    UNION ALL SELECT '03_min_year_ibama_clean', CAST(MIN(year) AS VARCHAR), '2008' FROM project2.marts.ibama_clean
    UNION ALL SELECT '04_max_year_ibama_clean', CAST(MAX(year) AS VARCHAR), '2025' FROM project2.marts.ibama_clean
    UNION ALL SELECT '05_negative_fine_ibama_clean', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.ibama_clean WHERE fine_value < 0
    UNION ALL SELECT '06_total_fines_ibama_clean', CAST(CAST(ROUND(SUM(fine_value)) AS BIGINT) AS VARCHAR), '26814492927' FROM project2.marts.ibama_clean
    UNION ALL SELECT '07_n_rows_prodes_clean', CAST(COUNT(*) AS VARCHAR), '13896' FROM project2.marts.prodes_clean
    UNION ALL SELECT '08_n_geocodes_prodes_clean', CAST(COUNT(DISTINCT geocode_ibge) AS VARCHAR), '772' FROM project2.marts.prodes_clean
    UNION ALL SELECT '09_n_years_prodes_clean', CAST(COUNT(DISTINCT year) AS VARCHAR), '18' FROM project2.marts.prodes_clean
    UNION ALL SELECT '10_na_geocode_prodes_clean', CAST(SUM(CASE WHEN geocode_ibge IS NULL THEN 1 ELSE 0 END) AS VARCHAR), '0' FROM project2.marts.prodes_clean
    UNION ALL SELECT '11_na_year_prodes_clean', CAST(SUM(CASE WHEN year IS NULL THEN 1 ELSE 0 END) AS VARCHAR), '0' FROM project2.marts.prodes_clean
    UNION ALL SELECT '12_na_area_prodes_clean', CAST(SUM(CASE WHEN area_km2 IS NULL THEN 1 ELSE 0 END) AS VARCHAR), '0' FROM project2.marts.prodes_clean
    -- n_years counts DISTINCT years only; min/max below confirm the range.
    UNION ALL SELECT '13_negative_area_prodes_clean', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.prodes_clean WHERE area_km2 < 0
    UNION ALL SELECT '14_min_year_prodes_clean', CAST(MIN(year) AS VARCHAR), '2008' FROM project2.marts.prodes_clean
    UNION ALL SELECT '15_max_year_prodes_clean', CAST(MAX(year) AS VARCHAR), '2025' FROM project2.marts.prodes_clean
    -- Magnitude check (mirrors total_fines_ibama_clean): catches a
    -- wrong-shape-but-valid CSV swap.
    UNION ALL SELECT '16_total_area_prodes_clean', CAST(CAST(ROUND(SUM(area_km2)) AS BIGINT) AS VARCHAR), '140019' FROM project2.marts.prodes_clean
    UNION ALL SELECT '17_n_municipality_ref', CAST(COUNT(*) AS VARCHAR), '5571' FROM project2.marts.municipality_ref
    UNION ALL SELECT '18_duplicate_geocodes_ref', CAST(COUNT(*) AS VARCHAR), '0' FROM (SELECT geocode_ibge FROM project2.marts.municipality_ref GROUP BY geocode_ibge HAVING COUNT(*) > 1) d
    UNION ALL SELECT '19_invalid_ref_geocode', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.municipality_ref WHERE LENGTH(geocode_ibge) != 7
    UNION ALL SELECT '20_missing_uf_ref', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.municipality_ref WHERE uf IS NULL
    UNION ALL SELECT '21_missing_reference_prodes_to_ref', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.staging.prodes_raw p LEFT JOIN project2.marts.municipality_ref r ON p.geocode_ibge = r.geocode_ibge WHERE r.geocode_ibge IS NULL
    UNION ALL SELECT '22_n_municipality_area', CAST(COUNT(*) AS VARCHAR), '5573' FROM project2.marts.municipality_area
    UNION ALL SELECT '23_duplicate_area_geocodes', CAST(COUNT(*) AS VARCHAR), '0' FROM (SELECT geocode_ibge FROM project2.marts.municipality_area GROUP BY geocode_ibge HAVING COUNT(*) > 1) d
    UNION ALL SELECT '24_missing_area_prodes_to_area', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.staging.prodes_raw p LEFT JOIN project2.marts.municipality_area a ON p.geocode_ibge = a.geocode_ibge WHERE a.geocode_ibge IS NULL
    -- missing_legal_amazon_munis: expected 1, not 0. Boa Esperança do
    -- Norte/MT (5101837) split from Nova Ubiratã in 2025, too new for the
    -- PRODES mesh. Consequence for pct_desmatado (5106240): cf. the
    -- extended report's Nova Ubiratã note.
    UNION ALL SELECT '25_missing_legal_amazon_munis', CAST(COUNT(*) AS VARCHAR), '1'
        FROM project2.marts.municipality_ref r
        LEFT JOIN (SELECT DISTINCT geocode_ibge FROM project2.marts.prodes_clean) p
            ON r.geocode_ibge = p.geocode_ibge
        WHERE r.uf IN ('RO','AC','AM','RR','PA','AP','TO','MT') AND p.geocode_ibge IS NULL
    UNION ALL SELECT '26_n_ipca_annual', CAST(COUNT(*) AS VARCHAR), '18' FROM project2.marts.ipca_annual
    -- Mirrors the 12-month check on the R side (exploring_script.R). A
    -- dropped month would skew avg_index undetected by n_ipca_annual or
    -- invalid_deflator.
    UNION ALL SELECT '27_ipca_months_not_12', CAST(COUNT(*) AS VARCHAR), '0' FROM (
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
