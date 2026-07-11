----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 02_marts.sql — tabelas limpas e tipadas
--
-- Author:  Diogo Grieco
-- Updated: v2-2026-07-10
--
-- Purpose: filtrar, tipar e padronizar colunas consumidas
--          pelas camadas seguintes (sem SELECT *).
----------------------------------------------------------

----------------------------------------------------------
-- ibama_clean
-- Filtro v3 (3 casos; espelha exploring_script.R, locked)
-- DECISÃO (data): DAT_HORA_AUTO_INFRACAO (lavratura, 0% NA)
--   em vez de DT_FATO_INFRACIONAL (71% NA na base filtrada).
--   Join no mesmo ano validado no exploring (só_t 4.8% vs
--   só_t1 0.7%).
-- Esperado: 60.707 linhas
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.ibama_clean AS
SELECT
    COD_MUNICIPIO AS geocode_ibge,
    EXTRACT(YEAR FROM CAST(DAT_HORA_AUTO_INFRACAO AS DATE)) AS ano,
    CAST(REPLACE(VAL_AUTO_INFRACAO, ',', '.') AS DOUBLE)    AS val_multa
FROM project2.staging.ibama_raw
WHERE
    SIT_CANCELADO         = 'N'
    AND DES_STATUS_FORMULARIO = 'Lavrado'
    AND (
        -- Case 1: Flora + Desmatamento (58.051; pipeline v1)
        (TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA = 'Desmatamento')
        -- Case 2: Flora, área NULL, código específico de desmatamento
        -- (2.129; concentrados 2008-2012, campo não obrigatório à época)
        OR (TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA IS NULL
            AND COD_INFRACAO IN (
                '409907', -- Destruir, desmatar, danificar florestas ou vegetação nativa
                '409901', -- Destruir ou danificar florestas em APP
                '452001', -- Destruir/desmatar florestas em APP (art. 2º Lei 4.771)
                '430001', -- Desmatar florestas sem autorização IBAMA
                '431003', -- Destruir ou danificar florestas em áreas especiais (art. 225 CF)
                '468001'  -- Destruir florestas nativas ou plantadas protetoras de mangues
            ))
        -- Case 3: tipo NULL, área = Desmatamento (527; mesmo padrão histórico)
        OR (TIPO_INFRACAO IS NULL AND INFRACAO_AREA = 'Desmatamento')
    );

----------------------------------------------------------
-- prodes_clean
-- Esperado: 14.490 linhas | 805 geocodes (800 nomes; 5 homônimos)
-- geocode_ibge já é string limpa de 7 dígitos no raw
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.marts.prodes_clean AS
SELECT
    geocode_ibge,
    mun,
    CAST(year AS INTEGER) AS ano,
    CAST(REPLACE("area km²", ',', '.') AS DOUBLE) AS area_km2
FROM project2.staging.prodes_raw;

----------------------------------------------------------
-- == CHECKS marts ==
----------------------------------------------------------

-- ibama_clean: contagem (esperado: 60.707)
SELECT COUNT(*) AS n_ibama_clean FROM project2.marts.ibama_clean;

-- ano sem NULL (esperado: 0)
SELECT COUNT(*) AS null_ano
FROM project2.marts.ibama_clean
WHERE ano IS NULL;

-- range de anos (esperado: 2008-2025)
SELECT MIN(ano) AS min_ano, MAX(ano) AS max_ano
FROM project2.marts.ibama_clean;

-- val_multa negativa (esperado: 0)
SELECT COUNT(*) AS multa_negativa
FROM project2.marts.ibama_clean
WHERE val_multa < 0;

-- val_multa total (esperado: ~26.814.492.927)
SELECT ROUND(SUM(val_multa)) AS total_multas
FROM project2.marts.ibama_clean;

-- prodes_clean: painel balanceado (esperado: 14.490 | 805 | 18)
SELECT COUNT(*)                    AS n_rows,
       COUNT(DISTINCT geocode_ibge) AS n_geocodes,
       COUNT(DISTINCT ano)          AS n_anos
FROM project2.marts.prodes_clean;

-- prodes_clean: NAs (esperado: 0 em todas)
SELECT SUM(CASE WHEN geocode_ibge IS NULL THEN 1 ELSE 0 END) AS na_geocode,
       SUM(CASE WHEN ano IS NULL          THEN 1 ELSE 0 END) AS na_ano,
       SUM(CASE WHEN area_km2 IS NULL     THEN 1 ELSE 0 END) AS na_area
FROM project2.marts.prodes_clean;
