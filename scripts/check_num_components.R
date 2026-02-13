# Check to make sure there aren't two discrete sub-populations of NCAA
# teams.

library(tidyverse)
library(arrow)
library(igraph)

df <- read_parquet('/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/filtered_game_scores.parquet')

team_names <-
	unique(c(df$home_team_name, df$away_team_name)) %>%
	enframe(name = NULL, value = 'team_name')

team_relations <-
	df %>%
	select(from=home_team_name, to=away_team_name) %>%
	distinct

g_mbb <- graph_from_data_frame(team_relations, directed = FALSE, vertices = team_names)
num_components <- components(g_mbb)$no

print("Checking if there are 1 components:")
sprintf("%i number of components", num_components)
g_mbb$layout

# There's a handful of outliers, but it's certainly a single component
plot(g_mbb, vertex.label=NA, vertex.size = 2, vertex.color = 'black')
