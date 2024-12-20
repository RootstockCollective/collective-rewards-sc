# Collective Rewards Specification

## Definitions

- Builder: anyone who is building on Rootstock and is activated through the RootstockCollective DAO
- Backer: anyone who staked their RIF to participate to the Collective Reward program
- CR: Collective Reward

## Roles

- Governor: an address in charge of executing the RootstockCollective DAO proposals.
- Authorized change: a smart contract temporarily authorized by the Governor.
- Foundation treasury: an address in charge of managing the CR treasury.
- KYC Approver: an address in charge of approve the Builder KYC.
- Upgrader: an address that, withing the Governor and the authorized changer, can upgrade the contracts.

For more information about how roles are managed, please refer to [`GovernanceManager`](/src/governance/GovernanceManagerRootstockCollective.sol).

## Purpose

The Collective Rewards protocol aims to create a decentralized system to allow Builders and Backers to get rewards. The main idea is to allow Backers who have StRIF (by staking RIF), to allocate their votes to activated Builders. In order for a Builder to be activated they need to:

- get the KYC approval by the KYC Approver
- get the community approval through the RootstockCollective DAO.
When a Builder is KYC approved, they need to specify the amount of rewards that they plan to distribute to their Backers as a percentage of the rewards that they'll get.
Once the Builder is activated, they can be voted by Backers. The number of votes that a Builder gets will determine the rewards the Builder will be entitled of. If a Backer allocated votes for a Builder, they'll receive rewards that are proportional to the votes allocated and the amount of time for which the votes stay allocated to that Builder.

Example:\
Chad is a Builder.\
Alice and Bob are Backers.\
Chad is KYC and community approved and his backer rewards percentage is 50%.\
The Backers who vote for Chad will get 50% of the rewards distributed to Chad.\
At the end of the cycle Chad is entitled to get 2000 RIF.\
Alice voted with 100 StRIF for Chad for half cycle.\
Bob voted with 100 StRIF for Chad for a whole cycle.\
Chad will get 1500 RIF (75%).\
Bob will get 375 RIF. For half of the cycle, Bob got all the possible rewards, 500/2 = 250. For the other half of the cycle, the remaining rewards got split between Alice and Bob, hence 250/2 = 125.\
Alice will get 125 RIF.\

## Builder status

To keep track of the Builder status, the contracts make use of the `BuilderState`

```solidity
bool activated;
bool kycApproved;
bool communityApproved;
bool paused;
bool revoked;
bytes7 reserved; // for future upgrades
bytes20 pausedReason;
```

- `activated`: it's activated once either when the Builder is KYC approved for the first time (`BuilderRegistry#activateBuilder()`) or when it's migrated from v1 (`BuilderRegistry#migrateBuilder()`) and it will never be unset.
- `kycApproved`: it's set when the Builder is KYC approved (`BuilderRegistry#activateBuilder()` or `BuilderRegistry#approveBuilderKYC()`) or when the Builder is migrated from v1 (`BuilderRegistry#migrateBuilder()`) and it can be unset when the KYC is revoked (`BuilderRegistry#revokeBuilderKYC()`).
- `communityApproved`: it's set when the Builder is community approved (`BuilderRegistry#communityApproveBuilder()`) and unset when the community approval is removed (`BuilderRegistry#dewhitelistBuilder()`). **Once the flag is unset, it cannot be reset again**.
- `paused`: this flag can be used by the KYC Approver to temporarily pause a Builder (`BuilderRegistry#pauseBuilder()`) because of additional checks required on that Builder. The KYC approver can specify a reason (`pausedReason`) when pausing the Builder. It's unset by the KYC Approver also (`BuilderRegistry#unpauseBuilder()`) and this flag can be set and unset at any time.
- `revoked`: this flag is set by the Builders themselves if they don't want to participate to CR (`BuilderRegistry#revokeBuilder()`). It's also unset by the Builders when they want to be part of CR again (`BuilderRegistry#permitBuilder`).

### Conditions required to switch the Builder's flags

| Action                    | Paused    | Revoked   | KYC Approved  | Activated | Community Approved    |
|---------------------------|:---------:|:---------:|:-------------:|:---------:|:---------------------:|
| ActivateBuilder           |   -       |   -       |   -           |   False   |   -                   |
| CommunityApproveBuilder   |   -       |   -       |   -           |   -       |   False               |
| ApproveBuilderKYC         |   -       |   -       |   False       |   True    |   -                   |
| RevokeBuilderKYC          |   -       |   -       |   True        |   -       |   -                   |
| RevokeBuilder             |   -       |   False   |   True        |   -       |   True                |
| PermitBuilder             |   -       |   True    |   True        |   -       |   True                |
| PauseBuilder              |   -       |   -       |   -           |   -       |   -                   |
| UnpauseBuilder            |   True    |   -       |   -           |   -       |   -                   |
| DewhitelistBuilder        |   -       |   -       |   -           |   -       |   True                |

### Conditions required to execute actions:

| Action                    | Paused    | Revoked   | KYC Approved  | Activated | Community Approved    |
|---------------------------|:---------:|:---------:|:-------------:|:---------:|:---------------------:|
| Allocate (increase)       |   -       |   False   |   True        |   -       |  True                 |
| Allocate (decrease)       |   -       |   -       |   -           |   -       |  -                    |
| Included in distribution  |   -       |   False   |   True        |   -       |  True                 |
| Incentivize               |   -       |   False   |   True        |   -       |  True                 |
| Updated reward percentage |   False   |   -       |   True        |   -       |  True                 |
| Updated reward receiver   |   False   |   -       |   True        |   -       |  True                 |

## Rewards calculation

In order to keep track of the rewards calculation for each user in an efficient way we applied the mechanisms of a [staking algorithm](https://www.rareskills.io/post/staking-algorithm). Rather than keeping track of the rewards for each user on a regular basis (let's say every x blocks or every x seconds), we update the internal states of the Gauge only when a user transaction is executed. In particular, each time that a user allocates votes (`Gauge#allocate`) or claim rewards (`Gauge#claimBackerRewards`), we update the reward data, by keeping track of:

- reward rate: it's the current rewards per token per seconds that we'll distribute;
- reward per token stored: it represents the accumulated value of the rewards per token;
- last update time: last time the state was updated;
- rewards per backer: the rewards the backer can claim;
- backer rewards per token paid per backer: it keeps track of the reward per token debt that each backer has when joining;
- reward missing: the reward rate multiplied by the time for which there are no votes allocated.

Now, let's check some scenarios: if a backer joined the system since the beginning, the reward calculation would be quite straightforward; we multiply the reward rate by the token amount allocated and by the time for which the user allocated and we've the rewards the Backer is entitled of.
But what happens if the Backer joined the system later? That's where the rewards per token paid comes into play. When the Backer allocates votes, we store a debt for the Backer corresponding to the current reward per token stored up until that time. From there on, the Backer will start accumulating rewards using the same reward rate, but when it's time to calculate the Backer reward, we multiply the Backer allocation by the difference between the current reward per token and the reward per token paid.

What happens to the rewards when the Builder doesn't have allocated votes? We keep track of the rewards missing and they're included in the calculation of the reward rate.

### Scenario 1: single Backer

A Gauge has 1000 tokens to be distributed to Backers over a 100 second cycle.\
The leftover is 0 because the reward rate is initially 0.\
The reward missing is initially 0.\
The reward per token stored is currently 0, because no time has passed.\
The reward rate at time 0 is 1000/100 = 10. 10 tokens will be distributed for each second.\
Last time update = 0.\

Alice allocates 100 votes at time 10.\
The reward missing is updated to 10 seconds (now - last time update) multiplied by reward rate 10 = 100\
The reward per token stored is 0, because the total allocation hasn't been updated yet.\
Last time update = 10.\
Alice reward per token paid is 0.\
Alice rewards is set to 0, because her allocation is updated at the end.\
Alice allocation is set to 100.\
Total allocation is updated to 100.\

Alice claims at time 90.\
The reward per token stored is updated; old value + ((current time - last time update) $\times$ reward rate)/total allocation ((90-10)$\times$10)/90 =~ 8.9.\
Last time update = 90.\
Alice rewards = Alice allocation $\times$ (reward per token stored - Alice reward per token paid) = 100 $\times$ 8.9 = 890.\
Alice per token paid is set to reward per token stored that is equal to 8.9.\
Token is transferred to Alice address.\
Alice reward is set to 0.\

### Scenario 2: multiple Backers

A Gauge has 1000 tokens to distribute to Backers over a cycle of 100 seconds.\
The leftover is 0 because the reward rate is initially 0.\
The reward per token stored is currently 0, because no time has passed.\
The reward missing is initially 0.\
The reward rate at time 0 is 1000/100 = 10. 10 tokens will be distributed for each second.\
Last time update = 0.\

Alice allocates 100 votes at time 10.\
The reward missing is updated to 10 seconds (now - last time update) multiplied by reward rate 10 = 100.\
The reward per token stored is 0, because the total allocation hasn't been updated yet.\
Alice reward per token paid is 0.\
Alice rewards is set to 0, because her allocation is updated at the end.\
Alice allocation so as the total allocation is updated.\
Last time update = 10.\

Bob allocates 50 votes at time 50.\
Reward missing isn't updated because total allocation is greater than 0.\
The reward per token stored is updated; old value + ((current time - last time update) $\times$ reward rate)/total allocation ((50-10)$\times$10)/100 = 4\
Last time update = 50.\
Bob rewards = Bob allocation $\times$ (reward per token stored - Bob reward per token paid) = 0 $\times$ 4 = 0\
Bob per token paid is set to reward per token stored that is equal to 4.\
Bob allocation is updated to 50.\
Total allocation is updated to 150.\

Bob claims at time 100\
The reward per token stored is updated; old value + ((current time - last time update) $\times$ reward rate)/total allocation ((100-50)$\times$10)/150 =~ 7.3.\
Last time update = 100.\
Bob rewards = old value + (Bob allocation $\times$ (reward per token stored - Bob reward per token paid)) = 50 $\times$ (7.3 - 4) = 165.\
Bob per token paid is set to reward per token stored that is equal to 7.3.\
Token is transferred to Bob address.\
Bob reward is set to 0.\

Alice claims at time 100.\
The reward per token stored is updated; old value + ((current time - last time update) $\times$ reward rate)/total allocation ((100-50)$\times$10)/150 =~ 7.3, no time has passed.\
Last time update = 100.\
Alice rewards = old value + (Alice allocation $\times$ (reward per token stored - Alice reward per token paid)) = 100 $\times$ (7.3 - 0) = 730.\
Alice per token paid is set to reward per token stored that is equal to 7.3.\
Token is transferred to Bob address.\
Alice reward is set to 0.\

## Builder incentivization

In order for the Builder to receive rewards, they need to capture Backers attention and votes. Beside the Builder network community value itself, and setting a compelling backers reward, Builders could also pump their rewards up on theirs Gauge contracts by means of `Gauge#incentivizeWithRewardToken()` and `Gauge#incentivizeWithCoinbase()`. Those rewards will be available only for the Backers who vote for the Builder on the ongoing cycle and they'll be undistinguishable from the rewards gained by votes.
