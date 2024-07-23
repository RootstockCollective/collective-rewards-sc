# SponsorsManager

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/593a4330380586d483b11df54f093ffbc3b3a65a/src/SponsorsManager.sol)

**Inherits:** [Governed](/src/governance/Governed.sol/abstract.Governed.md)

## State Variables

### MAX_DISTRIBUTIONS_PER_BATCH

```solidity
uint256 internal constant MAX_DISTRIBUTIONS_PER_BATCH = 20;
```

### stakingToken

address of the token used to stake

```solidity
IERC20 public immutable stakingToken;
```

### rewardToken

address of the token rewarded to builder and voters

```solidity
IERC20 public immutable rewardToken;
```

### gaugeFactory

gauge factory contract address

```solidity
GaugeFactory public immutable gaugeFactory;
```

### totalAllocation

total allocation on all the gauges

```solidity
uint256 public totalAllocation;
```

### rewardsPerShare

rewards to distribute per sponsor emission [PREC]

```solidity
uint256 public rewardsPerShare;
```

### indexLastGaugeDistributed

index of tha last gauge distributed during a distribution period

```solidity
uint256 public indexLastGaugeDistributed;
```

### onDistributionPeriod

true if distribution period started. Allocations remain blocked until it finishes

```solidity
bool public onDistributionPeriod;
```

### builderToGauge

gauge contract for a builder

```solidity
mapping(address builder => Gauge gauge) public builderToGauge;
```

### gauges

array of all the gauges created

```solidity
Gauge[] public gauges;
```

### sponsorTotalAllocation

total amount of stakingToken allocated by a sponsor

```solidity
mapping(address sponsor => uint256 allocation) public sponsorTotalAllocation;
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
constructor(
    address governor_,
    address changeExecutor_,
    address rewardToken_,
    address stakingToken_,
    address gaugeFactory_
)
    Governed(governor_, changeExecutor_);
```

### createGauge

creates a new gauge for a builder

```solidity
function createGauge(address builder_) external onlyGovernorOrAuthorizedChanger returns (Gauge gauge);
```

**Parameters**

| Name       | Type      | Description                               |
| ---------- | --------- | ----------------------------------------- |
| `builder_` | `address` | builder address who can claim the rewards |

**Returns**

| Name    | Type    | Description    |
| ------- | ------- | -------------- |
| `gauge` | `Gauge` | gauge contract |

### allocate

allocates votes for a gauge

_reverts if it is called during the distribution period_

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

_reverts if it is called during the distribution period_

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
function notifyRewardAmount(uint256 amount_) external notInDistributionPeriod;
```

**Parameters**

| Name      | Type      | Description                           |
| --------- | --------- | ------------------------------------- |
| `amount_` | `uint256` | amount of reward tokens to distribute |

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

### claimRewards

claims rewards form a batch of gauges

```solidity
function claimRewards(Gauge[] memory gauges_) external;
```

**Parameters**

| Name      | Type      | Description              |
| --------- | --------- | ------------------------ |
| `gauges_` | `Gauge[]` | array of gauges to claim |

### \_allocate

internal function used to allocate votes for a gauge or a batch of gauges

```solidity
function _allocate(
    Gauge gauge_,
    uint256 allocation_,
    uint256 sponsorTotalAllocation_,
    uint256 totalAllocation_
)
    internal
    returns (uint256 newSponsorTotalAllocation, uint256 newTotalAllocation);
```

**Parameters**

| Name                      | Type      | Description                                            |
| ------------------------- | --------- | ------------------------------------------------------ |
| `gauge_`                  | `Gauge`   | address of the gauge where the votes will be allocated |
| `allocation_`             | `uint256` | amount of votes to allocate                            |
| `sponsorTotalAllocation_` | `uint256` | current sponsor total allocation                       |
| `totalAllocation_`        | `uint256` | current total allocation                               |

**Returns**

| Name                        | Type      | Description                                       |
| --------------------------- | --------- | ------------------------------------------------- |
| `newSponsorTotalAllocation` | `uint256` | sponsor total allocation after new the allocation |
| `newTotalAllocation`        | `uint256` | total allocation after the new allocation         |

### \_updateAllocation

internal function used to update allocation variables

_reverts if sponsor doesn't have enough staking token balance_

```solidity
function _updateAllocation(
    address sponsor_,
    uint256 newSponsorTotalAllocation_,
    uint256 newTotalAllocation_
)
    internal;
```

**Parameters**

| Name                         | Type      | Description                                       |
| ---------------------------- | --------- | ------------------------------------------------- |
| `sponsor_`                   | `address` | address of the sponsor who allocates              |
| `newSponsorTotalAllocation_` | `uint256` | sponsor total allocation after new the allocation |
| `newTotalAllocation_`        | `uint256` | total allocation after the new allocation         |

### \_distribute

internal function used to distribute reward tokens to a gauge

```solidity
function _distribute(Gauge gauge_) internal;
```

**Parameters**

| Name     | Type    | Description                        |
| -------- | ------- | ---------------------------------- |
| `gauge_` | `Gauge` | address of the gauge to distribute |

## Events

### GaugeCreated

```solidity
event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
```

### NewAllocation

```solidity
event NewAllocation(address indexed sponsor_, address indexed gauge_, uint256 allocation_);
```

### NotifyReward

```solidity
event NotifyReward(address indexed sender_, uint256 amount_);
```

### DistributeReward

```solidity
event DistributeReward(address indexed sender_, address indexed gauge_, uint256 amount_);
```

## Errors

### UnequalLengths

```solidity
error UnequalLengths();
```

### GaugeExists

```solidity
error GaugeExists();
```

### GaugeDoesNotExist

```solidity
error GaugeDoesNotExist(address builder_);
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
