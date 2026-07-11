----------------------------------------------------------
-- Enforcement Gap Monitoring System
-- 04_export.sql — feeds do dashboard (Power BI)
--
-- Author:  Diogo Grieco
-- Updated: v2-2026-07-10
--
-- Purpose: materializar as tabelas analíticas como parquet
--          em output/ (pasta fora do git; regenerável).
-- Rodar somente após 01-03 validados pelos checks.
----------------------------------------------------------

COPY project2.analytics.egs_final
    TO 'output/pbi_egs_final.parquet' (FORMAT PARQUET);

COPY project2.analytics.ranking_gap_absoluto
    TO 'output/pbi_ranking_gap_absoluto.parquet' (FORMAT PARQUET);

COPY project2.analytics.ranking_completo
    TO 'output/pbi_ranking_completo.parquet' (FORMAT PARQUET);

COPY project2.analytics.resumo_anual
    TO 'output/pbi_resumo_anual.parquet' (FORMAT PARQUET);
