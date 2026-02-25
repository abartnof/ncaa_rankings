# ------------------------------------------------------------
# Title      : Single measures hierarchical model
# Description: Load cleaned game‑score data, reshape it to a
#              home/away format, fit a logistic mixed‑effects
#              model (glmer) to predict win probability, and
#              extract fixed and random effects for further
#              analysis (home‑team advantage, team strengths,
#              residual diagnostics, etc.).
#
#              Model logic: 
#              Consider the random-effect for a single team as akin to its 
#              'skill', in latent variable terms.
#              Model each game as the skill of the home team, minus the skill of
#              the away team.
#
#              https://www.jstatsoft.org/article/view/v020i02
#              The coeﬃcients in a generalized linear model for a binomial 
#              response with the logit link. generate the log-odds for a 
#              positive response. 
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
output_fn <- '/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/output_team_scores/lmer_team_rankings.csv'
print(df)


team_levels <- unique(c(df$home_team_name, df$away_team_name))
# Create the modeling dataframe
model_data <-
	df %>%
	mutate(
		home_team = factor(home_team_name, levels = team_levels, ordered = FALSE),
		away_team = factor(away_team_name, levels = team_levels, ordered = FALSE),
		did_home_win = as.integer(home_score > away_score),
		# game_date_z = as.vector(scale(as.integer(game_date)))
	)

#### Model ####
mod <- glmer(
	data = model_data, 
	family = binomial(link = "logit"),
	formula = did_home_win ~ 0 + (1|home_team_name) + (1|away_team_name))


#### Check out the results ####
# Residuals.
# strangely fitting model: there seems to actually be two sub-populations?
# it's beyond the remit of this model, but it's worth noting!
residuals(mod) %>%
	enframe(name=NULL, value='residual') %>%
	ggplot(aes(x = residual)) +
	geom_histogram()

qqnorm(residuals(mod))


# Check out the random effects of the model
re <- ranef(mod)
# note that you actually subtract away from home to get the prediction of a winner
# so away is on a negative scale
skill <-
	re %>%
	as_tibble %>%
	select(grpvar, grp, condval) %>%
	spread(grpvar, condval) %>%
	rename(away = away_team_name, home = home_team_name)
head(skill)

# how well do these correlate?
# pretty well! (negatively!)
skill %>%
	drop_na %>%
	with(., cor(away, home, method = 's'))

# Check out variance in estimates
# 1. does variance correlate with skill?
# technically yes-- more for away than for home-- but it doesn't look 
# strange so i'm not suspicious. I assume the away-team 'bonus' is just 
# different for each team.

re %>%
	as.data.frame %>%
	as_tibble %>%
	select(grpvar, condval, condsd) %>%
	group_by(grpvar) %>%
	nest %>%
	mutate(cor = map_dbl(data, ~with(., cor(condval, condsd)))) %>%
	ungroup

# home teams
re %>%
	as.data.frame %>%
	as_tibble %>%
	filter(grpvar == 'home_team_name') %>%
	arrange(condval) %>%
	mutate(
		low = condval - condsd, 
		high = condval + condsd,
		grp = fct_reorder(grp, condval)
	) %>%
	ggplot(aes(x = grp, y = condval, ymin = low, ymax = high)) +
	geom_point() +
	geom_errorbar() +
	coord_flip() +
	theme(axis.text.y = element_blank()) +
	labs(y = 'Estimated skill', x = 'Home team')

# away teams
re %>%
	as.data.frame %>%
	as_tibble %>%
	filter(grpvar == 'away_team_name') %>%
	arrange(condval) %>%
	mutate(
		low = condval - condsd, 
		high = condval + condsd,
		grp = fct_reorder(grp, condval)
	) %>%
	ggplot(aes(x = grp, y = condval, ymin = low, ymax = high)) +
	geom_point() +
	geom_errorbar() +
	coord_flip() +
	theme(axis.text.y = element_blank()) +
	labs(y = 'Estimated skill', x = 'Away team')

# There's a non-linear relationship between skill and variance
re %>%
	as.data.frame %>%
	as_tibble %>%
	select(grpvar, condval, condsd) %>%
	ggplot(aes(x = condval, y = condsd)) +
	geom_point() +
	geom_smooth(method = 'loess') +
	facet_wrap(~grpvar) +
	labs(x = 'Skill estimate', y = 'Skill variance')

home_n <-
	df %>%
	count(home_team_name) %>%
	mutate(game_type = 'home') %>%
  select(game_type, team_name = home_team_name, n)

away_n <-
	df %>%
	count(away_team_name) %>%
	mutate(game_type = 'away') %>%
  select(game_type, team_name = away_team_name, n)

collected_counts <-
	bind_rows(home_n, away_n)

# as we might guess, there's basically an inverse relationship between how often
# a team plays, and how much variance there is in their skills
variance_to_counts <-
	re %>%
	as_tibble %>%
	select(grpvar, grp, condsd) %>%
	mutate(grpvar = case_match(grpvar, 
														 'away_team_name' ~ 'away',
														 'home_team_name' ~ 'home'),
				 grp = as.character(grp)
				 ) %>%
	rename(game_type = grpvar, team_name = grp) %>%
	left_join(collected_counts, by = c('game_type', 'team_name'))

variance_to_counts %>%
	ggplot(aes(x = n, y = condsd)) +
	geom_point() +
	geom_smooth(method = 'loess') +
	geom_smooth(method = 'lm', color = 'red') +
	facet_wrap(~game_type)

# the correlations between game count and variance is both 1. basically the same
# for away or home, and 2. pretty strong. i think this is a pretty informative
# (and common-sensical) correlation
variance_to_counts %>%
	group_by(game_type) %>%
	nest() %>%
	mutate(
		cor = map_dbl(data, ~with(., cor(condsd, n)))
	) %>%
	ungroup


# Without knowing if a team is going to be playing home or away, we can just
# create a 'composite' skill (avg of the two)

composite <-
	skill %>%
	drop_na %>%
	mutate(
		away = -away,
	) %>%
	rowwise() %>%
	mutate(composite = 0.5 * (away + home)) %>%
	ungroup %>%
	rename(team_name = grp) %>%
	arrange(desc(composite))

print(composite)

composite %>%  write_csv(output_fn)
