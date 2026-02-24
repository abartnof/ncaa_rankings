# ------------------------------------------------------------
# Title      : Repeated measures hierarchical model
# Description: Load cleaned game‑score data, reshape it to a
#              home/away format, fit a logistic mixed‑effects
#              model (glmer) to predict win probability, and
#              extract fixed and random effects for further
#              analysis (home‑team advantage, team strengths,
#              residual diagnostics, etc.).
#
#              Model logic: 
#              This model is a slight variation on the previous script, 
#              which uses a single row for each game. 
#              in contrast, this considers each game as a repeated-measure.
#
# Author     : Andrew Bartnof
# Created    : 2026‑02‑23
# Version    : 1.0
#
# Required Packages ------------------------------------------------
# tidyverse   – data manipulation & piping
# arrow       – reading Parquet files
# skimr       – quick summary statistics
# lme4        – fitting GLMMs (glmer)
# lubridate  – handling dates
#
# Usage -----------------------------------------------------------
# Run the script from an R session (or RStudio) after installing
# the required packages. It will read the Parquet file, prepare the
# dataset, fit the model, and output various diagnostics and
# summaries.
#
# ------------------------------------------------------------


library(tidyverse)
library(arrow)
library(skimr)
library(lme4)

#### Prepare data ####

df <- read_parquet('/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/filtered_game_scores.parquet') %>%
	mutate( game_date = lubridate::as_date(game_date) )
print(df)

# Create two rows per game; from the pov of the home team, 
# and from the pov of the away team. Do this by stacking two dataframes on top
# of each other.

home <-
	df %>%
	mutate(
		is_win = home_score > away_score,
		is_home = TRUE
	) %>%
	rename(target = home_team_name, opponent = away_team_name) %>%
	select(game_id, target, opponent, is_win, is_home)

away <-
	df %>%
	mutate(
		is_win = away_score > home_score,
		is_home = FALSE
	) %>%
	rename(target = away_team_name, opponent = home_team_name) %>%
	select(game_id, target, opponent, is_win, is_home)

X <- bind_rows(home, away) %>% arrange(game_id)


#### Model data ####
# Consider is_home game as a fixed-effect variable; everything else is a 
# random-effect.

# as of testing, this had a singular fit. normal considering that game_id
# is included as a random-effect.
mod <- glmer(data = X, family = binomial(link = 'logit'),
						 formula = is_win ~ 0 + is_home + (1|game_id) + (1|target) + (1|opponent)
						 )

random_effects <- ranef(mod) %>% as.data.frame

# Correlation of each team's skills as home and away?
# Yes, there's a perfect (negative) correlation, which means the 
# model is working perfectly.
opponent_away <-
	random_effects %>%
	tibble %>%
	filter(grpvar %in% c('target', 'opponent')) %>%
	select(grpvar, grp, condval) %>%
	spread(grpvar, condval)
print(opponent_away)
cor(opponent_away$opponent, opponent_away$target, method = 's')

# given the perfect (negative) cor, just use each team's row where they're 
# considered the target team. then, check out team skill estimates
target <-
	random_effects %>%
	as_tibble %>%
	filter(grpvar == 'target') %>%
	rename(target = grp) %>%
	select(target, condval, condsd) %>%
	arrange(desc(condval))



# the variance around the random effects is not very high
target %>%
	skim(condsd)

# the variance looks higher among weaker teams
target %>%
	mutate(low = condval - condsd, high = condval + condsd) %>%
	ggplot(aes(x = target, y = condval)) +
	geom_point() +
	geom_errorbar(aes(ymin = low, ymax = high)) +
	coord_flip() +
	theme(axis.text.y=element_blank()) +
	labs(y = 'Estimate of team skill', x = 'Team')

# and the more a team plays, the lower the variance. this makes sense.
games_played <-
	df %>%
	select(home_team_name, away_team_name) %>%
	gather(role, team_name) %>%
	count(team_name)

variance_vs_games_played <-
	target %>%
	rename(team_name = target) %>%
	select(team_name, condsd) %>%
	left_join(games_played)
print(variance_vs_games_played)
cor(variance_vs_games_played$condsd, variance_vs_games_played$n, method = 's')
	
# Check out the residuals. 
# We have the same issue we had in the other model- bimodal residuals
residuals(mod) %>%
	enframe(name=NULL, value='residual') %>%
	ggplot(aes(x=residual)) +
	geom_histogram()

# what is the home-team advantage?
fixef(mod) %>%
	enframe %>%
	mutate(
		prob = exp(value) / (1+exp(value))
	)

# Finally, look at team skills
target %>%
	arrange(desc(condval))
