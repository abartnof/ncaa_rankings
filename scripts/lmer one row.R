# lmer 1 row per game

# https://www.jstatsoft.org/article/view/v020i02
# The coeﬃcients in a generalized linear model for a binomial response with the logit link
# generate the log-odds for a positive response. 

# we'll create a model using glmer in which we model two latent variables:
#  - skill at home
#  - skill away
#  - then, make a composite score

library(tidyverse)
library(arrow)
library(skimr)
library(lme4)
library(ggrepel)

df_raw <- read_parquet('/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/game_scores.parquet')

# Filter 
# 1. to teams that have scored at least 5 games home, and 5 games away.
# 2. to games where one team won and the other didn't (seems obvious)
num_games <- 5L

valid_home_teams <-
	df %>%
	count(home_team_name) %>%
	filter(n >= num_games) %>%
	select(team_name = home_team_name)

valid_away_teams <-
	df %>%
	count(away_team_name) %>%
	filter(n >= num_games) %>%
	select(team_name = away_team_name)

valid_team_list <-
	valid_home_teams %>%
	inner_join(valid_away_teams, by = 'team_name') %>%
	pull

df <-
	df_raw %>%
	filter(
		home_score != away_score,
		home_team_name %in% valid_team_list,
		away_team_name %in% valid_team_list
	)
sprintf('%i input games', nrow(df_raw))
sprintf('%i usable games', nrow(df))
sprintf('%i games omitted', nrow(df_raw) - nrow(df))

# Create the modeling dataframe
model_data <-
	df %>%
	mutate(
		home_team = factor(home_team_name, levels = valid_team_list),
		away_team = factor(away_team_name, levels = valid_team_list),
		did_home_win = as.integer(home_score > away_score),
		game_date_z = as.vector(scale(as.integer(game_date)))
	)

mod0 <- glm(
	data = model_data, 
	family = binomial(link = "logit"),
	formula = did_home_win ~ 1)

mod <- glmer(
	data = model_data, 
	family = binomial(link = "logit"),
	formula = did_home_win ~ 0 + (1|home_team_name) + (1|away_team_name))

mod_time <- glmer(
	data = model_data, 
	family = binomial(link = "logit"),
	formula = did_home_win ~ 0 + (game_date_z|home_team_name) + (game_date_z|away_team_name))

# GOF
# interpretation: this model is a pretty good estimator of where things are,
# but as a predictor, it's got issues.

# the residuals are no better than a true null model's residuals
t.test(residuals(mod0), residuals(mod), paired = TRUE)

# it would be nice to include time as random slopes, but it's not really worth it.
# the ANOVA isn't significant, and the residuals are about the same.
anova(mod, mod_time)
qqnorm(residuals(mod))
qqnorm(residuals(mod_time))


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
skill %>%
	drop_na %>%
	with(., cor(away, home, method = 's'))

# Let's assume the best teams have played plenty of games home and away, so if a 
# team hasn't played home or abroad, we aren't interested in them for our brackets.
# skill %>%
# 	drop_na %>%
# 	mutate(
# 		away = -away,
# 		composite = away + home
# 	) %>%
# 	arrange(desc(composite)) %>%
# 	rowid_to_column() %>%
# 	filter(str_detect(grp, 'Texas')) %>%
# 	rename(team = grp)

# depending on if we keep an intercept, this is the mean probability of winning
composite <-
	skill %>%
	drop_na %>%
	mutate(
		away = -away,
		away = exp(away / (1-exp(away))),
		home = exp(home / (1-exp(home)))
	) %>%
	rowwise() %>%
	mutate(composite = 0.5 * (away + home)) %>%
	ungroup %>%
	arrange(desc(composite))
composite

composite %>%
	rowid_to_column('i') %>%
	mutate(my_label = if_else(i < 5, grp, NA_character_)) %>%
	ggplot(aes(x = home, y = away, label = my_label)) +
	# geom_label() +
	geom_point() +
	scale_x_continuous(limits = c(0, 1), labels = scales::percent_format()) +
	scale_y_continuous(limits = c(0, 1), labels = scales::percent_format()) +
	labs(x = 'Home win %', y = 'Away win %')

composite %>%
	rowid_to_column('i') %>%
	mutate(
		my_label = if_else(i < 20, grp, NA_character_),
		my_color = if_else(i < 20, grp, '(Other)')
		) %>%
	ggplot(aes(x = home, y = away, label = my_label, color = my_color)) +
	geom_text(hjust = -.1) +
	geom_point() +
	scale_x_continuous(labels = scales::percent_format()) +
	scale_y_continuous(labels = scales::percent_format()) +
	coord_cartesian(xlim = c(0.5, 1), y = c(0.5, 1)) +
	labs(x = 'Home win %', y = 'Away win %') +
	theme(legend.position = 'none')

?geom_text_repel


# GOF
qqnorm(residuals(mod))
