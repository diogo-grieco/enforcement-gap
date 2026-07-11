----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 01_staging.sql — ingestão de dados brutos
--
-- Author:  Diogo Grieco
-- Updated: v2.2-2026-07-10 (fixes IPCA: parallel=false; filtro de
--          formato numérico contra vazamento do rodapé do Sidra)
--
-- Purpose: ingerir arquivos raw no DuckDB sem transformação
--          analítica (tudo VARCHAR; tipagem no marts).
-- Nota:    caminhos relativos à raiz do projeto (project2/).
----------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS project2.staging;
CREATE SCHEMA IF NOT EXISTS project2.marts;
CREATE SCHEMA IF NOT EXISTS project2.analytics;

----------------------------------------------------------
-- prodes_raw
-- Fonte: INPE/TerraBrasilis (download manual)
-- Granularidade: município-ano | Esperado: 14.490 x 5
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.prodes_raw AS
SELECT * FROM read_csv(
    'data_prodes/terrabrasilis_legal_amazon_*.csv',
    delim = ';',
    header = true,
    all_varchar = true    -- tipagem determinística no marts (espelha o R)
);

----------------------------------------------------------
-- ibama_raw
-- Fonte: IBAMA dados abertos (download manual, 1 csv/ano)
-- Granularidade: auto de infração | Esperado: 309.116 x 84
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.ibama_raw AS
SELECT * FROM read_csv(
    'data_ibama/auto_infracao_ano_*.csv',
    delim = ';',
    header = true,
    all_varchar = true
);

----------------------------------------------------------
-- ipca_deflator
-- Fonte: IBGE/Sidra t.1737 v.2266 (número-índice, dez/93=100),
--        Brasil, jan/2008-dez/2025, download 2026-07-10
-- DECISÃO: base 2025 = média dos índices mensais do ano
--          (lavraturas distribuem-se pelo ano; pico set-out)
-- Formato largo do Sidra: UNPIVOT seleciona colunas-mês por
-- regex; NULLs (rodapé de notas) descartados pelo UNPIVOT
-- Esperado: 18 linhas | deflator(2025) = 1.0 | deflator(2008) ~ 2.6
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.staging.ipca_deflator AS
WITH wide AS (
    SELECT * FROM read_csv(
        'data_ipca/sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv',
        delim = ';', skip = 3, header = true,
        all_varchar = true, null_padding = true, ignore_errors = true,
        -- rodapé do Sidra tem quebra de linha entre aspas: o scanner
        -- paralelo não suporta isso com null_padding (DuckDB >= 1.5)
        parallel = false)
),
long AS (
    UNPIVOT wide ON COLUMNS('\d{4}$') INTO NAME mes VALUE indice
),
anual AS (
    SELECT CAST(regexp_extract(mes, '(\d{4})$', 1) AS INTEGER) AS ano,
           AVG(CAST(REPLACE(indice, ',', '.') AS DOUBLE))      AS indice_medio
    FROM long
    -- rodapé de legenda do Sidra vaza strings para colunas-mês via
    -- null_padding; só valores com formato de índice ('2746,37...') entram
    WHERE regexp_matches(indice, '^\d+(,\d+)?$')
    GROUP BY ano
)
SELECT ano,
       (SELECT indice_medio FROM anual WHERE ano = 2025) / indice_medio AS deflator
FROM anual
ORDER BY ano;

----------------------------------------------------------
-- municipios_ref
-- PENDENTE: requer data_ibge/dtb_municipios.csv (DTB/IBGE,
-- download manual; ~5.570 linhas). Ajustar nomes de coluna
-- ao arquivo real antes de rodar.
-- Fonte de verdade para nome/UF em todas as categorias,
-- incluindo gap_absoluto (sem registro em ibama_clean).
----------------------------------------------------------

-- CREATE OR REPLACE TABLE project2.staging.municipios_ref AS
-- SELECT
--     CAST(codigo_municipio_completo AS VARCHAR) AS geocode_ibge,
--     nome_municipio,
--     sigla_uf AS uf
-- FROM read_csv('data_ibge/dtb_municipios.csv',
--               header = true, all_varchar = true);

----------------------------------------------------------
-- == CHECKS staging ==
----------------------------------------------------------

-- Contagens brutas (esperado: 14.490 | 309.116)
SELECT (SELECT COUNT(*) FROM project2.staging.prodes_raw) AS n_prodes,
       (SELECT COUNT(*) FROM project2.staging.ibama_raw)  AS n_ibama;

-- ipca_deflator cobre 2008-2025 (esperado: 0)
SELECT COUNT(*) AS anos_faltando
FROM (SELECT UNNEST(RANGE(2008, 2026)) AS ano) anos
LEFT JOIN project2.staging.ipca_deflator d USING (ano)
WHERE d.ano IS NULL;

-- deflator válido (esperado: 0)
SELECT COUNT(*) AS deflator_invalido
FROM project2.staging.ipca_deflator
WHERE deflator IS NULL OR deflator <= 0;

-- geocodes IBAMA com tamanho != 7 (esperado: 0, senão documentar)
SELECT COUNT(*) AS geocode_invalido
FROM project2.staging.ibama_raw
WHERE LENGTH(CAST(COD_MUNICIPIO AS VARCHAR)) != 7;

-- PENDENTE (após municipios_ref): PRODES sem referência (esperado: 0)
-- SELECT COUNT(*) AS sem_referencia
-- FROM project2.staging.prodes_raw p
-- LEFT JOIN project2.staging.municipios_ref r
--   ON p.geocode_ibge = r.geocode_ibge
-- WHERE r.geocode_ibge IS NULL;
