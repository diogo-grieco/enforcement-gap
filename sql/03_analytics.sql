----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 03_analytics.sql — índice, classificação e rankings
--
-- Author:  Diogo Grieco
-- Updated: v2-2026-07-10
--
-- NOTA DE ESCALA: LOG() no DuckDB é base 10 (o log() do R é
-- natural). Escala é monotônica: rankings não mudam, mas
-- valores absolutos de EGS/priority_score assumem log10.
--
-- DECISÕES METODOLÓGICAS (2026-07-10, espelham exploring v5):
-- (a) MATERIALIDADE: area_km2 >= 1 km² em classificação e
--     rankings — ordem de grandeza acima da área mínima de
--     mapeamento do PRODES (6,25 ha), elimina desmatamento
--     residual sem relevância de priorização. area < 1 =
--     'sem_pressao' (sem pressão material).
-- (b) RESPOSTA EFETIVA: val_multas >= 0.01 — auto sem valor
--     pecuniário equivale a ausência de fiscalização
--     (decisão metodológica). gap_absoluto = desmatamento
--     material sem NENHUMA resposta com efeito pecuniário.
--     Checkpoint (R, exploring v5): gap_absoluto = 3.063.
-- (c) p75 do ranking completo: base tipo_egs = 'completo',
--     comparação >= (inclusivo).
-- (d) WHERE streak_length >= 3 roda ANTES do priority_score:
--     streak 1-2 não é zerado pelo LOG, é excluído por regra
--     de persistência (1 ciclo eleitoral + margem). Design,
--     não bug.
-- PENDENTE (Fix 2/3): deflacionar val_multa com
--     staging.ipca_deflator antes de somas plurianuais e p75.
----------------------------------------------------------

----------------------------------------------------------
-- egs_base: painel município-ano com pressão e resposta
-- Esperado: 14.490 linhas (herda o painel do PRODES)
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.egs_base AS
SELECT
    p.geocode_ibge,
    p.mun,
    p.ano,
    p.area_km2,
    COUNT(i.geocode_ibge)         AS n_autos,
    COALESCE(SUM(i.val_multa), 0) AS val_multas
FROM project2.marts.prodes_clean p
LEFT JOIN project2.marts.ibama_clean i
    ON  p.geocode_ibge = i.geocode_ibge
    AND p.ano          = i.ano
GROUP BY p.geocode_ibge, p.mun, p.ano, p.area_km2;

----------------------------------------------------------
-- egs_final: índice e classificação
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.egs_final AS
SELECT
    geocode_ibge,
    mun,
    ano,
    area_km2,
    n_autos,
    val_multas,
    CASE
        WHEN area_km2 >= 1 AND val_multas >= 0.01
            THEN LOG(1 + area_km2) / SQRT(LOG(1 + n_autos) * LOG(1 + val_multas))
        WHEN area_km2 >= 1
            THEN LOG(1 + area_km2)
        ELSE NULL   -- sem pressão material
    END AS egs,
    CASE
        WHEN area_km2 < 1          THEN 'sem_pressao'
        WHEN val_multas < 0.01     THEN 'gap_absoluto'
        ELSE                            'completo'
    END AS tipo_egs
    -- n_autos > 0 implícito no 'completo': val_multas >= 0.01 exige
    -- ao menos um auto com valor
FROM project2.analytics.egs_base;

----------------------------------------------------------
-- ranking_gap_absoluto: persistência sem resposta
-- Materialidade: area_km2 >= 1 | persistência >= 3 anos
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.ranking_gap_absoluto AS
WITH qualifying AS (
    SELECT geocode_ibge, mun, ano, area_km2,
           ROW_NUMBER() OVER (PARTITION BY geocode_ibge ORDER BY ano) AS rn
    FROM project2.analytics.egs_final
    -- area >= 1 redundante: garantido pela classificação
    WHERE tipo_egs = 'gap_absoluto'
),
streaks AS (
    SELECT geocode_ibge, mun,
           ano - rn      AS streak_group,
           COUNT(*)      AS streak_length,
           SUM(area_km2) AS area_no_streak,
           MIN(ano)      AS streak_start,
           MAX(ano)      AS streak_end
    FROM qualifying
    GROUP BY geocode_ibge, mun, ano - rn
)
-- múltiplos streaks qualificados no mesmo município: MAX pega o mais
-- longo, SUM acumula área de todos os streaks >= 3 (persistência total)
SELECT
    geocode_ibge, mun,
    MAX(streak_length)                                               AS max_streak,
    ROUND(SUM(area_no_streak), 1)                                    AS total_desmatado_km2,
    MIN(streak_start)                                                AS primeiro_ano,
    MAX(streak_end)                                                  AS ultimo_ano,
    ROUND(LOG(MAX(streak_length)) * LOG(1 + SUM(area_no_streak)), 3) AS priority_score
FROM streaks
WHERE streak_length >= 3
GROUP BY geocode_ibge, mun
ORDER BY priority_score DESC;

----------------------------------------------------------
-- ranking_completo: resposta presente mas desproporcional
-- p75 sobre completo | egs >= p75 (inclusivo)
-- (referência antiga 0.727 era da base v2; regerar sob v3)
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.ranking_completo AS
WITH p75 AS (
    SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY egs) AS p75_egs
    FROM project2.analytics.egs_final
    -- area >= 1 e egs NOT NULL redundantes: garantidos pela classificação
    WHERE tipo_egs = 'completo'
),
qualifying AS (
    SELECT e.geocode_ibge, e.mun, e.ano, e.egs, e.area_km2,
           ROW_NUMBER() OVER (PARTITION BY e.geocode_ibge ORDER BY e.ano) AS rn
    FROM project2.analytics.egs_final e
    CROSS JOIN p75
    WHERE e.tipo_egs = 'completo'
      AND e.egs >= p75.p75_egs
),
streaks AS (
    SELECT geocode_ibge, mun,
           ano - rn           AS streak_group,
           COUNT(*)           AS streak_length,
           ROUND(AVG(egs), 3) AS avg_egs,
           SUM(area_km2)      AS area_no_streak,
           MIN(ano)           AS streak_start,
           MAX(ano)           AS streak_end
    FROM qualifying
    GROUP BY geocode_ibge, mun, ano - rn
)
SELECT
    geocode_ibge, mun,
    MAX(streak_length)                                               AS max_streak,
    ROUND(AVG(avg_egs), 3)                                           AS egs_medio,
    ROUND(SUM(area_no_streak), 1)                                    AS total_desmatado_km2,
    MIN(streak_start)                                                AS primeiro_ano,
    MAX(streak_end)                                                  AS ultimo_ano,
    ROUND(LOG(MAX(streak_length)) * LOG(1 + SUM(area_no_streak)), 3) AS priority_score
FROM streaks
WHERE streak_length >= 3
GROUP BY geocode_ibge, mun
ORDER BY priority_score DESC;

----------------------------------------------------------
-- resumo_anual: visão geral para o dashboard
----------------------------------------------------------

CREATE OR REPLACE TABLE project2.analytics.resumo_anual AS
SELECT
    ano,
    COUNT(*)                                                    AS n_municipios,
    SUM(CASE WHEN tipo_egs = 'gap_absoluto' THEN 1 ELSE 0 END)  AS n_gap_absoluto,
    SUM(CASE WHEN tipo_egs = 'completo'     THEN 1 ELSE 0 END)  AS n_completo,
    SUM(CASE WHEN tipo_egs = 'sem_pressao'  THEN 1 ELSE 0 END)  AS n_sem_pressao,
    ROUND(SUM(area_km2), 1)                                     AS total_desmatado_km2,
    ROUND(AVG(CASE WHEN tipo_egs = 'completo' THEN egs END), 3) AS avg_egs_completo
FROM project2.analytics.egs_final
GROUP BY ano
ORDER BY ano;

----------------------------------------------------------
-- == CHECKS analytics ==
----------------------------------------------------------

-- painel preservado (esperado: 14.490)
SELECT COUNT(*) AS n_egs_final FROM project2.analytics.egs_final;

-- distribuição por tipo (checkpoint R exploring v5: gap_absoluto = 3.063)
SELECT tipo_egs, COUNT(*) AS n
FROM project2.analytics.egs_final
GROUP BY tipo_egs
ORDER BY tipo_egs;

-- p75 de referência (regerar sob v3 e registrar na session reference)
SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY egs) AS p75_egs
FROM project2.analytics.egs_final
WHERE tipo_egs = 'completo';
