Heirarchical modeling for men's NCAA basketball rankings

Author: Andrew Bartnof

Date: February 2026

Problem

March Madness is coming up, and I thought it would be fun to find a way to model team ability going into the tournament. The problem with team rankings is that if you are a very medium fish in a very small pond, your stats can look great (in college sports, this would be like being in a less competitive conference).

Latent variable analysis is the gold standard for this kind of problem, when raw metrics don't tell the whole story. But latent variable analysis models are generally fitted to situations where a lot of individuals each try to complete the same task (like a standardized test); they're not generally fitted to situations where two teams compete pairwise against each other.

Doran et al. (2007) suggest that you can actually use hierarchical modeling to model skill in situations too complex for conventional latent variable analyses.

Hypothesis

My hypothesis was that by feeding NCAA men's basketball scores into a hierarchical model in R, I could model team ability. I test two things:

1.  Whether all of the teams in the NCAA form one network, or multiple networks. I need them to form one network. This doesn't mean that each team plays every other team round-robin style; but it does mean that there aren't some communities that aren't completely cut off from the rest of the NCAA. I couldn't run one model if there are multiple unconnected communities.
2.  Whether a hierarchical model outperforms a simpler model.

Methods

The game data was collected using the [Python sportsdataverse package](https://www.sportsdataverse.org){.uri} for 2025-2026. The only data cleaning I did was to exclude any team that hadn't played

Results

Discussion
