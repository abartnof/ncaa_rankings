# https://www.jstatsoft.org/article/view/v020i02
# The coeﬃcients in a generalized linear model for a binomial response with the logit link
# generate the log-odds for a positive response. 


library(tidyverse)
library(arrow)
library(skimr)
library(lme4)

df <- read_parquet('/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/game_scores.parquet') %>%
	filter(home_score != away_score)

# each game needs to be represented as a test, 
# which denotes a test-taker and a test.
# since there are two participants per game, this means each game is duplicated, 
# and the results are stored as if each participant is both a test-taker and a test

# version 1: home team as participant
home_as_participants <-
	df %>%
	rename(participant = home_team_name, item = away_team_name) %>%
	mutate(
		did_participant_win = home_score > away_score,
		participant_type = 'home',
	) %>%
	select(game_id, participant_type, participant, item, did_participant_win)

# version 2: away team as participant
away_as_participants <-
	df %>%
	rename(participant = away_team_name, item = home_team_name) %>%
	mutate(
		did_participant_win = away_score > home_score,
		participant_type = 'away'
	) %>%
	select(game_id, participant_type, participant, item, did_participant_win)

# qc: make sure there's one winner per game
table(home_as_participants$did_participant_win + away_as_participants$did_participant_win)

x <-
	bind_rows(home_as_participants, away_as_participants) %>%
	arrange(game_id) %>%
	mutate(did_participant_win = did_participant_win * 1L)


mod <- lmer(data = x, formula = 0 + did_participant_win ~ item + participant_type + (1|participant))

participant_skill <-
	mod %>%
	ranef %>%
	as_tibble %>%
	select(participant = grp, skill = condval)
	# mutate(probability_to_win = exp(condval) / (1 + exp(condval))) %>%
	# arrange(desc(probability_to_win)) %>%
	# tail

# Home-game advantage
mod %>%
	fixef %>%
	enframe %>%
	filter(name == 'participant_typehome') %>%
	mutate(value = exp(value)/ (1+exp(value)))

item_ease <-
	mod %>%
	fixef %>%
	enframe %>%
	filter(str_detect(name, '^item')) %>%
	mutate(name = str_replace(name, 'item', '')) %>%
	arrange(desc(value))


participant_skill <-
	mod %>%
	ranef %>%
	select(grp, condval) %>%
	mutate(condval = exp(condval)) %>%
	arrange(desc(condval))
	head

t <- 1.672
exp(t) / (1 + exp(t))
	exp(1.672)
exp(-0.4921)	

ranef(mod, condVar = TRUE) %>%
	as.data.frame %>%
	head
