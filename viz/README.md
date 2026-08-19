# Suíte de visualização (R)

Gera as 11 figuras dos relatórios em `deliverables/`, a partir dos parquets do pipeline. Cada script começa com `source("viz/00_setup.R")`, que declara caminhos, constantes de integridade, paletas e tema, e carrega os três parquets com `stopifnot()`, no mesmo estilo de `exploration/exploring_script.R`. A malha municipal e o pacote `sf` ficam fora dele, dentro do `01_maps.R`.

Rode sempre a partir da raiz do projeto (abrir `project2.Rproj`).

---

## Os dois arquivos que rodam antes

Não são intercambiáveis: cada um cobre um tipo diferente de "roda antes dos numerados".

| Arquivo | Carregado por | Quando |
|---|---|---|
| `00_setup.R` | todos os scripts numerados | sempre; leitura dos três parquets, constantes de integridade, as três rampas e a paleta das bandas de direção, tema |
| `prep_mesh.R` | nenhum | rodar isolado, uma vez, só se o conjunto de municípios do painel mudar |

---

## Onde cada coisa fica

| O quê | Local |
|---|---|
| Parquets do pipeline | `output/parquets/` |
| Malha municipal (GeoJSON) | `data/data_ibge/` |
| Figuras geradas (PNG) | `output/visualizations/` |

Todos declarados como constantes `PATH_*` / `FILE_*` no topo de `00_setup.R`. Se o layout mudar, muda em um lugar só.

---

## Instalação, uma vez

```r
install.packages(c(
  "tidyverse","sf","arrow","scales",          # 00_setup
  "geobr","rmapshaper",                        # prep_mesh (baixa e simplifica)
  "ggrepel",                                   # rótulos sem sobreposição
  "fixest"                                     # efeitos de painel
))
```

---

## Ordem de execução

Cada script numerado é independente: rode qualquer um sozinho, em qualquer ordem, e ele produz suas próprias figuras corretamente. Um clone já traz a malha simplificada versionada, então `prep_mesh.R` não precisa ser rodado; ele só é necessário se o conjunto de municípios do painel mudar.

A suíte lê apenas os três parquets do pipeline e, no `01_maps.R`, a malha. Nenhum script abre os CSVs brutos do IBAMA, e não há cache intermediário a construir.

| Script | Figuras do relatório | Produz |
|---|---|---|
| `prep_mesh.R` | (nenhuma) | malha municipal em `data/data_ibge/`, uma vez |
| `01_maps.R` | 2 a 5 e 7 | coropléticos que constroem o índice: desmatamento absoluto, % desmatado, resposta federal, EGS, direção do EGS |
| `02_ranking_panels.R` | 1, 8, 9 | a fórmula do EGS desenhada (numerador × denominador), quadrante histórico × recente, séries dos casos-âncora |
| `03_annual_and_audit.R` | 6 | série anual: situação dos 772 municípios e área desmatada, em dois painéis sobre o mesmo eixo de anos |
| `04_panel_effects.R` | 10 e 11 | gráfico de coeficientes (fixest) e event study em torno de um aumento anual do desmatamento |

A numeração dos arquivos PNG acompanha a do relatório estendido: `Figura N` no texto corresponde a `N_*.png` em `output/visualizations/`. Os cinco coropléticos (figuras 2 a 5 e 7) seguem a ordem que constrói o índice: numerador bruto, numerador normalizado, denominador, a razão, a direção da razão. As figuras 2, 3 e 5 quintilam os mesmos 552 municípios com pressão, então um quintil significa uma coisa só entre elas. A figura 4 é a exceção declarada: os 66 que tiveram pressão e nunca foram multados saem da rampa como categoria própria, e o quintil corre sobre os 486 restantes. A figura 7 não é quintil, é faixa de direção. Desde a integração das figuras ao corpo dos relatórios eles não aparecem juntos: a numeração segue a ordem de leitura, não a de construção.

---

## Convenções herdadas da análise

- Join por `geocode_ibge` de 7 dígitos, nunca por nome: há 5 pares de homônimos no painel.
- EGS e `pct_desmatado` são ordinais: a cor é sempre quintil de rank (`q5()`), nunca valor bruto contínuo.
- As constantes de integridade (`N_MUNI`, `N_PANEL`, `N_YEARS`, `N_MESH_FEATURES`, `N_TREND`) são declaradas uma vez em `00_setup.R` e asseridas com `stopifnot()` em cada script, como no script de exploração.
- Os números que os relatórios publicam e que nascem aqui são fixados como constantes `PUB_*` no próprio script que os produz, ao lado do cálculo, e asseridos logo abaixo. `grep "^PUB_" viz/*.R` lista o inventário completo. É o mesmo contrato dos blocos de check do SQL: se um falhar depois de rebaixar dados, o que precisa mudar é o esperado e o texto que o publica, não o código.
- A direção do EGS (`egs_trend`) é classificada no pipeline, em `03_analytics.sql`, ao lado da definição do índice: é escolha metodológica, não de desenho. As figuras 7 e 8 leem a coluna do parquet e `00_setup.R` apenas ordena os níveis e confere as contagens contra `N_TREND`. Antes cada figura classificava por conta própria, com vocabulários que discordavam. O cinza é `avg_egs_3y == 0`, não `n_years_pressure == 0`: onde a pressão cessou não há direção a medir.
- Os modelos de painel do `05` reproduzem o piloto em Python usando `fixest`, com efeitos fixos de município e ano e erros-padrão clusterizados por município: o estimador previsto para a tese.
- A malha e o pacote `sf` são carregados dentro de `01_maps.R`, não no `00_setup.R`: são 2,7 MB de GeoJSON e a ligação com GDAL, GEOS e PROJ, e só os mapas precisam deles.
- Uma exceção declarada à regra de que a suíte não calcula: o Spearman de 0,503 em `02_ranking_panels.R`. Ele não descreve o índice, descreve a própria figura 1, medindo o quanto a razão dos totais de dezoito anos diverge do índice publicado, que é a média das razões anuais. É um número que só existe porque a figura existe, e por isso mora com ela.
- A verificação do pipeline (56 checks em `pipeline/01-04*.sql`) é independente desta suíte; nenhuma figura daqui é necessária para aqueles checks rodarem.
- Os gráficos não trazem título nem subtítulo, só rótulos de eixo e legenda. O título de cada figura vive como seção numerada no texto do relatório, em vez de ficar embutido no PNG. Isso evita duplicar o mesmo texto em dois lugares e qualquer descompasso de fonte entre o gráfico e o documento.
