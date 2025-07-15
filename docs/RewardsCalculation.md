# Rewards Distribution calculation

The amount of rewards distributed to builders and backers is based on the support throughout time that a builder gets
from backers. The support during a cycle impacts the rewards they receive at the beginning of the next one. Builders get
their rewards ready to claim immediately after the distribution while backers will receive them based on the amount of
time they support the builder during that cycle.

The system supports three types of rewards: RIF (`rewardsRif`), USDRIF (`rewardsUsdrif`), and coinbase (`rewardsCoinbase`).
All are distributed proportionally to each gauge's `rewardShares` over the `totalPotentialReward` for the cycle.

To calculate the amount of rewards to distribute to each builder and its backers, each Gauge keeps track of its rewards
shares. They are calculated based on the amount of votes per time left in the cycle that the gauge has

```text
rewardShares = allocations [wei] * timeUntilNextCycle [seconds]
```

Reward shares get updated every time there is a change in allocations (either adding or removing votes) based on the
time left to end the cycle and after a distribution:

- In case there is an increase in votes, the allocation deviation \* `timeUntilNextCycle` is added to the total rewards
  shares
- If votes are removed, then allocation deviation \* `timeUntilNextCycle` is removed from the total reward shares.
- After a distribution, reward shares get reset to the total amount of allocation that the gauge has at the moment
  multiplied by the duration of the cycle.

The `BackersManager` keeps track of the total amount of shares of every `Gauge` combined in `totalPotentialReward`.

On the other hand, the `BackersManager` also keeps track of the `rewardsRif`, `rewardsUsdrif`, and `rewardsCoinbase`.
These represent the RIF, USDRIF, and coinbase (native token) rewards to be distributed.
They get updated each time the `BackersManager` receives rewards through `notifyRewardAmount` and after each distribution, when they get
reset to 0.

This way, rewards for each Gauge are calculated based on their `rewardShares` and the `totalPotentialRewards`.

RIF rewards:

```text
(rewardShares * rewardsRif) / totalPotentialReward
```

USDRIF rewards:

```text
(rewardShares * rewardsUsdrif) / totalPotentialReward
```

Coinbase rewards:

```text
 (rewardShares * rewardsCoinbase) / totalPotentialReward
```

The `BackersManager` also keeps track of the `backerRewardPercentage`. This is passed to each gauge alongside the
rewards during the distribution so each gauge can calculate how much goes to the builder and how much to the backers.

## Builder Rewards

Their rewards calculation is pretty straightforward: it's based on the `backerRewardPercentage`. For instance, if there
was a distribution to a Gauge of 10 tokens and 10 coinbase with a `backerRewardPercentage` of 40%, the builder would get
6 tokens and 6 coinbase. The rest gets distributed during the cycle among all the backers based on their amount of votes
and time they maintained those votes.

## Backer Rewards

Backers can receive rewards through the distribution and through incentives in reward token and coinbase.

Their rewards are calculated per asset based on a `rewardRate`. What a builder earns in a cycle is in simple terms the
time they have spent supporting the builder multiplied by the reward rate and their allocation rate.

A simplistic way to calculate the rewards assuming there were no changes in allocation or incentives during the cycle
would be:

```text
(timeSinceCycleStarted * rewardRate) * (backerAllocation / totalAllocations)
```

Where the reward rate would be the amount of rewards to distribute per time left in the cycle

```text
rewardRate = totalRewards / timeUntilNextCycle
```

Going into more detail, there is a need to keep track of different variables since the `rewardRate` changes based on the
amount of rewards to distribute, and what the backers receive depends on how their votes change or not.

`rewardRate`: it changes every time rewards for backers are added to the Gauge, either by distribution or by incentives.
It is then affected by the total rewards, where

```text
totalRewards = backersAmount + rewardMissing + leftover
```

- `backersAmount`: newly added rewards, either by incentives or distribution
- `rewardMissing`: rewards from previous cycle that didn't get distributed since that cycle ended without votes or from
  current cycle if all allocations were removed at some point
- `leftover`: rewards that haven't been distributed yet in current cycle. It's calculated with previous `rewardRate`
  (before updating to the new one) and the time left of the current cycle.

What a backer earns depends directly on the `rewardRate` and the amount of allocations (their own and total
allocations).

So in order to keep track of what was earned until there were either new incentives or new allocations, we have the
`rewardPerTokenStored`. This is the `rewardPerToken` (reward rate per vote) that was earned up to that point. The time
of this update is also stored to be able to calculate future rewards from this point onwards.

- When there is an incentive, the following variables get updated:
  - The `rewardRate` (it depends directly on the amount of total rewards)
  - The `rewardPerTokenStored` (rewardRate per vote before updating to new rewardRate)
  - Time of the update (to current time of the incentive)
  - The missing rewards if there are no allocations
- In case of allocating, the following variables get updated:
  - The `rewardPerTokenStored` (it depends on the amount of votes)
  - Time of the update (to current time of the allocation)
  - The Backer rewards: rewards earned up to that point get stored here
  - The `backerRewardPerTokenPaid`: this is the `rewardPerTokenStored` at the moment of the allocation. Keeping track of
    this is necessary to calculate what a backer can claim at any point of the cycle.

The way we calculate what a backer has earned (and can claim) until the current point in time is the stored rewards +
the rewards since the last update (whether it was an incentives or allocations update).

As it was mentioned before, the stored rewards of a backer get updated every time there is a change in allocation.

```text
backer rewards = previous backer rewards + current rewards
```

Where current rewards are calculated by current allocations of the backer and `rewardPerToken`

```text
currentRewards = backerAllocation * (rewardPerToken - backerRewardPerTokenPaid)
```

The `backerRewardsPerTokenPaid` is taken away from the `rewardPerToken` since it represents what was already included in
the stored backer rewards, we only want to consider what was earned since the last allocation.
