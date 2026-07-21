# Patch de auditoria — EGMS, 2026-07-20

**Origem:** auditoria adversarial (sessão Claude, 2026-07-20) + verificação dos 6 itens da segunda auditoria.
**Verificação empírica desta sessão:** `ibama_clean` replicado do zero a partir dos CSVs brutos (60.707 linhas, R$26.814.492.927 exatos); deflator reconstruído do Sidra real (2008 = 2,5826; 12 meses × 18 anos); parquets de produção consultados diretamente. Todos os números-alvo abaixo foram verificados contra os dados, não estimados.

**Como usar:** blocos em ordem. O Bloco A (SQL) vem antes de qualquer edição de texto — os ranks citados nos documentos dependem do resultado do A1. Cada item tem: arquivo → localizar → substituir → motivo. Itens marcados **[DECISÃO]** precisam de escolha sua antes de aplicar.

> **STATUS (2026-07-20): PATCH COMPLETO — BLOCOS A–F APLICADOS.**
> Decisões tomadas: A4 = (a) `ORDER BY status DESC`; check do 62 = sim, fixado em **61** (confirmado em produção); C4 = R$115M deflacionado; E5 = claim rebaixada (Python não preservado; replicação da auditoria registrada em §5.2); F2 = README corrigido + copiado para a raiz; F3 = IPCA mantido versionado, `.gitignore` real corrigido.
> Bloco B executado e verificado: 51/51 checks OK; parquets re-exportados; ordem confirmada (Monte Alegre #3, Aveiro #4, GLR 54, Itaituba 129, Aripuanã 140, Apuí 141).
> Registro consolidado: Fix S18 em `sql_technical_fixes.md`. Pendências que sobram são as editoriais nomeadas em `final_reference.md` §11.4 (citações externas) e os opcionais do S15 (checksums, fixture da lista MMA).

**Resultado pré-verificado do A1** (calculei a ordenação não-arredondada contra `pbi_egs_final.parquet`): top 5 = Cachoeira do Piriá, Porto de Moz, **Monte Alegre (#3), Aveiro (#4)**, Alenquer; Governador Luiz Rocha **#54**; Itaituba #129; Aripuanã #140; Apuí **#141**. Ou seja: com o A1 aplicado, os ranks já citados nos documentos (54, 129, 141, Monte Alegre em 3º) ficam corretos — sem o A1, a próxima execução do pipeline os quebra.

---

## BLOCO A — SQL (aplicar primeiro)

### A1 — Tiebreak pela média não-arredondada (crítico)
**Arquivo:** `sql/03_analytics.sql`, final de `egs_ranking`.
O `ORDER BY avg_egs_18y DESC` ordena pelo valor arredondado a 3 casas, criando empates artificiais que o geocode resolve *contra* a ordem verdadeira: Monte Alegre (1,10893) > Aveiro (1,10870), ambos "1.109", e o geocode de Aveiro (1501006) é menor — a próxima execução inverteria o top 3/4 publicado.

Localizar:
```sql
-- Fix S16.1 (2026-07-20): deterministic tiebreak. Without it, municipalities
-- tied on avg_egs_18y (rounded to 3 decimals) have no guaranteed order
-- between re-executions — a problem for any document that names a "top N"
-- as if positions were stable.
ORDER BY avg_egs_18y DESC, e.geocode_ibge;
```
Substituir por:
```sql
-- Fix S16.1 (2026-07-20; revisado na auditoria de 2026-07-20): tiebreak
-- determinístico pela média NÃO-arredondada, depois geocode. Ordenar pela
-- coluna arredondada criava empates artificiais (Monte Alegre 1,10893 vs
-- Aveiro 1,10870, ambos "1.109") que o geocode resolvia contra a ordem
-- verdadeira. AVG(e.egs) preserva a ordem real; o geocode só desempata
-- empates exatos (ex.: municípios com egs todo zero).
ORDER BY AVG(e.egs) DESC, e.geocode_ibge;
```

### A2 — Persistir `fine_values_nominal` em `egs_final` (2ª auditoria, item 1)
**Arquivo:** `sql/03_analytics.sql`, SELECT de `egs_final`.
A coluna existe em `egs_base` e some em `egs_final` — a cifra "62 casos com piso ativo (nominal)" citada nos docs é irreprodutível a partir das tabelas persistidas.

Localizar (no SELECT de `egs_final`):
```sql
    n_infractions,
    fine_values,
    CASE
```
Substituir por:
```sql
    n_infractions,
    fine_values_nominal,
    fine_values,
    CASE
```
Nota: `pbi_egs_final.parquet` ganha uma coluna — anotar no dicionário de dados do Power BI. Opcional: adicionar check `n_floor_active_nominal = 62` no bloco de analytics para fixar a cifra.

### A3 — Checks de `prodes_clean` simétricos aos de `ibama_clean` (2ª auditoria, item 2)
**Arquivo:** `sql/02_marts.sql`, bloco de checks, logo após a linha `na_area_prodes_clean`.
Inserir:
```sql
    UNION ALL SELECT 'negative_area_prodes_clean', CAST(COUNT(*) AS VARCHAR), '0' FROM project2.marts.prodes_clean WHERE area_km2 < 0
    UNION ALL SELECT 'min_year_prodes_clean', CAST(MIN(year) AS VARCHAR), '2008' FROM project2.marts.prodes_clean
    UNION ALL SELECT 'max_year_prodes_clean', CAST(MAX(year) AS VARCHAR), '2025' FROM project2.marts.prodes_clean
```
Esperados verificados nesta sessão (min área = 0, anos 2008–2025). Com o check nominal do A2, o total passa a **7 + 25 + 19 = 51 checks** → dispara o Bloco F4 (atualizar contagens em prosa).

### A4 — **[DECISÃO]** "Falhas primeiro" nos grids de check
O título do `sql_explained.md` §0 diz "falhas primeiro", mas `ORDER BY status ASC` põe os `OK` primeiro ('O'=79 < 'f'=102). Escolher:
- **(a) recomendado:** trocar para `ORDER BY status DESC, check_name` nos três arquivos SQL (falhas de fato primeiro) e ajustar a explicação do §0 do `sql_explained.md`;
- **(b) mínimo:** manter o SQL e corrigir o título/explicação do `sql_explained.md` para "OKs primeiro, falhas agrupadas no fim".

### A5 — Header de `01_staging.sql`: exceção do JSON
A claim "everything VARCHAR" é falsa para `municipality_ref_raw` (`read_json_auto` guarda `id` como inteiro e STRUCTs tipados — é por isso que o marts faz `CAST(id AS VARCHAR)`).
Localizar: `everything VARCHAR; typing happens`
Substituir o trecho do propósito por: `everything VARCHAR for the CSV sources; the JSON source keeps read_json_auto's inferred types, untouched — typing/standardization happens in marts`

### A6 — Fix S17: código e mecanismo errados (também em C7/D1)
**Arquivo:** `sql/01_staging.sql`, comentário do check `invalid_geocode_ibama`.
O código IBGE real de Manoel Viana/RS é **4311759** (verificado no `municipios.json` do próprio projeto), não 4311773; e "missing its leading zero" é impossível (nenhum código IBGE começa com 0 — UFs 11–53).
Localizar: `code missing its leading zero; correct IBGE code is 4311773`
Substituir por: `malformed 6-digit code; the correct IBGE code is 4311759 — mechanism unknown, NOT a leading-zero drop (no IBGE code starts with 0)`

### A7 — Comentários numéricos em `02_marts.sql` / `03_analytics.sql`
1. `02_marts.sql`, comentário de `ibama_clean` — a unidade do lag é o **auto**, não o município-ano.
   Localizar: `59.2% of muni-years match same-year` → `59.2% of infraction records (n = 60,707) match same-year`
2. `03_analytics.sql`, decisão (i) — mesmo ajuste: após `(59.2% same-year / 4.7% only_t / 1.0% only_t1 / 35.1% never)` acrescentar ` — shares of the 60,707 infraction records, not of municipality-years —`
3. `03_analytics.sql`, decisão (d) — Localizar `(0.723 vs 0.583 mean, deflated)` → `(0.723 vs 0.582 mean, deflated)` (produção: 0,5818).
4. `03_analytics.sql`, decisão (a) — Localizar `(Spearman 0.985 across all 805 municipalities)` → `(Spearman 0.985, 1 km² vs 6.25 ha rankings, across all 805 municipalities — the pair actually computed in R; the no-threshold comparison was top-N overlap only)`

---

## BLOCO B — Re-execução (depois do A, antes do C)

1. Rodar `02_marts.sql` → `03_analytics.sql` → `04_export.sql` no DBeaver (o `04` **não foi re-rodado** após o S16.1 — a ordem física do parquet atual prova isso).
2. Conferir os 51 checks — atenção ao `n_floor_active_nominal`: esperado 61 (réplica da auditoria); se vier 62, investigar antes de mudar (ver C7).
3. Conferir no parquet novo: linha 3 = Monte Alegre; GLR na posição 54; Aripuanã 140; Apuí 141. (Valores pré-verificados nesta sessão por fora do pipeline.)

---

## BLOCO C — Números que a produção desmente

### C1 — Apuí: "pico histórico" e números do protótipo nominal (4 arquivos)
Produção: pior ano da série = **2009 (1,459**, ano de auto único, caso quase-fronteira tipo S10); 2021 = **0,770**; média 2020–22 = **0,743**. Os 0,748/0,775 vieram do protótipo.

a) `references/v6/p2_results_narrative_draft.md`:
Localizar: `the annual EGS rose to its historical maximum, averaging 0.748 — with 2021 (0.775) the worst year in the municipality's series`
Substituir: `the annual EGS rose to its worst sustained stretch, averaging 0.743 over the three years (2021: 0.770). The single-year series maximum is actually 2009 (1.459) — an isolated one-notice year of exactly the near-floor type Fix S10 targets — which is why the sustained 2020–22 plateau, not the 2009 spike, is the meaningful peak`

b) `references/v6/final_reference.md` §10:
Localizar: `annual EGS peaked in 2020–22 (mean 0.748; deforestation 440 km²/yr against a flat response)`
Substituir: `annual EGS reached its worst sustained stretch in 2020–22 (mean 0.743; deforestation 440 km²/yr against a flat response — the single-year series max, 1.459 in 2009, is an isolated one-notice year)`

c) `references/v6/sql_technical_fixes.md`, registro empírico, item (d):
Localizar: `EGS médio 0,748 em 2020–22 (pico; área 440 km²/ano)`
Substituir: `EGS médio 0,743 em 2020–22 (pior trecho sustentado; o máximo pontual da série é 2009, 1,459, ano de auto único — corrigido 2026-07-20, número anterior era do protótipo nominal; área 440 km²/ano)`

d) `references/v6/p2_writing_sample.md`:
Localizar: `teve seu pico histórico de EGS em 2020–2022`
Substituir: `teve em 2020–2022 seu pior trecho sustentado de EGS (o máximo pontual da série, 2009, é um ano isolado de auto único)`

### C2 — "the two largest federal responses in the dataset" é falso
Produção: Altamira R$3,75 bi/1.454 autos; São Félix do Xingu R$2,35 bi; Lábrea R$2,28 bi/1.576; Porto Velho 2.938 autos. Apuí é ≤4º em valor; Itaituba nem isso.

a) `references/v6/p2_results_narrative_draft.md`:
Localizar: `but also the largest federal responses in the dataset (561 and 845 notices; R$842M and R$1,027M deflated)`
Substituir: `but also two of the larger federal responses in the dataset (561 and 845 notices; R$842M and R$1,027M deflated — for scale, the dataset maximum is Altamira: 1,454 notices, R$3.75bn)`

b) `references/v6/final_reference.md` §8:
Localizar: `(old measured leaders, the two largest federal responses in the dataset)`
Substituir: `(old measured leaders, with two of the dataset's larger federal responses)`

### C3 — Monte Alegre 1.110 → 1.109
`references/v6/final_reference.md` §8. Produção e recálculo: ROUND(1,108925, 3) = 1,109.
Localizar: `Monte Alegre (PA) 1.110` → `Monte Alegre (PA) 1.109`
(A ordem Monte Alegre #3 / Aveiro #4 fica correta com o A1 — não mexer.)

### C4 — **[DECISÃO]** Apuí 2023–25: R$112M é a média nominal
Deflacionada = **R$115M/ano** (84,7 + 72,5 + 188,2 / 3); nominal = 111,5 ≈ 112. Recomendo padronizar no deflacionado (todas as outras cifras do projeto são deflacionadas):
a) `references/v6/p2_results_narrative_draft.md`: `95 notices/year, R$112M/year in deflated fines` → `95 notices/year, R$115M/year in deflated fines`
b) `references/v6/final_reference.md` §10: `(95 notices/yr, R$112M/yr; 118 notices and R$188M in 2025 alone)` → `(95 notices/yr, R$115M/yr deflated; 118 notices and R$188M in 2025 alone)`
Alternativa: manter 112 e rotular "nominal" — mas quebra o padrão do projeto.

### C5 — 0,583 → 0,582
a) `references/v6/final_reference.md` §4: `(0.723 vs 0.583)` → `(0.723 vs 0.582)`
b) `sql/sql_explained.md` §3.4: `(médias 0,723 vs. 0,583, deflacionado)` → `(médias 0,723 vs. 0,582, deflacionado)`
(O `03_analytics.sql` já foi no A7.3.)

### C7 — "62 com valores nominais" → 61 (condicionado à confirmação do Bloco B)
A réplica independente da auditoria dá **61** casos de piso ativo com multas nominais (em duas operacionalizações), não 62. A cifra 62 aparece só em comentários, nunca foi assertada — drift de protótipo. Após o check `n_floor_active_nominal` passar com 61 em produção:
a) `exploration/exploring_script.R`: `# (deflated fines; would be 62 with nominal)` → `# (deflated fines; 61 with nominal — corrected 2026-07-20, prototype comment said 62)`; e em Decision 1: `With nominal fines it would bind 62 times` → `With nominal fines it binds 61 times (corrected 2026-07-20)`
b) `references/v6/sql_technical_fixes.md`: `(0,9%; seriam 62 com valores nominais — a deflação engorda o denominador e tira casos da zona instável)` → `(0,9%; seriam 61 com valores nominais — corrigido 2026-07-20, o registro anterior dizia 62 — a deflação engorda o denominador e tira casos da zona instável)`; e no Fix S10: `(62 se calculado com valores nominais)` → `(61 se calculado com valores nominais; corrigido 2026-07-20)`

### C6 — Identidade algébrica: 1e-16 é do R, o check garante 0,01
`references/v6/final_reference.md` §4:
Localizar: `*Algebraic identity, verified to ~1e-16 and enforced by check:*`
Substituir: `*Algebraic identity, verified in R to ~1e-16; the SQL check (identity_mismatches) enforces it to 0.01, the tolerance imposed by the rounded column:*`

---

## BLOCO D — Correções factuais em prosa

### D1 — S17 nos documentos (código 4311759 + mecanismo)
a) `references/v6/sql_technical_fixes.md`, Fix S17 (2 ocorrências: achado e por-que-importa):
Localizar: `com um código de 6 dígitos faltando o zero à esquerda (o código IBGE correto é `4311773`)`
Substituir: `com um código de 6 dígitos malformado (o código IBGE correto é 4311759 — verificado no municipios.json; mecanismo da corrupção desconhecido — NÃO é zero à esquerda perdido: nenhum código IBGE começa com 0)`
b) `sql/sql_explained.md` §1.5:
Localizar: `código de 6 dígitos com zero à esquerda perdido (correto: 4311773)`
Substituir: `código de 6 dígitos malformado (correto: 4311759; não é zero à esquerda — nenhum código IBGE começa com 0)`

### D2 — Unidade do lag nos documentos
a) `references/v6/final_reference.md` §4:
Localizar: `59.2% of municipality-years match same-year` → `59.2% of infraction records (n = 60,707; the unit of the lag validation is the notice, not the municipality-year) match same-year`
b) `sql/sql_explained.md` §3.3: na frase `A validação de lag do exploring_script.R (59,2% mesmo ano...)`, acrescentar após o parêntese: ` — proporções sobre os 60.707 autos, não sobre município-anos —`

### D3 — "805 municípios da Amazônia Legal" (a delimitação oficial tem 772)
LC 124/2007 / SUDAM / IBGE: 772 municípios. 805 é o painel municipal do PRODES (inclui municípios parcialmente contidos — confirmar formulação exata na documentação do INPE).
a) `references/v6/p2_writing_sample.md`: `para os 805 municípios da Amazônia Legal ao mesmo tempo` → `para os 805 municípios do painel municipal do PRODES para a Amazônia Legal ao mesmo tempo`
b) `references/v6/p2_results_narrative_draft.md`: `Across 805 municipalities in the Brazilian Legal Amazon` → `Across the 805 municipalities of PRODES's municipal panel for the Legal Amazon (the official delimitation counts 772; PRODES includes partially contained municipalities)`
c) `references/v6/final_reference.md` §1: `for all municipalities of the Brazilian Legal Amazon` → `for all municipalities in PRODES's Legal Amazon panel`

### D4 — "47 checks automatizados" (writing sample)
Localizar: `47 checks automatizados` → `51 checks com valores esperados versionados no próprio pipeline` ("automatizados" contradiz o próprio sql_explained: nada aborta, é leitura visual).

### D5 — Spearman: precisão do que foi computado
a) `references/v6/final_reference.md` §4: `and no threshold; Spearman 0.985 across all 805 municipalities` → `and no threshold; Spearman 0.985 (1 km² vs 6.25 ha rankings) across all 805 municipalities — the no-threshold comparison was verified by top-10/20/50 overlap only`
b) `references/v6/p2_results_narrative_draft.md`: `the top 50 of the ranking is identical under all three, Spearman 0.985 across all 805 municipalities` → `the top 50 of the ranking is identical under all three; Spearman 0.985 (1 km² vs 6.25 ha) across all 805 municipalities`

---

## BLOCO E — Narrativa e citações externas

### E1 — Cachoeira do Piriá: nomear a tensão (2ª auditoria, item 5 — procede)
`references/v6/p2_results_narrative_draft.md`, fim do parágrafo do caso #1. Acrescentar:
`One tension worth naming: its 3-year mean (1.228) sits above its 18-year mean, while its slope is mildly negative (−0.010) — the recent situation is worse than the historical average, and the negative slope reflects early-series highs, not current improvement. By the recent-mean criterion applied to Aveiro below, the #1 case is also deteriorating relative to its own history.`

### E2 — Porto de Moz: claim sem fonte
`references/v6/p2_results_narrative_draft.md`:
Localizar: `consistent with its inclusion in Pará's integrated state enforcement operations in 2024–25`
Substituir: `a pattern consistent with intensified state enforcement in Pará in 2024–25 — though no source specific to Porto de Moz was found in this round of verification`

### E3 — Barra do Bugres estendido ao top 20 (2ª auditoria, item 4 — parcial)
Não é erro (ressalva genérica legítima), mas explicitar o não-feito. `p2_results_narrative_draft.md`, seção "What this system does not resolve":
Localizar: `applies with full force to the current top 20, and no case should be published without that caveat attached`
Substituir: `applies with full force to the current top 20 — no AUTEX/DOF authorization check was performed for any of the 20 current cases — and no case should be published without that caveat attached`

### E4 — Checklist da revisão editorial de citações (§11.4, agora com itens nomeados)
Acrescentar ao `final_reference.md` §11, item 4, a lista do que falta verificar:
1. SEMAS-PA / Operação Curupira: o link citado (nota de 10/10/2024 sobre "redução de 37% nos alertas") **não corresponde no título** aos números citados (196 autos, R$87,9M, 30.592 ha) — confirmar se a página os contém ou achar a fonte primária (página é JS; fetch automatizado retorna vazio).
2. Números de orçamento do IBAMA (corte ~43%, execução 41%, ~500 fiscais) — sem link desde a v2.
3. IBAMA 2025 em Apuí (R$173M, ~27.000 ha embargados) — herdado da v2, sem link.
4. Prisão do ex-vice-prefeito de Apuí (mar/2025) — sem link.
5. Portarias GM/MMA 1.716/1.717 (2026) — já sinalizado como não obtido; repetir a tentativa antes de publicar.

### E5 — `egms_tabela_final_prototipo.csv` não existe no repo
Citado em `final_reference.md` §8 e `sql_technical_fixes.md` (registro empírico) como artefato de conferência — o arquivo não está no repositório. **[DECISÃO]**: (a) commitar o CSV em `references/` como fixture, ou (b) remover a referência de §8 (`/ egms_tabela_final_prototipo.csv (cross-check artifact)`) e anotar no registro empírico que o artefato não foi preservado. O mesmo vale para o script Python da tripla validação (nunca preservado): a rodada desta auditoria (2026-07-20, replicação independente de `ibama_clean`, deflator e classificação a partir dos brutos) pode ser citada como reprodução externa — mas só se os comandos forem preservados; caso contrário, rebaixar "triple cross-validation" para "twice reproduced (R + DuckDB), plus a third-party session replication not preserved in the repo".

### E6 — Lista MMA como fixture
A Portaria 1.202/2024 (81 municípios) sustenta o overlap 8/20 e não está no repo — o overlap não é verificável offline. Sugestão: salvar a lista dos 81 (CSV simples, fonte + data) em `references/` e citar o arquivo.

---

## BLOCO F — Housekeeping

### F1 — S13 item 6 nunca aterrissou no repo
`references/v5/p2_municipal_research.md` (linha ~38): `ver ressalva already registrada` → `ver ressalva já registrada`; e adicionar no topo do arquivo a nota prometida: `**Documento histórico** — pesquisa feita sobre os rankings v2/v3, superados; ver final_reference.md §10 para a verificação vigente.` Atualizar o status do S13 item 6 no `sql_technical_fixes.md` (a correção anterior ficou numa cópia de outputs que não voltou).

### F2 — **[DECISÃO]** README: estrutura não bate com o repo
`references/v6/README.md` mostra os SQLs na raiz (estão em `sql/`), `exploring_script.R` na raiz (está em `exploration/`), cita `exploring_script_explained.md` (o arquivo é `.txt`), e o próprio README não existe na raiz. Escolher: (a) mover os arquivos para bater com o README, ou (b) **recomendado**: corrigir a árvore do README para a estrutura real (`sql/`, `exploration/`, `references/`) e copiar o README para a raiz do repo.

### F3 — **[DECISÃO]** .gitignore real ≠ recomendado
No `.gitignore` real: falta `output/`, falta `data_ibge/`, typo `.duckdb.exe` (o binário é `duckdb.exe`, sem ponto — hoje não é ignorado). E `data_ipca/` não está no gitignore **e o CSV do IPCA está trackeado** — enquanto o README o declara "não versionado". Recomendo: manter o CSV do IPCA versionado (pequeno, snapshot estável — ajuda reprodução) e atualizar README + gitignore para refletir isso; adicionar `output/`, `data_ibge/`, `duckdb.exe`. Decidir também se `references/` entra no versionamento (hoje nenhum doc está no git).

### F4 — Contagem de checks 47 → 51 (A3 + check nominal aplicados)
Atualizar apenas as menções de **estado atual** (as históricas — "46→47", S14 — ficam):
- `final_reference.md`: §2 (`7 + 22 + 18 = **47 checks`→`7 + 25 + 19 = **51 checks`), §5 item 3 (`all 47 consolidated checks`), §7.8 (`bringing the total to 47` → acrescentar nota `; 51 as of the 2026-07-20 audit patch`).
- `p2_results_narrative_draft.md`: header (`all 47 pipeline checks passing`) e nota final (`all 47 checks passing`).
- `p2_writing_sample.md`: coberto no D4 (usar `51 checks`).
- `README.md`: passo 4 (`7 checks em staging, 22 em marts, 18 em analytics — 47 no total` → `7 / 25 / 19 — 51 no total`; e a nota sobre o 22º check ganha: `; a auditoria de 2026-07-20 adicionou 3 checks de prodes_clean e o n_floor_active_nominal`).
- `sql/sql_explained.md`: header (`7 + 22 + 18 = 47`), §0 (`47 no total`), §2.6 (`22 checks consolidados` → `25`), §3.7 (`18 checks` → `19`), pendências (`47 no total` → `51 no total`).

### F5 — 5.571 vs 5.573: uma linha de reconciliação
As duas fontes IBGE divergem em 2 municípios sem nota em lugar nenhum. Acrescentar ao comentário de `municipality_area` em `02_marts.sql` (ou ao §3 do final_reference): `Nota: a API de localidades retorna 5.571 municípios; o arquivo de áreas 2025, 5.573 — divergência de 2 registros entre fontes IBGE, não investigada; irrelevante para os 805 do PRODES (cobertura 100% verificada em ambas).`

### F6 — Varredura de fechamento: S17 não foi "pela redesign"
`sql_technical_fixes.md`, varredura de fechamento: mover S17 da lista `(7 pela redesign: S1, S2, S3, S7, S10, S12, S17)` para os resolvidos da passada (foi correção de check independente da redesign). Cosmético.

### F7 — (Opcional) Entrada S18 registrando esta auditoria
Manter o padrão do documento vivo: uma entrada S18 resumindo os achados desta auditoria (tiebreak arredondado, números do protótipo em prosa, S17 com etiologia errada, unidade do lag, parquets stale) com status e data — para que o log continue sendo a fonte da verdade do processo.

---

## Verificação pós-patch (rodar depois do Bloco B)

```sql
-- 1. Ordem do topo (esperado: Cachoeira, Porto de Moz, Monte Alegre, Aveiro, Alenquer)
SELECT mun, avg_egs_18y FROM 'output/pbi_egs_ranking.parquet' LIMIT 5;

-- 2. Ranks citados (esperado: GLR 54, Itaituba 129, Aripuanã 140, Apuí 141)
WITH r AS (SELECT row_number() OVER () rk, mun FROM 'output/pbi_egs_ranking.parquet')
SELECT rk, mun FROM r WHERE mun IN ('Governador Luiz Rocha','Itaituba','Aripuanã','Apuí');

-- 3. Nominal persistido (esperado: 61 — ver C7; o "62" dos comentários era drift de protótipo)
SELECT COUNT(*) FROM 'output/pbi_egs_final.parquet'
WHERE gap_type='measured_gap' AND SQRT(LOG(1+n_infractions)*LOG(1+fine_values_nominal)) < 1;

-- 4. Apuí (esperado: 0.743 / 0.770 / max 1.459 em 2009 / 115.1)
SELECT AVG(egs) FILTER (WHERE year BETWEEN 2020 AND 2022),
       MAX(egs) FILTER (WHERE year=2021),
       MAX(egs), ARG_MAX(year, egs)
FROM 'output/pbi_egs_final.parquet' WHERE mun='Apuí';
```
