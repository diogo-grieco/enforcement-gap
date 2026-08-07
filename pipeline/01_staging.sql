----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 01_staging.sql: raw data ingestion
--
-- Author: Diogo Grieco
--
-- Purpose: ingest raw files into DuckDB with no analytical
--          transformation (everything VARCHAR for the CSV sources;
--          the JSON source keeps read_json_auto's inferred types,
--          untouched; typing/standardization happens in marts).
------------------------------------------------------------
--
------------------------------------------------------------
-- CONFIGURATION
-- Edit this line to your local project clone path before running. 
------------------------------------------------------------

SET VARIABLE data_root = 'C:/Users/diogo/projects/project2';

CREATE SCHEMA IF NOT EXISTS project2.staging;
CREATE SCHEMA IF NOT EXISTS project2.marts;
CREATE SCHEMA IF NOT EXISTS project2.analytics;

----------------------------------------------------------
-- prodes_raw
-- Source: INPE/TerraBrasilis (manual download)
-- Granularity: municipality-year | Expected: 14,490 x 5
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.prodes_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data/data_prodes/terrabrasilis_legal_amazon_*.csv',
    delim = ';',
    header = true,
    all_varchar = true    -- typing happens in marts (mirrors R)
);

----------------------------------------------------------
-- ibama_raw
-- Source: IBAMA open data (manual download, 1 csv/year). Public
--         release: 13 of 84 raw columns, NOME_INFRATOR dropped, and
--         CPF_CNPJ_INFRATOR replaced by a random surrogate id (pid_); 
--         cf. data/data_ibama_public/README.md
-- Granularity: infraction notice | Expected: 309,116 x 13
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.ibama_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data/data_ibama_public/auto_infracao_ano_*.csv',
    delim = ';',
    quote = '"',           -- required as rows contain ';' inside quoted fields
    header = true,
    all_varchar = true
);

----------------------------------------------------------
-- ipca_raw
-- Source: IBGE/Sidra t.1737 v.2266 (index number, dec/93=100),
--         Brazil, jan/2008-dec/2025, downloaded 2026-07-10
-- Wide format, one column per month, everything text.
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.ipca_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data/data_ipca/sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv',
    delim = ';',
    skip = 3,
    header = true,
    all_varchar = true,
    null_padding = true,
    ignore_errors = true,
    parallel = false
);

----------------------------------------------------------
-- municipality_ref_raw
-- Source: IBGE localities API (servicodados.ibge.gov.br/
--         api/v1/localidades/municipios), downloaded manually via
--         browser on 2026-07-12 (the DTB/xls site was unreachable).
-- Saved as data_ibge/municipios.json.
-- Expected: 5,571 rows (verified 2026-07-12 against the real file).
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.municipality_ref_raw AS
SELECT * FROM read_json_auto(getvariable('data_root') || '/data/data_ibge/municipios.json');

----------------------------------------------------------
-- municipality_area_raw
-- Source: IBGE, Malha Municipal Digital: Áreas Territoriais, file
--         AR_BR_RG_UF_RGINT_RGI_MUN_2025.xls, downloaded 2026-07-20.
-- The source is a legacy .xls; converted once to CSV 
-- Expected: 5,575 rows (5,573 municipalities + 2 garbage rows).
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.municipality_area_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data/data_ibge/municipality_area_2025.csv',
    delim = ',',
    header = true,
    all_varchar = true
);

----------------------------------------------------------
-- == STAGING CHECKS ==
----------------------------------------------------------

WITH checks AS (
    SELECT '01_n_prodes' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '14490' AS expected FROM project2.staging.prodes_raw
    UNION ALL SELECT '02_n_ibama', CAST(COUNT(*) AS VARCHAR), '309116' FROM project2.staging.ibama_raw
    UNION ALL SELECT '03_n_prodes_columns', CAST(COUNT(*) AS VARCHAR), '5' FROM information_schema.columns WHERE table_catalog='project2' AND table_schema='staging' AND table_name='prodes_raw'
    UNION ALL SELECT '04_n_ibama_columns', CAST(COUNT(*) AS VARCHAR), '13' FROM information_schema.columns WHERE table_catalog='project2' AND table_schema='staging' AND table_name='ibama_raw'
    -- Expected 29, not 0: 23 malformed + 6 null geocodes in the raw IBAMA file.
    UNION ALL SELECT '05_invalid_geocode_ibama', CAST(COUNT(*) AS VARCHAR), '29' FROM project2.staging.ibama_raw WHERE COD_MUNICIPIO IS NULL OR LENGTH(COD_MUNICIPIO) != 7
    -- Expected 33, not 0: the PRODES export ships 33 municipalities outside the Legal Amazon.
    UNION ALL SELECT '06_out_of_scope_geocodes_prodes', CAST(COUNT(DISTINCT geocode_ibge) AS VARCHAR), '33' FROM project2.staging.prodes_raw WHERE SUBSTR(geocode_ibge, 1, 2) NOT IN ('11','12','13','14','15','16','17','21','51')
    UNION ALL SELECT '07_n_municipality_ref_raw', CAST(COUNT(*) AS VARCHAR), '5571' FROM project2.staging.municipality_ref_raw
    UNION ALL SELECT '08_n_municipality_area_raw', CAST(COUNT(*) AS VARCHAR), '5575' FROM project2.staging.municipality_area_raw
)
SELECT check_name, actual, expected,
       CASE WHEN actual = expected THEN 'OK' ELSE 'failed' END AS status
FROM checks
ORDER BY status DESC, check_name; 
