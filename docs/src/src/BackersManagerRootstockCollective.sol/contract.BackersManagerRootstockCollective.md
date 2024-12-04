# BackersManagerRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/6d0eca4e2c61e833bcb70c54d8668e5644ba180e/src/BackersManagerRootstockCollective.sol)

**Inherits:**
[ICollectiveRewardsCheckRootstockCollective](/src/interfaces/ICollectiveRewardsCheckRootstockCollective.sol/interface.ICollectiveRewardsCheckRootstockCollective.md),
[BuilderRegistryRootstockCollective](/src/BuilderRegistryRootstockCollective.sol/abstract.BuilderRegistryRootstockCollective.md)

Creates gauges, manages backers votes and distribute rewards

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

### backerTotalAllocation

total amount of stakingToken allocated by a backer

```solidity
mapping(address backer => uint256 allocation) public backerTotalAllocation;
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
    IGovernanceManagerRootstockCollective governanceManager_,
    address rewardToken_,
    address stakingToken_,
    address gaugeFactory_,
    address rewardDistributor_,
    uint32 cycleDuration_,
    uint24 cycleStartOffset_,
    uint32 distributionDuration_,
    uint128 rewardPercentageCooldown_
)
    external
    initializer;
```

**Parameters**

| Name                        | Type                                    | Description                                                                       |
| --------------------------- | --------------------------------------- | --------------------------------------------------------------------------------- |
| `governanceManager_`        | `IGovernanceManagerRootstockCollective` | contract with permissioned roles                                                  |
| `rewardToken_`              | `address`                               | address of the token rewarded to builder and voters                               |
| `stakingToken_`             | `address`                               | address of the staking token for builder and voters                               |
| `gaugeFactory_`             | `address`                               | address of the GaugeFactoryRootstockCollective contract                           |
| `rewardDistributor_`        | `address`                               | address of the rewardDistributor contract                                         |
| `cycleDuration_`            | `uint32`                                | Collective Rewards cycle time duration                                            |
| `cycleStartOffset_`         | `uint24`                                | offset to add to the first cycle, used to set an specific day to start the cycles |
| `distributionDuration_`     | `uint32`                                | duration of the distribution window                                               |
| `rewardPercentageCooldown_` | `uint128`                               | time that must elapse for a new reward percentage from a builder to be applied    |

### supportsInterface

_See
[IERC165-supportsInterface](/node_modules/forge-std/src/mocks/MockERC721.sol/contract.MockERC721.md#supportsinterface)._

```solidity
function supportsInterface(bytes4 interfaceId_) public view override returns (bool);
```

### canWithdraw

returns true if can withdraw, remaining balance should exceed the current allocation

_user token balance should already account for the update, meaning the check is applied AFTER the withdraw accounting
has become effective._

```solidity
function canWithdraw(address targetAddress_, uint256) external view returns (bool);
```

**Parameters**

| Name             | Type      | Description                                                                                                              |
| ---------------- | --------- | ------------------------------------------------------------------------------------------------------------------------ |
| `targetAddress_` | `address` | address who wants to withdraw stakingToken param value\_ amount of stakingToken to withdraw, not used on current version |
| `<none>`         | `uint256` |                                                                                                                          |

### allocate

allocates votes for a gauge

_reverts if it is called during the distribution period reverts if gauge does not have a builder associated_

```solidity
function allocate(GaugeRootstockCollective gauge_, uint256 allocation_) external notInDistributionPeriod;
```

**Parameters**

| Name          | Type                       | Description                                            |
| ------------- | -------------------------- | ------------------------------------------------------ |
| `gauge_`      | `GaugeRootstockCollective` | address of the gauge where the votes will be allocated |
| `allocation_` | `uint256`                  | amount of votes to allocate                            |

### allocateBatch

allocates votes for a batch of gauges

_reverts if it is called during the distribution period reverts if gauge does not have a builder associated_

```solidity
function allocateBatch(
    GaugeRootstockCollective[] calldata gauges_,
    uint256[] calldata allocations_
)
    external
    notInDistributionPeriod;
```

**Parameters**

| Name           | Type                         | Description                                       |
| -------------- | ---------------------------- | ------------------------------------------------- |
| `gauges_`      | `GaugeRootstockCollective[]` | array of gauges where the votes will be allocated |
| `allocations_` | `uint256[]`                  | array of amount of votes to allocate              |

### notifyRewardAmount

transfers reward tokens from the sender to be distributed to the gauges

_reverts if it is called during the distribution period reverts if there are no gauges available for the distribution_

```solidity
function notifyRewardAmount(uint256 amount_) external payable notInDistributionPeriod;
```

### startDistribution

starts the distribution period blocking all the allocations until all the gauges were distributed

_reverts if is called outside the distribution window reverts if it is called during the distribution period_

```solidity
function startDistribution() external onlyInDistributionWindow notInDistributionPeriod returns (bool finished_);
```

**Returns**

| Name        | Type   | Description                       |
| ----------- | ------ | --------------------------------- |
| `finished_` | `bool` | true if distribution has finished |

### distribute

continues pagination to distribute accumulated reward tokens to the gauges

_reverts if distribution period has not yet started This function is paginated and it finishes once all gauges
distribution are completed, ending the distribution period and voting restrictions._

```solidity
function distribute() external returns (bool finished_);
```

**Returns**

| Name        | Type   | Description                       |
| ----------- | ------ | --------------------------------- |
| `finished_` | `bool` | true if distribution has finished |

### claimBackerRewards

claims backer rewards from a batch of gauges

```solidity
function claimBackerRewards(GaugeRootstockCollective[] memory gauges_) external;
```

**Parameters**

| Name      | Type                         | Description              |
| --------- | ---------------------------- | ------------------------ |
| `gauges_` | `GaugeRootstockCollective[]` | array of gauges to claim |

### claimBackerRewards

claims backer rewards from a batch of gauges

```solidity
function claimBackerRewards(address rewardToken_, GaugeRootstockCollective[] memory gauges_) external;
```

**Parameters**

| Name           | Type                         | Description                                                                                                         |
| -------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `rewardToken_` | `address`                    | address of the token rewarded address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address |
| `gauges_`      | `GaugeRootstockCollective[]` | array of gauges to claim                                                                                            |

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
    GaugeRootstockCollective gauge_,
    uint256 allocation_,
    uint256 backerTotalAllocation_,
    uint256 totalPotentialReward_,
    uint256 timeUntilNextCycle_
)
    internal
    returns (uint256 newbackerTotalAllocation_, uint256 newTotalPotentialReward_);
```

**Parameters**

| Name                     | Type                       | Description                                            |
| ------------------------ | -------------------------- | ------------------------------------------------------ |
| `gauge_`                 | `GaugeRootstockCollective` | address of the gauge where the votes will be allocated |
| `allocation_`            | `uint256`                  | amount of votes to allocate                            |
| `backerTotalAllocation_` | `uint256`                  | current backer total allocation                        |
| `totalPotentialReward_`  | `uint256`                  | current total potential reward                         |
| `timeUntilNextCycle_`    | `uint256`                  | time until next cycle                                  |

**Returns**

| Name                        | Type      | Description                                      |
| --------------------------- | --------- | ------------------------------------------------ |
| `newbackerTotalAllocation_` | `uint256` | backer total allocation after new the allocation |
| `newTotalPotentialReward_`  | `uint256` | total potential reward after the new allocation  |

### \_updateAllocation

internal function used to update allocation variables

_reverts if backer doesn't have enough staking token balance_

```solidity
function _updateAllocation(
    address backer_,
    uint256 newbackerTotalAllocation_,
    uint256 newTotalPotentialReward_
)
    internal;
```

**Parameters**

| Name                        | Type      | Description                                      |
| --------------------------- | --------- | ------------------------------------------------ |
| `backer_`                   | `address` | address of the backer who allocates              |
| `newbackerTotalAllocation_` | `uint256` | backer total allocation after new the allocation |
| `newTotalPotentialReward_`  | `uint256` | total potential reward after the new allocation  |

### \_distribute

distribute accumulated reward tokens to the gauges

_reverts if distribution period has not yet started This function is paginated and it finishes once all gauges
distribution are completed, ending the distribution period and voting restrictions._

```solidity
function _distribute() internal returns (bool);
```

**Returns**

| Name     | Type   | Description                       |
| -------- | ------ | --------------------------------- |
| `<none>` | `bool` | true if distribution has finished |

### \_gaugeDistribute

internal function used to distribute reward tokens to a gauge

```solidity
function _gaugeDistribute(
    GaugeRootstockCollective gauge_,
    uint256 rewardsERC20_,
    uint256 rewardsCoinbase_,
    uint256 totalPotentialReward_,
    uint256 periodFinish_,
    uint256 cycleStart_,
    uint256 cycleDuration_
)
    internal
    returns (uint256);
```

**Parameters**

| Name                    | Type                       | Description                        |
| ----------------------- | -------------------------- | ---------------------------------- |
| `gauge_`                | `GaugeRootstockCollective` | address of the gauge to distribute |
| `rewardsERC20_`         | `uint256`                  | ERC20 rewards to distribute        |
| `rewardsCoinbase_`      | `uint256`                  | Coinbase rewards to distribute     |
| `totalPotentialReward_` | `uint256`                  | cached total potential reward      |
| `periodFinish_`         | `uint256`                  | cached period finish               |
| `cycleStart_`           | `uint256`                  | cached cycle start timestamp       |
| `cycleDuration_`        | `uint256`                  | cached cycle duration              |

**Returns**

| Name     | Type      | Description                                                                   |
| -------- | --------- | ----------------------------------------------------------------------------- |
| `<none>` | `uint256` | newGaugeRewardShares\_ new gauge rewardShares, updated after the distribution |

### \_rewardTokenApprove

approves rewardTokens to a given gauge

_give full allowance when it is community approved and remove it when it is dewhitelisted_

```solidity
function _rewardTokenApprove(address gauge_, uint256 value_) internal override;
```

**Parameters**

| Name     | Type      | Description                            |
| -------- | --------- | -------------------------------------- |
| `gauge_` | `address` | gauge contract to approve rewardTokens |
| `value_` | `uint256` | amount of rewardTokens to approve      |

### \_haltGaugeShares

removes halted gauge shares to not be accounted on the distribution anymore

_reverts if it is executed in distribution period because changing the totalPotentialReward produce a miscalculation of
rewards_

```solidity
function _haltGaugeShares(GaugeRootstockCollective gauge_) internal override notInDistributionPeriod;
```

**Parameters**

| Name     | Type                       | Description                 |
| -------- | -------------------------- | --------------------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract to be halted |

### \_resumeGaugeShares

adds resumed gauge shares to be accounted on the distribution again

_reverts if it is executed in distribution period because changing the totalPotentialReward produce a miscalculation of
rewards_

```solidity
function _resumeGaugeShares(GaugeRootstockCollective gauge_) internal override notInDistributionPeriod;
```

**Parameters**

| Name     | Type                       | Description                  |
| -------- | -------------------------- | ---------------------------- |
| `gauge_` | `GaugeRootstockCollective` | gauge contract to be resumed |

## Events

### NewAllocation

```solidity
event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
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

### BeforeDistribution

```solidity
error BeforeDistribution();
```

### PositiveAllocationOnHaltedGauge

```solidity
error PositiveAllocationOnHaltedGauge();
```

### NoGaugesForDistribution

```solidity
error NoGaugesForDistribution();
```
