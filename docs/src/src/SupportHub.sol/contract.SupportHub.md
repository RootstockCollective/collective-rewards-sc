# SupportHub

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/c4d78ff998298ce9e3dffdd99f32430a3c5ed3af/src/SupportHub.sol)

**Inherits:** [Governed](/src/governance/Governed.sol/abstract.Governed.md)

Creates builder gauges, manages supporters supports and distribute rewards

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

address of the token rewarded to builder and supportrs

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

rewards to distribute per supporter emission [PREC]

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

### supporterTotalAllocation

total amount of stakingToken allocated by a supporter

```solidity
mapping(address supporter => uint256 allocation) public supporterTotalAllocation;
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

| Name                   | Type      | Description                                            |
| ---------------------- | --------- | ------------------------------------------------------ |
| `changeExecutor_`      | `address` | See Governed doc                                       |
| `rewardToken_`         | `address` | address of the token rewarded to builder and supportrs |
| `stakingToken_`        | `address` | address of the staking token for builder and supportrs |
| `builderGaugeFactory_` | `address` | address of the BuilderGaugeFactory contract            |
| `builderRegistry_`     | `address` | address of the BuilderRegistry contract                |

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

allocates supports for a builderGauge

_reverts if it is called during the distribution period_

```solidity
function allocate(BuilderGauge builderGauge_, uint256 allocation_) external notInDistributionPeriod;
```

**Parameters**

| Name            | Type           | Description                                                      |
| --------------- | -------------- | ---------------------------------------------------------------- |
| `builderGauge_` | `BuilderGauge` | address of the builderGauge where the supports will be allocated |
| `allocation_`   | `uint256`      | amount of supports to allocate                                   |

### allocateBatch

allocates supports for a batch of builderGauges

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

| Name             | Type             | Description                                                 |
| ---------------- | ---------------- | ----------------------------------------------------------- |
| `builderGauges_` | `BuilderGauge[]` | array of builderGauges where the supports will be allocated |
| `allocations_`   | `uint256[]`      | array of amount of supports to allocate                     |

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

claims supporter rewards from a batch of builderGauges

```solidity
function claimSponsorRewards(BuilderGauge[] memory builderGauges_) external;
```

**Parameters**

| Name             | Type             | Description                     |
| ---------------- | ---------------- | ------------------------------- |
| `builderGauges_` | `BuilderGauge[]` | array of builderGauges to claim |

### \_allocate

internal function used to allocate supports for a builderGauge or a batch of builderGauges

```solidity
function _allocate(
    BuilderGauge builderGauge_,
    uint256 allocation_,
    uint256 supporterTotalAllocation_,
    uint256 totalAllocation_
)
    internal
    returns (uint256 newSponsorTotalAllocation, uint256 newTotalAllocation);
```

**Parameters**

| Name                        | Type           | Description                                                      |
| --------------------------- | -------------- | ---------------------------------------------------------------- |
| `builderGauge_`             | `BuilderGauge` | address of the builderGauge where the supports will be allocated |
| `allocation_`               | `uint256`      | amount of supports to allocate                                   |
| `supporterTotalAllocation_` | `uint256`      | current supporter total allocation                               |
| `totalAllocation_`          | `uint256`      | current total allocation                                         |

**Returns**

| Name                        | Type      | Description                                         |
| --------------------------- | --------- | --------------------------------------------------- |
| `newSponsorTotalAllocation` | `uint256` | supporter total allocation after new the allocation |
| `newTotalAllocation`        | `uint256` | total allocation after the new allocation           |

### \_updateAllocation

internal function used to update allocation variables

_reverts if supporter doesn't have enough staking token balance_

```solidity
function _updateAllocation(
    address supporter_,
    uint256 newSponsorTotalAllocation_,
    uint256 newTotalAllocation_
)
    internal;
```

**Parameters**

| Name                         | Type      | Description                                         |
| ---------------------------- | --------- | --------------------------------------------------- |
| `supporter_`                 | `address` | address of the supporter who allocates              |
| `newSponsorTotalAllocation_` | `uint256` | supporter total allocation after new the allocation |
| `newTotalAllocation_`        | `uint256` | total allocation after the new allocation           |

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

### SupportAllocated

```solidity
event SupportAllocated(address indexed supporter_, address indexed builderGauge_, uint256 allocation_);
```

### RewardsReceived

```solidity
event RewardsReceived(address indexed sender_, uint256 amount_);
```

### RewardsDistributed

```solidity
event RewardsDistributed(address indexed sender_, address indexed builderGauge_, uint256 amount_);
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
