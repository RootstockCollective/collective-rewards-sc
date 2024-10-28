# SponsorsManager

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/b33b452f74e855019810b1ca7496e7536968bb3a/src/SponsorsManager.sol)

**Inherits:** [BuilderRegistry](/src/BuilderRegistry.sol/abstract.BuilderRegistry.md)

Creates gauges, manages sponsors votes and distribute rewards

## State Variables

### \_MAX_DISTRIBUTIONS_PER_BATCH

```solidity
uint256 internal constant _MAX_DISTRIBUTIONS_PER_BATCH = 20;
```

### stakingToken

address of the token used to stake

```solidity
IERC20 public stakingToken;
```

### rewardToken

address of the token rewarded to builder and voters

```solidity
address public rewardToken;
```

### totalPotentialReward

total potential reward

```solidity
uint256 public totalPotentialReward;
```

### tempTotalPotentialReward

on a paginated distribution we need to temporarily store the totalPotentialReward

```solidity
uint256 public tempTotalPotentialReward;
```

### rewardsERC20

ERC20 rewards to distribute [N]

```solidity
uint256 public rewardsERC20;
```

### rewardsCoinbase

Coinbase rewards to distribute [N]

```solidity
uint256 public rewardsCoinbase;
```

### indexLastGaugeDistributed

index of tha last gauge distributed during a distribution period

```solidity
uint256 public indexLastGaugeDistributed;
```

### \_periodFinish

timestamp end of current rewards period

```solidity
uint256 internal _periodFinish;
```

### onDistributionPeriod

true if distribution period started. Allocations remain blocked until it finishes

```solidity
bool public onDistributionPeriod;
```

### sponsorTotalAllocation

total amount of stakingToken allocated by a sponsor

```solidity
mapping(address sponsor => uint256 allocation) public sponsorTotalAllocation;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyInDistributionWindow

```solidity
modifier onlyInDistributionWindow();
```

### notInDistributionPeriod

```solidity
modifier notInDistributionPeriod();
```

### constructor

```solidity
constructor();
```

### initialize

contract initializer

```solidity
function initialize(
    address changeExecutor_,
    address kycApprover_,
    address rewardToken_,
    address stakingToken_,
    address gaugeFactory_,
    address rewardDistributor_,
    uint32 epochDuration_,
    uint24 epochStartOffset_,
    uint128 kickbackCooldown_
)
    external
    initializer;
```

**Parameters**

| Name                 | Type      | Description                                                                       |
| -------------------- | --------- | --------------------------------------------------------------------------------- |
| `changeExecutor_`    | `address` | See Governed doc                                                                  |
| `kycApprover_`       | `address` | See BuilderRegistry doc                                                           |
| `rewardToken_`       | `address` | address of the token rewarded to builder and voters                               |
| `stakingToken_`      | `address` | address of the staking token for builder and voters                               |
| `gaugeFactory_`      | `address` | address of the GaugeFactory contract                                              |
| `rewardDistributor_` | `address` | address of the rewardDistributor contract                                         |
| `epochDuration_`     | `uint32`  | epoch time duration                                                               |
| `epochStartOffset_`  | `uint24`  | offset to add to the first epoch, used to set an specific day to start the epochs |
| `kickbackCooldown_`  | `uint128` | time that must elapse for a new kickback from a builder to be applied             |

### allocate

allocates votes for a gauge

_reverts if it is called during the distribution period reverts if gauge does not have a builder associated_

```solidity
function allocate(Gauge gauge_, uint256 allocation_) external notInDistributionPeriod;
```

**Parameters**

| Name          | Type      | Description                                            |
| ------------- | --------- | ------------------------------------------------------ |
| `gauge_`      | `Gauge`   | address of the gauge where the votes will be allocated |
| `allocation_` | `uint256` | amount of votes to allocate                            |

### allocateBatch

allocates votes for a batch of gauges

_reverts if it is called during the distribution period reverts if gauge does not have a builder associated_

```solidity
function allocateBatch(Gauge[] calldata gauges_, uint256[] calldata allocations_) external notInDistributionPeriod;
```

**Parameters**

| Name           | Type        | Description                                       |
| -------------- | ----------- | ------------------------------------------------- |
| `gauges_`      | `Gauge[]`   | array of gauges where the votes will be allocated |
| `allocations_` | `uint256[]` | array of amount of votes to allocate              |

### notifyRewardAmount

transfers reward tokens from the sender to be distributed to the gauges

_reverts if it is called during the distribution period_

```solidity
function notifyRewardAmount(uint256 amount_) external payable notInDistributionPeriod;
```

### startDistribution

starts the distribution period blocking all the allocations until all the gauges were distributed

_reverts if is called outside the distribution window reverts if it is called during the distribution period_

```solidity
function startDistribution() external onlyInDistributionWindow notInDistributionPeriod;
```

### distribute

distribute accumulated reward tokens to the gauges

_reverts if distribution period has not yet started This function is paginated and it finishes once all gauges
distribution are completed, ending the distribution period and voting restrictions._

```solidity
function distribute() public;
```

### claimSponsorRewards

claims sponsor rewards from a batch of gauges

```solidity
function claimSponsorRewards(Gauge[] memory gauges_) external;
```

**Parameters**

| Name      | Type      | Description              |
| --------- | --------- | ------------------------ |
| `gauges_` | `Gauge[]` | array of gauges to claim |

### periodFinish

returns timestamp end of current rewards period If it is called by a halted gauge returns the timestamp of the last
period distributed This is important because unclaimed rewards must stop accumulating rewards and halted gauges are not
updated on the distribution anymore

```solidity
function periodFinish() external view returns (uint256);
```

### \_allocate

internal function used to allocate votes for a gauge or a batch of gauges

```solidity
function _allocate(
    Gauge gauge_,
    uint256 allocation_,
    uint256 sponsorTotalAllocation_,
    uint256 totalPotentialReward_,
    uint256 timeUntilNextEpoch_
)
    internal
    returns (uint256 newSponsorTotalAllocation_, uint256 newTotalPotentialReward_);
```

**Parameters**

| Name                      | Type      | Description                                            |
| ------------------------- | --------- | ------------------------------------------------------ |
| `gauge_`                  | `Gauge`   | address of the gauge where the votes will be allocated |
| `allocation_`             | `uint256` | amount of votes to allocate                            |
| `sponsorTotalAllocation_` | `uint256` | current sponsor total allocation                       |
| `totalPotentialReward_`   | `uint256` | current total potential reward                         |
| `timeUntilNextEpoch_`     | `uint256` | time until next epoch                                  |

**Returns**

| Name                         | Type      | Description                                       |
| ---------------------------- | --------- | ------------------------------------------------- |
| `newSponsorTotalAllocation_` | `uint256` | sponsor total allocation after new the allocation |
| `newTotalPotentialReward_`   | `uint256` | total potential reward after the new allocation   |

### \_updateAllocation

internal function used to update allocation variables

_reverts if sponsor doesn't have enough staking token balance_

```solidity
function _updateAllocation(
    address sponsor_,
    uint256 newSponsorTotalAllocation_,
    uint256 newTotalPotentialReward_
)
    internal;
```

**Parameters**

| Name                         | Type      | Description                                       |
| ---------------------------- | --------- | ------------------------------------------------- |
| `sponsor_`                   | `address` | address of the sponsor who allocates              |
| `newSponsorTotalAllocation_` | `uint256` | sponsor total allocation after new the allocation |
| `newTotalPotentialReward_`   | `uint256` | total potential reward after the new allocation   |

### \_distribute

internal function used to distribute reward tokens to a gauge

```solidity
function _distribute(
    Gauge gauge_,
    uint256 rewardsERC20_,
    uint256 rewardsCoinbase_,
    uint256 totalPotentialReward_,
    uint256 periodFinish_,
    uint256 epochStart_,
    uint256 epochDuration_
)
    internal
    returns (uint256);
```

**Parameters**

| Name                    | Type      | Description                        |
| ----------------------- | --------- | ---------------------------------- |
| `gauge_`                | `Gauge`   | address of the gauge to distribute |
| `rewardsERC20_`         | `uint256` | ERC20 rewards to distribute        |
| `rewardsCoinbase_`      | `uint256` | Coinbase rewards to distribute     |
| `totalPotentialReward_` | `uint256` | cached total potential reward      |
| `periodFinish_`         | `uint256` | cached period finish               |
| `epochStart_`           | `uint256` | cached epoch start timestamp       |
| `epochDuration_`        | `uint256` | cached epoch duration              |

**Returns**

| Name     | Type      | Description                                                                   |
| -------- | --------- | ----------------------------------------------------------------------------- |
| `<none>` | `uint256` | newGaugeRewardShares\_ new gauge rewardShares, updated after the distribution |

### \_haltGaugeShares

removes halted gauge shares to not be accounted on the distribution anymore

_reverts if it is executed in distribution period because changing the totalPotentialReward produce a miscalculation of
rewards_

```solidity
function _haltGaugeShares(Gauge gauge_) internal override notInDistributionPeriod;
```

**Parameters**

| Name     | Type    | Description                 |
| -------- | ------- | --------------------------- |
| `gauge_` | `Gauge` | gauge contract to be halted |

### \_resumeGaugeShares

adds resumed gauge shares to be accounted on the distribution again

_reverts if it is executed in distribution period because changing the totalPotentialReward produce a miscalculation of
rewards_

```solidity
function _resumeGaugeShares(Gauge gauge_) internal override notInDistributionPeriod;
```

**Parameters**

| Name     | Type    | Description                  |
| -------- | ------- | ---------------------------- |
| `gauge_` | `Gauge` | gauge contract to be resumed |

## Events

### NewAllocation

```solidity
event NewAllocation(address indexed sponsor_, address indexed gauge_, uint256 allocation_);
```

### NotifyReward

```solidity
event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
```

### RewardDistributionStarted

```solidity
event RewardDistributionStarted(address indexed sender_);
```

### RewardDistributed

```solidity
event RewardDistributed(address indexed sender_);
```

### RewardDistributionFinished

```solidity
event RewardDistributionFinished(address indexed sender_);
```

## Errors

### UnequalLengths

```solidity
error UnequalLengths();
```

### NotEnoughStaking

```solidity
error NotEnoughStaking();
```

### OnlyInDistributionWindow

```solidity
error OnlyInDistributionWindow();
```

### NotInDistributionPeriod

```solidity
error NotInDistributionPeriod();
```

### DistributionPeriodDidNotStart

```solidity
error DistributionPeriodDidNotStart();
```

### GaugeDoesNotExist

```solidity
error GaugeDoesNotExist();
```

### BeforeDistribution

```solidity
error BeforeDistribution();
```
