# Enforcement Gap Monitoring System (EGMS)

Pipeline DuckDB + SQL + R que cruza desmatamento (PRODES/INPE) com fiscalização ambiental federal (IBAMA) na Amazônia Legal, produzindo o **Enforcement Gap Score (EGS)** — um índice de município-ano que mede o desequilíbrio entre pressão de desmatamento e resposta institucional federal — e um ranking municipal consolidado (`egs_ranking`).

Autor: Diogo Grieco.

---

## Stack

- **DuckDB** — motor de consulta / armazenamento (`project2.duckdb`)
- **SQL** — pipeline em 4 arquivos (`01_staging.sql` → `04_export.sql`), v5 (2026-07-20)
- **R (tidyverse)** — exploração e validação dos dados brutos (`exploring_script.R`)
- **Power BI** — dashboard (consome os parquets gerados por `04_export.sql`)

O pipeline roda igualmente via DBeaver, DuckDB CLI, ou o pacote `duckdb`/`DBI` em R — nenhuma etapa depende do diretório de trabalho do cliente (ver "Configuração" abaixo).

---

## Estrutura de pastas esperada

```
project2/
├── README.md                  (cópia deste arquivo na raiz do repo)
├── sql/
│   ├── 01_staging.sql
│   ├── 02_marts.sql
│   ├── 03_analytics.sql
│   ├── 04_export.sql
│   └── sql_explained.md
├── exploration/
│   ├── exploring_script.R
│   └── exploring_script_explained.txt
├── references/                (documentação por versão; v6 = atual)
├── project2.duckdb            (gerado ao rodar o pipeline)
├── data_prodes/               (dados brutos — não versionado)
│   └── terrabrasilis_legal_amazon_*.csv
├── data_ibama/                (dados brutos — não versionado)
│   └── auto_infracao_ano_*.csv
├── data_ibge/                 (dados brutos — não versionado)
│   ├── municipios.json
│   └── municipality_area_2025.csv
├── data_ipca/                 (versionado — snapshot de reprodutibilidade)
│   └── sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv
└── output/                    (gerado por 04_export.sql — não versionado)
    ├── pbi_egs_final.parquet
    ├── pbi_egs_ranking.parquet
    └── pbi_annual_summary.parquet
```

As pastas `data_*/` e `output/` **não são versionadas** (ver `.gitignore` abaixo) — são grandes, de download manual, e regeneráveis a partir das fontes primárias. Exceção deliberada: o CSV do IPCA (`data_ipca/`) é pequeno e estável e **está versionado**, como parte do snapshot de reprodutibilidade (decisão da auditoria de 2026-07-20).

---

## Fontes de dados e instruções de download

| Pasta | Fonte | Onde baixar |
|---|---|---|
| `data_prodes/` | PRODES/INPE, desmatamento anual por município na Amazônia Legal | [TerraBrasilis](https://terrabrasilis.dpi.inpe.br/) — exportar CSV agregado por município-ano |
| `data_ibama/` | IBAMA, autos de infração ambiental (um CSV por ano) | [dadosabertos.ibama.gov.br](https://dadosabertos.ibama.gov.br/) — dataset "Fiscalização - auto de infração" |
| `data_ibge/` (referência) | IBGE, referência de município/UF | API de localidades: `https://servicodados.ibge.gov.br/api/v1/localidades/municipios` — baixar o JSON via navegador e salvar como `municipios.json` |
| `data_ibge/` (áreas) | IBGE, Malha Municipal Digital — Áreas Territoriais 2025 | [ibge.gov.br → áreas dos municípios](https://www.ibge.gov.br/geociencias/organizacao-do-territorio/estrutura-territorial/15761-areas-dos-municipios.html), arquivo `AR_BR_RG_UF_RGINT_RGI_MUN_2025.xls`. **Converter uma vez para CSV** (`municipality_area_2025.csv`); o `01_staging.sql` espera `delim = ','` — se converter com Excel/LibreOffice (que tende a usar `;`), ajustar o delim no `read_csv` correspondente |
| `data_ipca/` | IBGE/Sidra, índice IPCA mensal (deflator) | [Sidra, tabela 1737, variável 2266](https://sidra.ibge.gov.br/tabela/1737) — série Brasil, formato CSV largo (mês × ano) |

Os nomes de arquivo esperados por `01_staging.sql` usam wildcard (`*`) para PRODES e IBAMA — múltiplos CSVs na mesma pasta são concatenados automaticamente. IPCA, JSON do IBGE e CSV de áreas têm nome exato esperado (ver caminho completo no próprio `01_staging.sql`).

---

## Configuração — ponto único (`data_root`)

O topo de `01_staging.sql` define uma variável de sessão do DuckDB que é a **única linha que precisa ser editada** para rodar o pipeline em qualquer máquina:

```sql
SET VARIABLE data_root = 'C:/Users/diogo/projects/project2';  -- editar aqui
```

Todos os `read_csv`/`read_json_auto` do pipeline usam `getvariable('data_root') || '/...'`. Exceção deliberada: os paths de `COPY ... TO` em `04_export.sql` são literais absolutos (editar lá também) — ver nota no próprio arquivo.

---

## Como rodar

1. Baixe os 5 conjuntos de dados brutos (ver tabela acima) para as pastas `data_*/` correspondentes.
2. Edite `data_root` no topo de `01_staging.sql` para o caminho local do seu clone.
3. Rode os arquivos SQL em ordem, validando o bloco de checks ao final de cada um antes de seguir:
   ```
   01_staging.sql    → ingestão bruta apenas (5 tabelas *_raw, tudo VARCHAR, sem filtro)
   02_marts.sql      → limpeza, tipagem e padronização (ibama_clean, prodes_clean,
                        municipality_ref, municipality_area, ipca_annual)
   03_analytics.sql  → índices derivados: deflator IPCA, EGS unificado (fórmula única
                        com piso no denominador), egs_ranking (média 0-fill 18 anos,
                        média 3 anos, slope, pct_desmatado), annual_summary
   04_export.sql     → materializa 3 parquets em output/ para o Power BI
   ```
   No DBeaver: abrir o script, associar à conexão do `project2.duckdb`, `Execute SQL Script` (Alt+X) roda o arquivo inteiro, incluindo o bloco `== CHECKS ==` ao final.
4. Confira os checks: cada arquivo termina em **uma única query consolidada** que retorna `check_name | actual | expected | status` (7 checks em staging, 26 em marts, 20 em analytics, 1 em export — 54 no total; o check `ipca_months_not_12` entrou em 2026-07-20, Fix S14; a auditoria de 2026-07-20 adicionou 3 checks de `prodes_clean` e o `n_floor_active_nominal`; a terceira auditoria de 2026-07-20 adicionou `total_area_prodes_clean`, `deflator_2008` e o check pós-export de parquet stale. Falhas aparecem no topo do grid). Qualquer linha com `status = failed` deve ser investigada antes de prosseguir — ver a nota de reprodutibilidade acima antes de assumir que é um bug. A pasta `output/` precisa existir antes de rodar o `04` (o `COPY` não cria diretórios).
5. (Opcional) Abra `exploring_script.R` no RStudio para reproduzir a validação exploratória dos dados brutos — `stopifnot()` em cada etapa crítica. As validações empíricas da redesign de 2026-07-20 já estão incorporadas ao próprio `exploring_script.R` (v4.4-2026-07-20).
6. Aponte o Power BI para os 3 arquivos parquet em `output/`.

---

## Datas de download e reprodutibilidade (Fix S15)

Os valores esperados nos blocos de check (`n_ibama = 60707`, `total_fines = 26814492927`, `n_absolute_gap = 3063`, etc.) são uma fotografia dos dados na data em que foram baixados — **não são invariantes da fonte**. IBAMA revisa retroativamente seus CSVs de autos de infração (cancelamentos, correções, novos registros); PRODES publica estimativa preliminar e consolida o ano mais recente meses depois. Quem baixar os dados de novo, hoje ou no futuro, pode ver checks `failed` sem que haja bug algum no pipeline — só dado mais recente que o snapshot documentado aqui.

| Fonte | Data do snapshot usado | Observação |
|---|---|---|
| PRODES (`data_prodes/`) | 25/04/2026 (no próprio nome do arquivo) | 2025 é o ano mais recente do painel e pode não estar consolidado — ver nota "último ano sujeito a revisão" |
| IBAMA (`data_ibama/`) | **não registrada** | O nome dos arquivos (`auto_infracao_ano_*.csv`) não carrega data de download; anote a data manualmente ao baixar de novo |
| IBGE — referência (`municipios.json`) | 12/07/2026 | Download manual via navegador (API não respondeu de forma confiável neste projeto) |
| IBGE — áreas territoriais (`municipality_area_2025.csv`) | 20/07/2026 | Convertido de `.xls` para CSV — ver nota de delimitador em `01_staging.sql` |
| IBGE/Sidra — IPCA | 10/07/2026 (no próprio nome do arquivo) | — |

Antes de comparar um check `failed` com o pipeline, confirme se algum dos 5 arquivos foi rebaixado depois dessas datas. Se sim, o esperado do check é o que precisa ser atualizado, não o SQL.

---

## `.gitignore` recomendado

```
# RStudio
.Rproj.user
.Rhistory
.RData
.Ruserdata

# dados brutos — grandes, download manual, regeneráveis
# (data_ipca/ NÃO entra: o CSV do IPCA é versionado como snapshot)
data_prodes/
data_ibama/
data_ibge/

# saída do pipeline — regenerável a partir do banco
output/

# banco DuckDB local e binário
project2.duckdb
duckdb.exe
*.wal
```

---

## Documentação do projeto

- `final_reference.md` — apêndice técnico consolidado: metodologia (com base empírica de cada decisão), validações, limitações, histórico de desenvolvimento, resultados confirmados em produção.
- `sql_technical_fixes.md` — histórico vivo de achados e correções técnicas do pipeline SQL, incluindo o registro empírico completo da redesign dos rankings (2026-07-20).
- `p2_results_narrative_draft.md` — narrativa de portfólio (o que o sistema faz, o que os dados mostram), v3, re-ancorada no pipeline v5.
- `p2_writing_sample.md` — texto autoral sobre o projeto (decisões metodológicas e limites).
- `p2_horizonte_produto.md` — horizonte de produto (nacionalização, multi-bioma, multi-jurisdição); não é plano de execução do MVP.
- `exploration/exploring_script_explained.txt` / `sql/sql_explained.md` — guia comentado, linha a linha, do R e dos 4 arquivos SQL. Material de estudo, não faz parte do pipeline executável.

---

## Limitações conhecidas (resumo — detalhamento em `final_reference.md`, Seção 6)

- **O índice mede lacuna de fiscalização *federal*.** Só autos do IBAMA entram como resposta; aparatos estaduais ativos (ex.: SEMAS-PA, IPAAM-AM) não são capturados — um EGS alto é compatível com ausência real, substituição estadual, ou presença federal sem efeito.
- **PRODES ≠ desmatamento ilegal.** O índice não distingue supressão autorizada (AUTEX/DOF) de ilegal — caso verificado: Barra do Bugres/MT.
- **Resposta = autos lavrados.** Embargos, apreensões, ação penal e arrecadação efetiva das multas não entram.
- **EGS é ordinal na prática.** A ordenação é robusta (testada por sensibilidade); distâncias entre scores não têm interpretação direta.
- **Amazônia Legal apenas**; extensão exige join espacial (ver `p2_horizonte_produto.md`).
- **Último ano sujeito a revisão** — o dado PRODES 2025 pode não estar consolidado; a média de 3 anos o inclui, com essa ressalva.
- **`exploring_script.R` não tem o tratamento de portabilidade do SQL** (paths relativos ao working directory).
