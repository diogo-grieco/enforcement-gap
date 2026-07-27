----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 01_staging.sql — raw data ingestion
--
-- Author: Diogo Grieco
--
-- Purpose: ingest raw files into DuckDB with no analytical
--          transformation (everything VARCHAR for the CSV sources;
--          the JSON source keeps read_json_auto's inferred types,
--          untouched — typing/standardization happens in marts).
--          Every table in this file is SELECT * with no WHERE
--          clause (all_varchar = true on every CSV read) — if you find
--          a CAST, a WHERE, or a computed column below, it doesn't
--          belong in this file.
--
-- CONFIGURATION — edit this line to your local project clone
-- path before running. Single configuration point for the
-- pipeline; getvariable() resolves the same way in DBeaver,
-- CLI, or R, without depending on the process's working
-- directory.
----------------------------------------------------------

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
    all_varchar = true    -- deterministic typing happens in marts (mirrors R)
);

----------------------------------------------------------
-- ibama_raw
-- Source: IBAMA open data (manual download, 1 csv/year).
-- Public release: 13 of the 84 raw columns (the ones actually used
-- anywhere in this pipeline or in viz/04_raw_ibama.R). NOME_INFRATOR
-- is dropped (never used); CPF_CNPJ_INFRATOR is replaced with a stable
-- RANDOM surrogate id (pid_ + 16 random hex, one per offender) — the
-- surrogate preserves equality, so offender counts (Lorenz curve,
-- offender network) are unchanged. Because it is random (not derived
-- from the CPF/CNPJ), the pid_ ITSELF is not reversible: no salt or
-- known function maps a candidate CPF back to it, and the mapping is
-- kept local and never versioned.
-- That is NOT the same as anonymised. The other 12 columns are verbatim
-- copies of the public IBAMA CSV, which does carry NOME_INFRATOR — and
-- (COD_MUNICIPIO, DAT_HORA_AUTO_INFRACAO, VAL_AUTO_INFRACAO) uniquely
-- identifies 74.3% of the rows, so the source can be re-joined. This
-- folder is a reduced copy of a public administrative dataset, not a
-- de-identified one; the pid_ exists so that THIS repo does not
-- redistribute CPF/CNPJ, not to prevent re-identification of a record
-- the agency publishes with identification.
-- See data/data_ibama_public/README.md.
--
-- quote = '"' IS REQUIRED — do not remove it as redundant. 86 rows across
-- the 2019-2025 files carry a ';' INSIDE a quoted field (multi-value embargo
-- term codes, e.g. "3SQPDOXW;47UJ5XGX"). The CSV sniffer only samples the
-- FIRST file of the glob (2008), which has no quoted fields at all, so it
-- infers quote = (empty) and then reads those 86 rows as having 14 columns.
-- DuckDB <= 1.1.x happened to guess '"' anyway and the file loaded; from
-- 1.2.0 on, strict_mode turns the same guess into a hard abort
-- ("CSV Error on Line: 14421 ... Expected Number of Columns: 13 Found: 14").
-- Declaring the quote character makes the read independent of both the
-- sniffer's sample and the DuckDB version. Row count is 309,116 either way.
-- Granularity: infraction notice | Expected: 309,116 x 13
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.ibama_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data/data_ibama_public/auto_infracao_ano_*.csv',
    delim = ';',
    quote = '"',          -- required: see note above (86 rows have ';' inside quotes)
    header = true,
    all_varchar = true
);

----------------------------------------------------------
-- ipca_raw
-- Source: IBGE/Sidra t.1737 v.2266 (index number, dec/93=100),
--         Brazil, jan/2008-dec/2025, downloaded 2026-07-10
-- Wide format, one column per month, everything text. No UNPIVOT,
-- no cast, no filtering here — that's marts.ipca_annual. The reader
-- options below (skip, null_padding, ignore_errors, parallel=false)
-- are file-parsing mechanics, not analytical decisions: they exist
-- because Sidra's export has a multi-line title, a footer with a
-- line break inside quotes, and legend rows that would otherwise
-- break the CSV scanner — same category as all_varchar above, not
-- a judgment call about the data's meaning.
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.ipca_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data/data_ipca/sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv',
    delim = ';', skip = 3, header = true,
    all_varchar = true, null_padding = true, ignore_errors = true,
    parallel = false
);

----------------------------------------------------------
-- municipality_ref_raw
-- Source: IBGE localities API (servicodados.ibge.gov.br/
-- api/v1/localidades/municipios), downloaded manually via
-- browser on 2026-07-12 (the DTB/xls site was unreachable).
-- Save the JSON as data_ibge/municipios.json.
-- Raw nested structure, no field extraction — that's
-- marts.municipality_ref. read_json_auto infers the nested STRUCT
-- types (microrregiao.mesorregiao.UF.sigla,
-- "regiao-imediata"."regiao-intermediaria".UF.sigla, etc.) without
-- picking a path; the decision of which path to standardize on is a
-- typing/selection call, not raw ingestion.
-- Expected: 5,571 rows (verified 2026-07-12 against the real file).
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.municipality_ref_raw AS
SELECT * FROM read_json_auto(getvariable('data_root') || '/data/data_ibge/municipios.json');

----------------------------------------------------------
-- municipality_area_raw
-- Source: IBGE, Malha Municipal Digital — Áreas Territoriais
-- (https://www.ibge.gov.br/geociencias/organizacao-do-territorio/
-- estrutura-territorial/15761-areas-dos-municipios.html), file
-- AR_BR_RG_UF_RGINT_RGI_MUN_2025.xls, downloaded 2026-07-20.
--
-- DECISION: the source is a legacy binary .xls. Rather than add an
-- unverified DuckDB extension dependency (GDAL/xlsx reader) for a
-- static reference table, convert it once (Excel, LibreOffice, or an
-- online converter — Diogo used an online converter, confirmed
-- working) and read it exactly like every other source in this
-- pipeline. Save as data_ibge/municipality_area_2025.csv before
-- running this block.
--
-- VERIFY BEFORE RUNNING: delim below is ',' — confirmed against the
-- actual converted file (2026-07-20). If you regenerate this CSV with
-- a different tool (e.g. Excel/LibreOffice "Save As", which tends to
-- follow the Brazilian ';' convention of every other CSV in this
-- project), open it once and check before trusting the row count.
--
-- No CAST, no WHERE here — the 2 trailing garbage rows (one blank,
-- one an OBS footnote) are still present in this raw table; dropping
-- them is a filtering decision, done in marts.municipality_area.
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
-- Only checks that don't require typed/extracted/computed fields —
-- everything downstream of a CAST, a WHERE, or a UNPIVOT belongs in
-- 02_marts.sql's checks instead.
----------------------------------------------------------

WITH checks AS (
    SELECT 'n_prodes' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '14490' AS expected FROM project2.staging.prodes_raw
    UNION ALL SELECT 'n_ibama', CAST(COUNT(*) AS VARCHAR), '309116' FROM project2.staging.ibama_raw
    UNION ALL SELECT 'n_prodes_columns', CAST(COUNT(*) AS VARCHAR), '5' FROM information_schema.columns WHERE table_catalog='project2' AND table_schema='staging' AND table_name='prodes_raw'
    UNION ALL SELECT 'n_ibama_columns', CAST(COUNT(*) AS VARCHAR), '13' FROM information_schema.columns WHERE table_catalog='project2' AND table_schema='staging' AND table_name='ibama_raw'
    -- invalid_geocode_ibama: expected is 29, not 0.
    -- IS NULL is required in addition to LENGTH(...) != 7 — DuckDB's
    -- LENGTH(NULL) evaluates to NULL, not a number, so a plain "!= 7"
    -- alone silently passes NULL geocodes through the WHERE clause.
    -- 23 rows are COD_MUNICIPIO = '431173' (Manoel Viana, RS — malformed
    -- 6-digit code; the correct IBGE code is 4311759, verified against
    -- municipios.json. Corruption mechanism unknown — NOT a leading-zero
    -- drop: no IBGE code starts with 0; UF prefixes run 11-53.)
    -- 6 rows have COD_MUNICIPIO IS NULL (garbage rows). Neither group
    -- affects egs_final (RS is outside the Legal Amazon; the NULL rows
    -- fail the ibama_clean status filter anyway) — documented, not corrected.
    UNION ALL SELECT 'invalid_geocode_ibama', CAST(COUNT(*) AS VARCHAR), '29' FROM project2.staging.ibama_raw WHERE COD_MUNICIPIO IS NULL OR LENGTH(COD_MUNICIPIO) != 7
    -- out_of_scope_geocodes_prodes: expected is 33, not 0 — same spirit as
    -- invalid_geocode_ibama above. The TerraBrasilis export labelled
    -- "legal_amazon" ships 805 municipalities, but 33 of them sit in states
    -- OUTSIDE the Legal Amazon (GO 18, PI 6, MS 5, BA 4), each with
    -- area = 0 in all 18 years. 805 - 33 = 772, the official Legal Amazon
    -- count; 02_marts.sql filters them out of prodes_clean by geocode prefix.
    -- This check watches the SOURCE, not the filter (a check on prodes_clean
    -- would be tautological — the WHERE there guarantees 0 by construction;
    -- n_geocodes_prodes_clean = 772 already guards that side). If a future
    -- PRODES download changes which municipalities it ships, this fires and
    -- the marts filter must be revisited before trusting the panel.
    UNION ALL SELECT 'out_of_scope_geocodes_prodes', CAST(COUNT(DISTINCT geocode_ibge) AS VARCHAR), '33' FROM project2.staging.prodes_raw WHERE SUBSTR(geocode_ibge, 1, 2) NOT IN ('11','12','13','14','15','16','17','21','51')
    UNION ALL SELECT 'n_municipality_ref_raw', CAST(COUNT(*) AS VARCHAR), '5571' FROM project2.staging.municipality_ref_raw
    UNION ALL SELECT 'n_municipality_area_raw', CAST(COUNT(*) AS VARCHAR), '5575' FROM project2.staging.municipality_area_raw
)
SELECT check_name, actual, expected,
       CASE WHEN actual = expected THEN 'OK' ELSE 'failed' END AS status
FROM checks
ORDER BY status DESC, check_name;   -- 'failed' > 'OK' na colação binária: falhas no topo
