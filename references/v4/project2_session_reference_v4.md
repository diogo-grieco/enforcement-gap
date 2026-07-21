# P2 — Enforcement Gap Monitoring System
## Session Reference v4
**Last updated:** 2026-07-10
**Status:** Staging: deflator IPCA implementado (`municipios_ref` ainda pendente). Marts: filtro 3 casos estável, UF removida sem substituto (regressão — ver §4.11 / Fix 12). Analytics: p75 dinâmico, classificação por materialidade consistente, bug de `priority_score` (streak=1) resolvido. Script R: v4, seções IBAMA + PRODES + IPCA presentes. Esta versão foi gerada por **auditoria de código** (comparação entre `01-04_*.sql`, `exploring_script.R` e a v3 deste documento) — não por relato direto do autor. Onde um número não pôde ser confirmado por um checkpoint existente no código, está marcado como não confirmado.

**⚠ Novo item crítico:** UF foi removida de `ibama_clean` sem que `municipios_ref` tenha sido criada. Nenhuma tabela do pipeline atual carrega UF. Bloqueia o choropleth do Power BI. Ver §4.11 e Fix 12 em `p2_technical_fixes.txt`.

---

### Changelog v4 (2026-07-10 — staging deflator, analytics v2, auditoria pós-v3)

- **`ipca_deflator` implementado** (`01_staging.sql`): UNPIVOT do formato largo do Sidra + filtro regex contra vazamento do rodapé de notas; `parallel = false` necessário para `null_padding` funcionar com quebras de linha entre aspas (DuckDB ≥ 1.5). Base 2025 = média dos índices mensais do ano.
- **Fix 2 (deflação de `val_multas`) aplicado**: `egs_base` agora expõe `val_multas_nominal` (auditoria) e `val_multas` (deflacionado, usado em todo o downstream). Cabeçalho de `03_analytics.sql` ainda lista o fix como "PENDENTE" — comentário desatualizado, corrigir.
- **p75 deixou de ser hardcoded**: antes fixo em 0.727 (citado na v3 §6.2), agora `PERCENTILE_CONT(0.75)` calculado em CTE a cada execução de `03_analytics.sql`. Resolvido via deflação (Fix 2), não via p75 por ano — ver `p2_technical_fixes.txt` Fix 3.
- **Bug `priority_score = 0` quando `streak = 1` resolvido**: não pela correção sugerida em v3 (`LOG(streak+1)`). O filtro `streak_length >= 3` roda antes da agregação, então `MAX(streak_length)` nunca é 1 no cálculo do score. Documentado como decisão de design no SQL. Ver Fix 10.
- **Classificação `tipo_egs` — ambiguidade v3 resolvida**: v3 tinha §4.4 (limite 1 km²) inconsistente com a tabela de §4.7 (limite >0 km²). Pipeline atual aplica `area_km2 >= 1` de forma consistente. gap_absoluto sob esse critério = 3.063 (era 3.784 sob `>0`). Ver Fix 11.
- **`egs` para `sem_pressao`: `0` → `NULL`**, mudança não documentada em nenhum changelog anterior — registrada retroativamente aqui. Ver Fix 13.
- **UF removida de `ibama_clean` sem substituto** — regressão, não a mesma pendência de v3. Ver §4.11, Fix 12.
- **Filtro IBAMA 3 casos (Fix 9), coluna de data (Fix 8), same-year join (Fix 7)**: sem alteração, reconfirmados no código atual.
- **`municipios_ref` e Barra do Bugres**: sem progresso desde v3 — continuam pendentes.

> v3 (2026-05-07): pipeline v3 completo (Fix 8 + Fix 9). Script R seção IBAMA concluída e locked. Pendências abertas na época: `municipios_ref`, `ipca_deflator`, revisão streak/priority_score, p75 hardcoded, Barra do Bugres. Ver changelogs v3, v3.1, v3.2, v3.3 no documento anterior para o histórico completo de PRODES loading e cobertura.

---

## 1. Project Overview

**Decision question:** Where should enforcement agencies or monitoring teams increase inspection effort because current enforcement intensity is low relative to environmental risk?

**Primary users:** Environmental enforcement teams (IBAMA/state), NGO monitoring units, policy/donor organizations tracking territorial response capacity.

**Unit of analysis:** Municipality × year panel (Amazônia Legal, 2008–2025).

**Output types:**
- Ranked list of municipalities with persistent enforcement gap
- KPI classification by gap type (completo / gap_absoluto / sem_pressao)
- Dashboard with temporal and geographic filters (Power BI — bloqueado por §4.11)

*(Sem alteração desde v3.)*

---

## 2. Infrastructure & Stack

| Layer | Tool |
|---|---|
| Storage / query engine | DuckDB (`project2.duckdb`) |
| Data exploration | R + tidyverse |
| Visualization | Power BI (pending connection; bloqueado por UF — §4.11) |
| Data files | `C:/Users/diogo/projects/project2/` |

**Schema structure:**
```
project2.staging   → raw ingestion tables
project2.marts     → cleaned, typed, filtered tables
project2.analytics → final metrics and outputs
```

*(Sem alteração desde v3.)*

---

## 3. Data Sources

### 3.1 PRODES (TerraBrasilis) e 3.2 IBAMA

Sem alteração de conteúdo desde v3 — ver documento anterior para detalhamento completo de colunas, filtros e estatísticas de cobertura. Números reconfirmados no script R v4 (`NROW_PRODES_RAW`, `NROW_IBAMA_RAW`, `NROW_IBAMA_FILTERED`, `TOTAL_IBAMA_MULTAS` — todos idênticos à v3).

### 3.3 IPCA/Sidra (NOVA nesta versão — implementada, não apenas planejada)

**Fonte:** IBGE/Sidra, tabela 1737, variável 2266 (número-índice, dez/1993=100), Brasil, jan/2008–dez/2025. Download 2026-07-10.
**Arquivo:** `data_ipca/sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv`
**Formato:** largo (mês×ano em colunas), com título e rodapé de notas — tratado via `UNPIVOT` + filtro regex.

**Decisão de base:** deflator base = 2025, calculado como a média dos índices mensais do ano-base (não dezembro isolado) — lavraturas de autos se distribuem ao longo do ano, com pico set-out (ver §3.4/Fix 7 do documento de fixes), então a média anual é a base mais representativa para deflacionar somas anuais de `val_multa`.

**Tratamento do rodapé Sidra:** o CSV tem quebra de linha dentro de aspas no rodapé de notas, o que quebra o scanner paralelo do DuckDB quando combinado com `null_padding = true` (DuckDB ≥ 1.5) — `parallel = false` necessário. Após o `UNPIVOT`, um filtro regex (`^\d+(,\d+)?$`) descarta strings do rodapé que vazam para colunas de mês via `null_padding`.

**Checkpoint (R, `exploring_script.R` v4):** `NROW_IPCA_RAW <- 216` (18 anos × 12 meses).
**Checkpoint (SQL, `01_staging.sql`):** 18 linhas na tabela anual; `deflator(2025) = 1.0`; `deflator(2008) ≈ 2.6`.

---

## 4. Methodological Decisions (Locked, salvo indicação em contrário)

### 4.1 Fonte PRODES, não DETER — sem alteração.
### 4.2 Escopo: Amazônia Legal — sem alteração.
### 4.3 Filtros IBAMA — sem alteração (Fix 9, 3 casos, 60.707 registros).

### 4.4 Threshold `area_km2 >= 1`
Limite de detecção do PRODES. **Atualização v4:** este limite agora é aplicado de forma consistente em toda a classificação `tipo_egs`, incluindo a fronteira gap_absoluto/sem_pressao (ver §4.7). Na v3 havia uma inconsistência entre esta seção (limite 1 km²) e a tabela de §4.7 (limite >0 km²) — resolvida nesta versão a favor do limite de materialidade. Ver Fix 11 em `p2_technical_fixes.txt`.

### 4.5 EGS — nome e lógica — sem alteração.

### 4.6 Fórmula EGS
```
EGS = LOG(1 + area_km2) / SQRT(LOG(1 + n_autos) * LOG(1 + val_multas))
```
Fórmula inalterada. **Mudança:** `val_multas` agora é o valor deflacionado (base 2025), não nominal — ver Fix 2. O numerador (`area_km2`) e o denominador (`n_autos`, `val_multas`) continuam os mesmos, mas a escala de `val_multas` mudou, o que altera os valores absolutos de EGS (embora a ordenação dentro do mesmo ano seja preservada — deflação é monotônica por ano).

### 4.7 Três tipos de EGS (ATUALIZADA — divergente da v3)

| tipo_egs | Condição (v4) | EGS calculado (v4) |
|---|---|---|
| `completo` | `area_km2 >= 1 AND val_multas >= 0.01` | `LOG(1+area_km2) / SQRT(LOG(1+n_autos) * LOG(1+val_multas))` |
| `gap_absoluto` | `area_km2 >= 1 AND val_multas < 0.01` | `LOG(1+area_km2)` |
| `sem_pressao` | `area_km2 < 1` | `NULL` |

**Duas mudanças em relação à v3:**
1. Limite gap_absoluto/sem_pressao passou de `area_km2 > 0` para `area_km2 >= 1` (materialidade — Fix 11).
2. `egs` de `sem_pressao` passou de `0` para `NULL` (Fix 13) — evita que `sem_pressao` contamine agregações (`AVG`, etc.) com um zero que não é comparável às outras duas categorias.

`n_autos > 0` está implícito em `completo`: `val_multas >= 0.01` exige ao menos um auto com valor de multa.

### 4.8 Persistência: ≥ 3 anos consecutivos — sem alteração (ciclo eleitoral brasileiro).

### 4.9 priority_score (ATUALIZADA)
```
priority_score = ROUND(LOG(max_streak) * LOG(1 + total_desmatado_km2), 3)
```
**v3** sinalizava como pendência: quando `max_streak = 1`, `LOG(1) = 0`, zerando o score. **v4: resolvido.** O filtro `WHERE streak_length >= 3` roda antes da agregação `MAX(streak_length)`, então streaks de 1-2 anos nunca chegam ao cálculo do score — são excluídos por regra de persistência, não zerados por artefato aritmético do `LOG`. Comentário no SQL documenta isso explicitamente como decisão de design. Ver Fix 10 para a discussão de trade-off (municípios com streak curto e área expressiva continuam fora do ranking, agora por exclusão deliberada).

### 4.10 Join temporal: mesmo ano ✅ LOCKED — sem alteração. Reconfirmado no R v4 com a base de 3 casos (60.707 registros, materialidade >=1): só_t=4.7% | só_t1=1.0% | ambos=59.2% | nenhum=35.1%.

### 4.11 UF / municipios_ref (NOVA — registra uma regressão)
A v3 tinha `UF AS uf` em `ibama_clean` como solução provisória, com plano documentado de substituição por `municipios_ref` assim que essa tabela existisse. No pipeline atual, `UF` foi removida de `ibama_clean` e `municipios_ref` **não** foi criada — nenhuma tabela de `marts` ou `analytics` carrega UF ou nome de município confiável (só `mun`, que tem 5 homônimos entre estados no PRODES). Isso não é a mesma pendência da v3: é uma regressão, porque o estado anterior (UF provisória e incompleta) cobria mais casos do que o estado atual (nenhuma UF). Bloqueia o Bloco 6 (Power BI / choropleth) do `p2_next_steps.md`. Ver Fix 12.

---

## 5. Pipeline SQL — versão atual (2026-07-10)

Substituindo a versão da v3 (que já estava desatualizada em relação ao filtro de 3 casos e não tinha deflator). Snippets abreviados — ver os arquivos `01-04_*.sql` para o texto completo e comentários.

### 5.1 Staging — destaques novos em relação à v3
```sql
-- ipca_deflator (NOVO)
CREATE OR REPLACE TABLE project2.staging.ipca_deflator AS
WITH wide AS (
    SELECT * FROM read_csv(
        'data_ipca/sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv',
        delim = ';', skip = 3, header = true,
        all_varchar = true, null_padding = true, ignore_errors = true,
        parallel = false)
),
long AS (UNPIVOT wide ON COLUMNS('\d{4}$') INTO NAME mes VALUE indice),
anual AS (
    SELECT CAST(regexp_extract(mes, '(\d{4})$', 1) AS INTEGER) AS ano,
           AVG(CAST(REPLACE(indice, ',', '.') AS DOUBLE))      AS indice_medio
    FROM long
    WHERE regexp_matches(indice, '^\d+(,\d+)?$')
    GROUP BY ano
)
SELECT ano, (SELECT indice_medio FROM anual WHERE ano = 2025) / indice_medio AS deflator
FROM anual ORDER BY ano;

-- municipios_ref: AINDA COMENTADO — requer data_ibge/dtb_municipios.csv
```

### 5.2 Marts — ibama_clean (filtro 3 casos, locked; SEM coluna UF)
```sql
CREATE OR REPLACE TABLE project2.marts.ibama_clean AS
SELECT
    COD_MUNICIPIO AS geocode_ibge,
    EXTRACT(YEAR FROM CAST(DAT_HORA_AUTO_INFRACAO AS DATE)) AS ano,
    CAST(REPLACE(VAL_AUTO_INFRACAO, ',', '.') AS DOUBLE)    AS val_multa
FROM project2.staging.ibama_raw
WHERE SIT_CANCELADO = 'N' AND DES_STATUS_FORMULARIO = 'Lavrado'
  AND (
    (TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA = 'Desmatamento')
    OR (TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA IS NULL
        AND COD_INFRACAO IN ('409907','409901','452001','430001','431003','468001'))
    OR (TIPO_INFRACAO IS NULL AND INFRACAO_AREA = 'Desmatamento')
  );
```

### 5.3 Analytics — egs_base com deflator
```sql
CREATE OR REPLACE TABLE project2.analytics.egs_base AS
SELECT
    p.geocode_ibge, p.mun, p.ano, p.area_km2,
    COUNT(i.geocode_ibge)                        AS n_autos,
    COALESCE(SUM(i.val_multa), 0)                AS val_multas_nominal,
    COALESCE(SUM(i.val_multa), 0) * d.deflator   AS val_multas
FROM project2.marts.prodes_clean p
LEFT JOIN project2.marts.ibama_clean i ON p.geocode_ibge = i.geocode_ibge AND p.ano = i.ano
LEFT JOIN project2.staging.ipca_deflator d ON p.ano = d.ano
GROUP BY p.geocode_ibge, p.mun, p.ano, p.area_km2, d.deflator;
```

### 5.4 Analytics — egs_final (classificação por materialidade, Fix 11)
```sql
CREATE OR REPLACE TABLE project2.analytics.egs_final AS
SELECT
    geocode_ibge, mun, ano, area_km2, n_autos, val_multas,
    CASE
        WHEN area_km2 >= 1 AND val_multas >= 0.01
            THEN LOG(1 + area_km2) / SQRT(LOG(1 + n_autos) * LOG(1 + val_multas))
        WHEN area_km2 >= 1 THEN LOG(1 + area_km2)
        ELSE NULL
    END AS egs,
    CASE
        WHEN area_km2 < 1      THEN 'sem_pressao'
        WHEN val_multas < 0.01 THEN 'gap_absoluto'
        ELSE                        'completo'
    END AS tipo_egs
FROM project2.analytics.egs_base;
```

### 5.5 Rankings — p75 dinâmico (Fix 3) e streak antes do score (Fix 10)
```sql
-- ranking_completo: p75 calculado em CTE, não hardcoded
WITH p75 AS (
    SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY egs) AS p75_egs
    FROM project2.analytics.egs_final WHERE tipo_egs = 'completo'
),
...
-- ranking_gap_absoluto e ranking_completo: WHERE streak_length >= 3
-- roda ANTES do MAX(streak_length) que alimenta priority_score
```

Ver `03_analytics.sql` e `04_export.sql` para o texto completo, incluindo `resumo_anual` e a materialização em parquet.

---

## 6. Query Results

**⚠ Os números desta seção na v3 (§6.1–6.4) refletem o pipeline v3 (sem deflator, classificação `area_km2 > 0`) e estão desatualizados.** Não usar em narrativas sem regenerar.

### 6.1 Único número confirmado sob o pipeline atual

| Métrica | v3 (2026-05-02) | v4 (2026-07-10) |
|---|---|---|
| gap_absoluto (n) | 3.784 (área > 0) | **3.063** (área >= 1, checkpoint cruzado R/SQL) |
| completo (n) | 7.893 | não confirmado nesta auditoria |
| sem_pressao (n) | 2.813 | não confirmado nesta auditoria |
| p75 EGS (completo) | 0.5891 (hardcoded) | não confirmado — agora dinâmico, requer execução |

**Ação necessária antes de qualquer narrativa ou apresentação:** rodar o bloco `== CHECKS analytics ==` de `03_analytics.sql` (distribuição por `tipo_egs` e p75 de referência) e registrar os valores aqui.

### 6.2–6.4 Rankings (top 20 gap_absoluto, top 43 completo)

As tabelas de ranking da v3 (Governador Luiz Rocha, Barra do Bugres, Itaituba, Apuí, etc.) foram geradas **antes** da deflação de `val_multas` e da mudança de threshold de materialidade em `gap_absoluto`. Ambas as mudanças alteram o EGS e, portanto, potencialmente a composição e ordem desses rankings. Não estão reproduzidas nesta versão para evitar que números desatualizados sejam tratados como atuais — consultar `project2_session_reference_v3.md` apenas como referência histórica, e regerar as tabelas a partir de `project2.analytics.ranking_gap_absoluto` / `ranking_completo` antes de reincorporar aqui.

---

## 7. Fixes — Status Final

> Numeração deste documento é independente da numeração em `p2_technical_fixes.txt`. Ver esse arquivo para o detalhamento completo problema/solução/código de cada fix, incluindo os novos Fix 10-13.

| Fix | Descrição | Status v3 | Status v4 |
|---|---|---|---|
| Fix 1 | Threshold val_multas: floating-point na classificação | ✅ Aplicado | ✅ Aplicado (inalterado) |
| Fix 2 | Date column: `DT_FATO_INFRACIONAL` → `DAT_HORA_AUTO_INFRACAO` | ✅ Aplicado | ✅ Aplicado (inalterado) |
| Fix 3 | Queimadas removidas do filtro INFRACAO_AREA | ✅ Aplicado | ✅ Aplicado (inalterado) |
| Fix 4 | Join temporal `p.ano = i.ano` | ✅ Locked | ✅ Locked (reconfirmado) |
| Fix 9 | Filtro IBAMA: 1 caso → 3 casos | ✅ Aplicado | ✅ Aplicado (inalterado) |
| — | `ipca_deflator` no staging | ⚠ Aberto | ✅ **Aplicado** |
| — | p75 hardcoded vs. dinâmico | ⚠ Aberto | ✅ **Resolvido** (dinâmico) |
| — | `priority_score`: `streak=1 → score=0` | ⚠ Aberto | ✅ **Resolvido** (via filtro de persistência) |
| — | `municipios_ref` no staging | ⚠ Aberto | ⚠ **Ainda aberto** |
| — | UF fix nas rankings | ⚠ Aberto | ❌ **Regrediu** — UF removida sem substituto |
| — | Barra do Bugres: legal vs. ilegal | ⚠ Aberto | ⚠ **Ainda aberto** |
| — | classificação `tipo_egs`: materialidade ambígua | *(não identificado em v3)* | ✅ **Resolvido** (novo, Fix 11) |
| — | `sem_pressao`: `egs` 0 → NULL | *(não identificado em v3)* | ✅ **Aplicado, documentado retroativamente** (Fix 13) |

---

## 8. Limitações Interpretativas

Sem alteração de conteúdo desde v3 (itens 1–7), com uma adição:

8. **UF/nome de município não confiável no pipeline atual.** Nenhuma tabela expõe UF; `mun` tem 5 homônimos entre estados no PRODES. Qualquer análise ou narrativa que precise de UF deve resolver manualmente até `municipios_ref` existir (§4.11).

---

## 9. MVP Vision — Próximos Passos Analíticos

Sem alteração de conteúdo desde v3 (expansão de biomas, extensões inferenciais). Ver `p2_technical_fixes.txt` Fix 6 para o detalhamento técnico do spatial join.

---

## 10. Portfolio Integration

**Posicionamento:** sem alteração — P2 é o único projeto monitoring-focused do portfolio.

**Documento de próximas etapas detalhado:** `p2_next_steps.md`, atualizado em 2026-07-10 com status por bloco.

**Próximas etapas em ordem (revisado):**
1. ~~Script R: seção IBAMA~~ ✅ CONCLUÍDO
2. ~~Script R: loading PRODES~~ ✅ CONCLUÍDO
3. ~~Staging: `ipca_deflator`~~ ✅ CONCLUÍDO (2026-07-10)
4. **Staging: `municipios_ref`** ⚠ — único item real ainda aberto no staging; desbloqueia UF em todo o resto do pipeline
5. ~~Analytics: streak + priority_score + p75~~ ✅ CONCLUÍDO (2026-07-10)
6. **Marts/Analytics: UF** ❌ — regrediu, precisa de `municipios_ref` (item 4) antes de poder ser refeito
7. **PRODES: quebras estruturais** ⚠ — único item aberto do Bloco 1 (script R)
8. **Barra do Bugres** ⚠ — pesquisa externa, independente do resto
9. Documentação: README, apêndice metodológico, narrativas finais — bloqueado por itens 4/6 (UF) e pelos números desatualizados sinalizados em §6
10. Power BI — bloqueado por item 6 (UF/choropleth)
11. Website + LinkedIn (após P1–P3 completos)

**Caminho crítico:** `municipios_ref` → UF em marts/analytics → choropleth Power BI. É o único item que bloqueia três etapas subsequentes.

**Documento de fixes técnicos:** `p2_technical_fixes.txt` v4 (2026-07-10) — 13 fixes (9 originais + 4 novos identificados por auditoria de código).
