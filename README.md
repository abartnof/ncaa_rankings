Heirarchical modeling for men's NCAA basketball rankings

Author: Andrew Bartnof

Date: February 2026

## Introduction

March Madness is coming up, and I thought it would be fun to find a way to model team ability going into the tournament. The problem with team rankings is that if you are a very medium fish in a very small pond, your stats can look great (in college sports, this would be like being in a less competitive conference).

Latent variable analysis is the gold standard for this kind of problem, when raw metrics don't tell the whole story. But latent variable analysis models are generally fitted to situations where a lot of individuals each try to complete the same task (like a standardized test); they're not generally fitted to situations where two teams compete pairwise against each other.

Doran et al. (2007) suggest that you can actually use hierarchical modeling to model skill in situations too complex for conventional latent variable analyses.

## Hypothesis

My hypothesis was that by feeding NCAA men's basketball scores into a hierarchical model in R, I could model team ability. I test two things:

1.  Whether all of the teams in the NCAA form one network, or multiple networks. I need them to form one network. This doesn't mean that each team plays every other team round-robin style; but it does mean that there aren't some communities that aren't completely cut off from the rest of the NCAA. I couldn't run one model if there are multiple unconnected communities.
2.  Whether a hierarchical model outperforms a simpler model.

## Methods

The game data was collected using the Python sportsdataverse package for 2025-2026. If a team hadn't played both 1. at least 5 home games, and 2. at least 5 away games, I omitted it.

Then, I used the R iGraph package to make sure all of the teams are interconnected in a single network of play; this was true.

I fit the hierarchical models using the following equation in the R lme4 package:

`did_home_team_win ~ 0 + (1|home_team) + (1|away_team)`

I suppressed the intercept, and fit random intercepts for both home_team and away_team. Conceptually, this means that if the skill of the home team is greater than the skill of the away team, then the home team won.

In order to judge the goodness-of-fit for this model, I ran 5-fold cross-validation on the model, and saved the residuals from the test data sets. I compared these residuals with the residuals from two other simplified models:

1.  Marginal home team win rate. Based on the training data, what is the likelihood that any home team will win? Use this as the probability that the home team wins every match.
2.  Conditional home team win rate. Based on the training data, what is the likelihood that each particular home team will win (irrespective of their visiting opponent)? Use this as the probability that each home team will win, respectively.

## Results

There was no question that the hierarchical model would output some measure of relative skill for each team. The question was, how well did the model fit the data? And did it fit the data better than cheaper models?

| Model                          | Accuracy |
|--------------------------------|----------|
| Marginal home team win rate    | 0.648    |
| Conditional home team win rate | 0.665    |
| Full model                     | 0.701    |

: Median Cross-Validated Model Accuracy

![Cross-validated model accuracy](diagrams/cross_val_accuracy.png)

On one hand, the full model had quite good predictive power. Even without including such important features as margin of victory, total points scored, or game date, this model was accurate for 70% of the testing data. Pretty good!

On the other hand, even though the hierarchical model outperformed the smaller models, it's worth noting just how well those models performed. The marginal rate model was accurate in 64.8% of the test cases; the conditional rate model was accurate in 66.5% of the test cases. To be clear, these models do not even consider who the opposing away team is in any game. Remarkable!

Recall that in the hierarchical model, home and away skill levels are modeled distinctly from each other. The Spearman's rank correlation coefficient between these two is -0.735 (negative because they're modeled as opposing forces for any given game). This is a pretty strong correlation.

The hierarchical model works really well if you know where two teams will play. But in a tournament setting, you might not know that. As a result, I think the easiest solution is just to add the absolute beta values for away and home games, and consider this 'composite skill' a pretty good predictor of how well a team will perform vis-a-vis an opposing team.
