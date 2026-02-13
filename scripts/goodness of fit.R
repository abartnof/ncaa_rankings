# Title: NCAA Model Goodness of Fit
# Author: Andrew Bartnof

# Check our model's accuracy against a few 'null' hypotheses models:
  # 1. A marginal rate model, in which the overall % of home games won becomes 
	#    our predictor
  # 2. A conditional home team model, in which rate rate of each home team 
  #    winning a game becomes the predictor for any particular game
  # Use n-fold cross-validation to test the accuracy of predictions.

library(tidyverse)
library(arrow)
library(skimr)
library(lme4)
set.seed(1)


#### Load data ####

df_raw <- read_parquet('/Users/andrewbartnof/Documents/projects/public/ncaa_rankings/clean_data/game_scores.parquet')

# Filter 
# 1. to teams that have scored at least 5 games home, and 5 games away.
# 2. to games where one team won and the other didn't (seems obvious)
num_games <- 5L

valid_home_teams <-
	df_raw %>%
	count(home_team_name) %>%
	filter(n >= num_games) %>%
	select(team_name = home_team_name)

valid_away_teams <-
	df_raw %>%
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
		did_home_win = as.integer(home_score > away_score)
	)


#### Create functions that test models ####
# GLMER full model
fit_glmer <- function(train_data){
	mod <- glmer(
		data = train_data, 
		family = binomial(link = "logit"),
		formula = did_home_win ~ 0 + (1|home_team_name) + (1|away_team_name))
	return(mod)
}

predict_glmer <- function(mod, new_data){
	y_fit <- predict(
		object=mod, 
		newdata=new_data, 
		type = 'response', 
		allow.new.levels=FALSE)
	return(y_fit)
}


# Marginal home team win rate

get_marginal_home_team_win_rate <- function(train_data){
	# Input training data, get the marginal rate of the home team winning
	marginal_home_team_win_rate <- mean(train_data$did_home_win)
	return(marginal_home_team_win_rate)
}


# Conditional win rate for each home team

fit_tool_cond_win_home <- function(train_data){
	# input training data, get a tibble with the conditional win rate for each home team
	conditional_win_rate_for_home_team <-
		train_data %>%
		group_by(home_team_name) %>%
		summarize(win_rate = mean(did_home_win))
	return(conditional_win_rate_for_home_team)
}

predict_cond_win_home <- function(test_data, tool_cond_win_home){
		test_data %>%
		select(home_team_name) %>%
		left_join(tool_cond_win_home, by = 'home_team_name') %>%
		pull(win_rate)
}

#### loop through folds to perform cross-validation ####
# assign folds

folds_assigned <- model_data
folds_assigned$fold <- sample(x=seq(1, 5), replace = TRUE, size = nrow(model_data))
y_fit_collected <- tibble()

# perform cross-validation
for (target_fold in seq(1, 5)){
	print(target_fold)
	train_data <- folds_assigned %>% filter(fold != target_fold)
	test_data <- folds_assigned %>% filter(fold == target_fold)
	
	mod_fold <- fit_glmer(train_data = train_data)
	test_data$y_fit_glmer <- predict_glmer(mod=mod_fold, new_data=test_data)
	
	test_data$y_fit_marg <- get_marginal_home_team_win_rate(train_data = train_data)
	
	tool_cond_win_home <- fit_tool_cond_win_home(train_data = train_data)
	test_data$y_fit_cond_win_home <- predict_cond_win_home(test_data = test_data, tool_cond_win_home =  tool_cond_win_home)
	
	y_fit_collected <- y_fit_collected %>% bind_rows(
		test_data %>% select(fold, did_home_win, starts_with('y_fit'))
		)
}

#### Check goodness-of-fit metrics ####
y_fit_collected %>%
	skim

accuracy_long <-
	y_fit_collected %>%
	gather(mod, y_fit, -fold, -did_home_win) %>%
	mutate(
		y_fit = round(y_fit),
		accuracy = did_home_win == y_fit,
		mod = fct_recode(mod, 
										 'Full model' = 'y_fit_glmer', 
										 'Conditional home team win rate' = 'y_fit_cond_win_home',
										 'Marginal home team win rate' = 'y_fit_marg'
										 ),
		mod = fct_reorder(mod, accuracy, mean)
	)


fold_accuracy <-
	accuracy_long %>%
	group_by(mod, fold) %>%
	summarize(accuracy = mean(accuracy)) %>%
	ungroup

overall_median_accuracy <-
	fold_accuracy %>%
	group_by(mod) %>%
	summarize(accuracy = median(accuracy)) %>%
	ungroup

overall_median_accuracy

fold_accuracy %>%
	ggplot(aes(x = mod, y = accuracy)) +
	geom_point() +
	# geom_point(data = overall_median_accuracy, color = 'blue', size = 5) +
	labs(x = 'Model', y = 'Accuracy', color = '') +
	coord_cartesian(ylim = c(0.5, 1)) +
	scale_y_continuous(labels = scales::percent_format())
