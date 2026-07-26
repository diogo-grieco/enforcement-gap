# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite — 07 offender network
# IBAMA raw data (cached)
#
# Author: Diogo Grieco
#
# Purpose: Multi-municipality offender network (item 18). Bipartite graph of
#          offenders (CPF/CNPJ) fined for deforestation in 3+ distinct
#          municipalities, linked to those municipalities — the territorial
#          reach of repeat offenders, invisible in the official municipality
#          aggregates. Self-contained: reads the same raw IBAMA cache as
#          04_raw_ibama.R via load_ibama_clean() (00_load_ibama_clean.R),
#          which builds the cache itself if it doesn't exist yet — running
#          04 first is faster (skips the 18-CSV read) but not required.
# =============================================================================

source("viz/00_setup.R")
source("viz/00_load_ibama_clean.R")
library(igraph)
library(ggraph)

# -----------------------------------------------------------------------------
#### Load + filter raw IBAMA (shared loader); network needs a valid offender id
# -----------------------------------------------------------------------------

clean <- load_ibama_clean()$clean %>%
  filter(!is.na(CPF_CNPJ_INFRATOR))

# -----------------------------------------------------------------------------
#### Offenders active in 3+ municipalities
# -----------------------------------------------------------------------------

MIN_MUNIS <- 3
offender_reach <- clean %>%
  distinct(CPF_CNPJ_INFRATOR, COD_MUNICIPIO) %>%
  count(CPF_CNPJ_INFRATOR, name = "n_munis") %>%
  filter(n_munis >= MIN_MUNIS)

# Edges: offender -- municipality; offenders anonymised (never show raw CPF/CNPJ).
edges <- clean %>%
  filter(CPF_CNPJ_INFRATOR %in% offender_reach$CPF_CNPJ_INFRATOR) %>%
  distinct(CPF_CNPJ_INFRATOR, COD_MUNICIPIO) %>%
  mutate(offender = paste0("offender_", dense_rank(CPF_CNPJ_INFRATOR))) %>%
  left_join(ranking %>% select(geocode_ibge, municipality_name),
            by = c("COD_MUNICIPIO" = "geocode_ibge")) %>%
  transmute(from = offender, to = municipality_name)

# -----------------------------------------------------------------------------
#### Build + type the graph, then plot
# -----------------------------------------------------------------------------

g <- graph_from_data_frame(edges, directed = FALSE)
V(g)$type <- ifelse(V(g)$name %in% edges$from, "offender", "municipality")

set.seed(1)   # reproducible layout
p_net <- ggraph(g, layout = "fr") +
  geom_edge_link(alpha = 0.25, colour = "grey55") +
  geom_node_point(aes(colour = type, size = type)) +
  scale_colour_manual(values = c(offender = "#a63d2f", municipality = "#2e6e54"),
                      labels = c(offender = "infrator", municipality = "município"), name = NULL) +
  scale_size_manual(values = c(offender = 3, municipality = 1.8), guide = "none") +
  theme_void(base_size = 12)

ggsave(file.path(PATH_OUT, "18_offender_network.png"), p_net, width = 9, height = 7, dpi = 150)
