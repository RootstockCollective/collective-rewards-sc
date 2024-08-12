# SponsorsManager

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/8ea3c1d859ef1bd73929cdcdcbc3043c2c6fd603/src/SponsorsManager.sol)

**Inherits:** [Governed](/src/governance/Governed.sol/abstract.Governed.md)

Creates builder gauges, manages sponsors votes and distribute rewards

## State Variables

### MAX_DISTRIBUTIONS_PER_BATCH

```solidity
uint256 internal constant MAX_DISTRIBUTIONS_PER_BATCH = 20;
```

### stakingToken

address of the token used to stake

```solidity
IERC20 public stakingToken;
```

### rewardToken

address of the token rewarded to builder and voters

```solidity
IERC20 public rewardToken;
```

### builderGaugeFactory

builderGauge factory contract address

```solidity
BuilderGaugeFactory public builderGaugeFactory;
```

### builderRegistry

builder registry contract address

```solidity
BuilderRegistry public builderRegistry;
```

### totalAllocation

total allocation on all the builderGauges

```solidity
uint256 public totalAllocation;
```

### rewardsPerShare

rewards to distribute per sponsor emission [PREC]

```solidity
uint256 public rewardsPerShare;
```

### indexLastGaugeDistributed

index of tha last builderGauge distributed during a distribution period

```solidity
uint256 public indexLastGaugeDistributed;
```

### onDistributionPeriod

true if distribution period started. Allocations remain blocked until it finishes

```solidity
bool public onDistributionPeriod;
```

### builderToGauge

builderGauge contract for a builder

```solidity
mapping(address builder => BuilderGauge builderGauge) public builderToGauge;
```

### builderGauges

array of all the builderGauges created

```solidity
BuilderGauge[] public builderGauges;
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
    address rewardToken_,
    address stakingToken_,
    address builderGaugeFactory_,
    address builderRegistry_
)
    external
    initializer;
```

**Parameters**

| Name                   | Type      | Description                                         |
| ---------------------- | --------- | --------------------------------------------------- |
| `changeExecutor_`      | `address` | See Governed doc                                    |
| `rewardToken_`         | `address` | address of the token rewarded to builder and voters |
| `stakingToken_`        | `address` | address of the staking token for builder and voters |
| `builderGaugeFactory_` | `address` | address of the BuilderGaugeFactory contract         |
| `builderRegistry_`     | `address` | address of the BuilderRegistry contract             |

### createBuilderGauge

creates a new builder builderGauge for a builder

```solidity
function createBuilderGauge(address builder_)
    external
    onlyGovernorOrAuthorizedChanger
    returns (BuilderGauge builderGauge);
```

**Parameters**

| Name       | Type      | Description                               |
| ---------- | --------- | ----------------------------------------- |
| `builder_` | `address` | builder address who can claim the rewards |

**Returns**

| Name           | Type           | Description                   |
| -------------- | -------------- | ----------------------------- |
| `builderGauge` | `BuilderGauge` | builder builderGauge contract |

### allocate

allocates votes for a builderGauge

_reverts if it is called during the distribution period_

```solidity
function allocate(BuilderGauge builderGauge_, uint256 allocation_) external notInDistributionPeriod;
```

**Parameters**

| Name            | Type           | Description                                                   |
| --------------- | -------------- | ------------------------------------------------------------- |
| `builderGauge_` | `BuilderGauge` | address of the builderGauge where the votes will be allocated |
| `allocation_`   | `uint256`      | amount of votes to allocate                                   |

### allocateBatch

allocates votes for a batch of builderGauges

_reverts if it is called during the distribution period_

```solidity
function allocateBatch(
    BuilderGauge[] calldata builderGauges_,
    uint256[] calldata allocations_
)
    external
    notInDistributionPeriod;
```

**Parameters**

| Name             | Type             | Description                                              |
| ---------------- | ---------------- | -------------------------------------------------------- |
| `builderGauges_` | `BuilderGauge[]` | array of builderGauges where the votes will be allocated |
| `allocations_`   | `uint256[]`      | array of amount of votes to allocate                     |

### notifyRewardAmount

transfers reward tokens from the sender to be distributed to the builderGauges

_reverts if it is called during the distribution period_

```solidity
function notifyRewardAmount(uint256 amount_) external notInDistributionPeriod;
```

**Parameters**

| Name      | Type      | Description                           |
| --------- | --------- | ------------------------------------- |
| `amount_` | `uint256` | amount of reward tokens to distribute |

### startDistribution

starts the distribution period blocking all the allocations until all the builderGauges were distributed

_reverts if is called outside the distribution window reverts if it is called during the distribution period_

```solidity
function startDistribution() external onlyInDistributionWindow notInDistributionPeriod;
```

### distribute

distribute accumulated reward tokens to the builderGauges

_reverts if distribution period has not yet started This function is paginated and it finishes once all builderGauges
distribution are completed, ending the distribution period and voting restrictions._

```solidity
function distribute() public;
```

### claimSponsorRewards

claims sponsor rewards from a batch of builderGauges

```solidity
function claimSponsorRewards(BuilderGauge[] memory builderGauges_) external;
```

**Parameters**

| Name             | Type             | Description                     |
| ---------------- | ---------------- | ------------------------------- |
| `builderGauges_` | `BuilderGauge[]` | array of builderGauges to claim |

### \_allocate

internal function used to allocate votes for a builderGauge or a batch of builderGauges

```solidity
function _allocate(
    BuilderGauge builderGauge_,
    uint256 allocation_,
    uint256 sponsorTotalAllocation_,
    uint256 totalAllocation_
)
    internal
    returns (uint256 newSponsorTotalAllocation, uint256 newTotalAllocation);
```

**Parameters**

| Name                      | Type           | Description                                                   |
| ------------------------- | -------------- | ------------------------------------------------------------- |
| `builderGauge_`           | `BuilderGauge` | address of the builderGauge where the votes will be allocated |
| `allocation_`             | `uint256`      | amount of votes to allocate                                   |
| `sponsorTotalAllocation_` | `uint256`      | current sponsor total allocation                              |
| `totalAllocation_`        | `uint256`      | current total allocation                                      |

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

internal function used to distribute reward tokens to a builderGauge

```solidity
function _distribute(BuilderGauge builderGauge_, uint256 rewardsPerShare_, BuilderRegistry builderRegistry_) internal;
```

**Parameters**

| Name               | Type              | Description                               |
| ------------------ | ----------------- | ----------------------------------------- |
| `builderGauge_`    | `BuilderGauge`    | address of the builderGauge to distribute |
| `rewardsPerShare_` | `uint256`         | cached reward per share                   |
| `builderRegistry_` | `BuilderRegistry` | cached builder registry                   |

## Events

### BuilderGaugeCreated

```solidity
event BuilderGaugeCreated(address indexed builder_, address indexed builderGauge_, address creator_);
```

### NewAllocation

```solidity
event NewAllocation(address indexed sponsor_, address indexed builderGauge_, uint256 allocation_);
```

### NotifyReward

```solidity
event NotifyReward(address indexed sender_, uint256 amount_);
```

### DistributeReward

```solidity
event DistributeReward(address indexed sender_, address indexed builderGauge_, uint256 amount_);
```

## Errors

### UnequalLengths

```solidity
error UnequalLengths();
```

### BuilderGaugeExists

```solidity
error BuilderGaugeExists();
```

### BuilderGaugeDoesNotExist

```solidity
error BuilderGaugeDoesNotExist(address builder_);
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
