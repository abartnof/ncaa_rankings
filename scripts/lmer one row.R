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

df <- read_parquet('/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/filtered_game_scores.parquet') %>%
	mutate( game_date = lubridate::as_date(game_date) )
print(df)


team_levels <- unique(c(df$home_team_name, df$away_team_name))
# Create the modeling dataframe
model_data <-
	df %>%
	mutate(
		home_team = factor(home_team_name, levels = team_levels, ordered = FALSE),
		away_team = factor(away_team_name, levels = team_levels, ordered = FALSE),
		did_home_win = as.integer(home_score > away_score),
		game_date_z = as.vector(scale(as.integer(game_date)))
	)

mod <- glmer(
	data = model_data, 
	family = binomial(link = "logit"),
	formula = did_home_win ~ 0 + (1|home_team_name) + (1|away_team_name))


# strangely fitting model: there seems to actually be two sub-populations?
# it's beyond the remit of this model, but it's worth noting!
qqnorm(residuals(mod))
hist(residuals(mod))


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
# pretty well!
skill %>%
	drop_na %>%
	with(., cor(away, home, method = 's'))

composite <-
	skill %>%
	drop_na %>%
	mutate(
		away = -away,
		# away = exp(away / (1-exp(away))),
		# home = exp(home / (1-exp(home)))
	) %>%
	rowwise() %>%
	mutate(composite = 0.5 * (away + home)) %>%
	ungroup %>%
	arrange(desc(composite))

# out of curiosity, what does home + away skill look like?
# answer: normal distribution, with a mean around 0; looks good!
hist(composite$composite)
