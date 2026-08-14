# Suíte de visualização (R)

Gera as 14 figuras dos relatórios em `deliverables/`, a partir dos parquets do pipeline. Cada script começa com `source("viz/00_setup.R")`, que declara caminhos, constantes de integridade, paleta e tema, e carrega os dados com `stopifnot()`, no mesmo estilo de `exploration/exploring_script.R`.

Rode sempre a partir da raiz do projeto (abrir `project2.Rproj`).

---

## Os dois arquivos que rodam antes

Não são intercambiáveis: cada um cobre um tipo diferente de "roda antes dos numerados".

| Arquivo | Carregado por | Quando |
|---|---|---|
| `00_setup.R` | todos os scripts `01` a `06` | sempre; leitura barata dos parquets e da malha, paleta, tema |
| `prep_mesh.R` | nenhum | rodar isolado, uma vez, só se o conjunto de municípios do painel mudar |

---

## Onde cada coisa fica

| O quê | Local |
|---|---|
| Parquets do pipeline | `output/parquets/` |
| Malha municipal (GeoJSON) | `data/data_ibge/` |
| CSVs do IBAMA sem PII (ver `data/data_ibama_public/README.md`) | `data/data_ibama_public/` |
| Figuras geradas (PNG) | `output/visualizations/` |
| Caches intermediários da suíte | `output/parquets/viz_*.parquet` |

Todos declarados como constantes `PATH_*` / `FILE_*` no topo de `00_setup.R`. Se o layout mudar, muda em um lugar só.

---

## Instalação, uma vez

```r
install.packages(c(
  "tidyverse","sf","arrow","scales",          # 00_setup
  "geobr","rmapshaper",                        # prep_mesh (baixa e simplifica)
  "ggrepel","ineq","readr",                    # painéis + IBAMA bruto
  "fixest",                                     # efeitos de painel
  "igraph","ggraph"                             # rede de infratores
))
```

---

## Ordem de execução

Cada script de `01` a `06` é independente: rode qualquer um sozinho, em qualquer ordem, e ele produz suas próprias figuras corretamente. Um clone já traz a malha simplificada versionada, então `prep_mesh.R` não precisa ser rodado; ele só é necessário se o conjunto de municípios do painel mudar.

`04_raw_ibama.R` e `06_offender_network.R` chamam `load_ibama_clean()`, que lê o cache dos autos brutos se ele existir e o constrói se não existir. Rodar o `04` antes do `06` só poupa o `06` de refazer a leitura dos 18 CSVs; não é obrigatório.

| Script | Figuras do relatório | Produz |
|---|---|---|
| `prep_mesh.R` | (nenhuma) | malha municipal em `data/data_ibge/`, uma vez |
| `01_maps.R` | 1 a 5 | coropléticos que constroem o índice: desmatamento absoluto, % desmatado, multas, EGS, direção do EGS |
| `02_ranking_panels.R` | 7, 8, 14 | dispersão log-log, quadrante histórico × recente, séries dos casos-âncora |
| `03_annual_and_audit.R` | 6 | série anual (lacuna por tipo + área desmatada) |
| `04_raw_ibama.R` | 9 e 10 | curva de Lorenz e cancelamento por ano; **armazena em cache** a leitura do IBAMA bruto |
| `05_panel_effects.R` | 11 e 12 | gráfico de coeficientes (fixest) e event study em torno de um surto |
| `06_offender_network.R` | 13 | rede de infratores multi-município |

A numeração dos arquivos PNG acompanha a do relatório estendido: `Figura N` no texto corresponde a `N_*.png` em `output/visualizations/`. As figuras 1 a 5 são uma série numa ordem deliberada: numerador bruto, numerador normalizado, denominador, a razão, a direção da razão. Todas em quintil de rank sobre os mesmos 552 municípios, então um quintil significa uma coisa só na série inteira.

---

## Convenções herdadas da análise

- Join por `geocode_ibge` de 7 dígitos, nunca por nome: há 5 pares de homônimos no painel.
- EGS e `pct_desmatado` são ordinais: a cor é sempre quintil de rank (`q5()`), nunca valor bruto contínuo.
- As constantes de integridade (`N_MUNI`, `N_PANEL`, `N_YEARS`, `N_IBAMA_*`) são declaradas uma vez em `00_setup.R` e asseridas com `stopifnot()` em cada script, como no script de exploração.
- Os números que os relatórios publicam e que nascem aqui são fixados como constantes `PUB_*` no próprio script que os produz, ao lado do cálculo, e asseridos logo abaixo. `grep "^PUB_" viz/*.R` lista o inventário completo. É o mesmo contrato dos blocos de check do SQL: se um falhar depois de rebaixar dados, o que precisa mudar é o esperado e o texto que o publica, não o código.
- Os modelos de painel do `05` reproduzem o piloto em Python usando `fixest`, com efeitos fixos de município e ano e erros-padrão clusterizados por município: o estimador previsto para a tese.
- A verificação do pipeline (56 checks em `pipeline/01-04*.sql`) é independente desta suíte; nenhuma figura daqui é necessária para aqueles checks rodarem.
- Os gráficos não trazem título nem subtítulo, só rótulos de eixo e legenda. O título de cada figura vive como seção numerada no texto do relatório, em vez de ficar embutido no PNG. Isso evita duplicar o mesmo texto em dois lugares e qualquer descompasso de fonte entre o gráfico e o documento.
