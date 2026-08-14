# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Visualization Suite: 06 offender network
# IBAMA raw data (cached)
#
# Author: Diogo Grieco
#
# Purpose: Multi-municipality offender network (report figure 13). Bipartite
#          graph of offenders fined for deforestation in 3+ distinct
#          municipalities, linked to those municipalities: the territorial
#          reach of repeat offenders, invisible in the municipality
#          aggregates. Calls load_ibama_clean() (00_setup.R), which builds the
#          cache if missing; running 04 first only saves the 18-CSV read.
# =============================================================================

source("viz/00_setup.R")
library(igraph)
library(ggraph)

# -----------------------------------------------------------------------------
#### Load + filter raw IBAMA; the network needs a valid offender id
# -----------------------------------------------------------------------------

clean <- load_ibama_clean()$clean %>%
  filter(!is.na(CPF_CNPJ_INFRATOR))

# -----------------------------------------------------------------------------
#### Offenders active in 3+ municipalities
# -----------------------------------------------------------------------------
# The 3-municipality cut is a reading choice, not a tested threshold: pinning
# the size of the graph is what keeps the figure from changing content
# unnoticed.

MIN_MUNIS <- 3
offender_reach <- clean %>%
  distinct(CPF_CNPJ_INFRATOR, COD_MUNICIPIO) %>%
  count(CPF_CNPJ_INFRATOR, name = "n_munis") %>%
  filter(n_munis >= MIN_MUNIS)

PUB_N_OFFENDERS_3PLUS <- 117
PUB_MAX_REACH         <- 6

stopifnot(
  "network: count of 3+ municipality offenders changed" =
    nrow(offender_reach) == PUB_N_OFFENDERS_3PLUS,
  "network: maximum offender reach changed" =
    max(offender_reach$n_munis) == PUB_MAX_REACH
)

# Edges: offender to municipality, offenders relabelled (never show the id).
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
  scale_colour_manual(
    values = c(offender = "#a63d2f", municipality = "#2e6e54"),
    labels = c(offender = "infrator", municipality = "município"),
    name = NULL) +
  scale_size_manual(values = c(offender = 3, municipality = 1.8),
                    guide = "none") +
  theme_void(base_size = 12)

ggsave(file.path(PATH_OUT, "13_offender_network.png"), p_net,
       width = 9, height = 7, dpi = 150)
