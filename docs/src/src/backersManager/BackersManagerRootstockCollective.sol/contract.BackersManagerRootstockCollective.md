# BackersManagerRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/f946f53322702b68bdb68a4c01ed6360683360e6/src/backersManager/BackersManagerRootstockCollective.sol)

**Inherits:**
[CycleTimeKeeperRootstockCollective](/src/backersManager/CycleTimeKeeperRootstockCollective.sol/abstract.CycleTimeKeeperRootstockCollective.md), [ICollectiveRewardsCheckRootstockCollective](/src/interfaces/ICollectiveRewardsCheckRootstockCollective.sol/interface.ICollectiveRewardsCheckRootstockCollective.md), ERC165Upgradeable

Creates gauges, manages backers votes and distribute rewards


## State Variables
### __gapUpgrade
gap to preserve storage layout after removing builder registry from the inheritance tree


```solidity
uint256[64] private __gapUpgrade;
```


### stakingToken
address of the token used to stake


```solidity
IERC20 public stakingToken;
```


### rifToken
address of the token rewarded to builder and voters


```solidity
address public rifToken;
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


### rewardsRif
ERC20 rewards to distribute [N]


```solidity
uint256 public rewardsRif;
```


### rewardsNative
Native rewards to distribute [N]


```solidity
uint256 public rewardsNative;
```


### indexLastGaugeDistributed
index of tha last gauge distributed during a distribution period


```solidity
uint256 public indexLastGaugeDistributed;
```


### _periodFinish
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


### builderRegistry
address of the builder registry contract


```solidity
BuilderRegistryRootstockCollective public builderRegistry;
```


### rewardsOptedOut
Tracks whether a backer has opted out from rewards, disabling the allocation to builders if true


```solidity
mapping(address backer => bool hasOptedOut) public rewardsOptedOut;
```


### maxDistributionsPerBatch
maximum allowed distributions per batch


```solidity
uint256 public maxDistributionsPerBatch;
```


### rewardsUsdrif
ERC20 rewards to distribute [N]


```solidity
uint256 public rewardsUsdrif;
```


### usdrifToken
address of the USDRIF token rewarded to builder and voters


```solidity
address public usdrifToken;
```


### __gap
*This empty reserved space is put in place to allow future versions to add new
variables without shifting down storage in the inheritance chain.
See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps*


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

### onlyBackerOrKycApprover


```solidity
modifier onlyBackerOrKycApprover(address account_);
```

### onlyBuilderRegistry


```solidity
modifier onlyBuilderRegistry();
```

### onlyOptedInBacker


```solidity
modifier onlyOptedInBacker();
```

### onlyConfigurator


```solidity
modifier onlyConfigurator();
```

### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

contract initializer

For more info on supported tokens, see:
https://github.com/RootstockCollective/collective-rewards-sc/blob/main/README.md#Reward-token


```solidity
function initialize(
    IGovernanceManagerRootstockCollective governanceManager_,
    address rifToken_,
    address stakingToken_,
    uint32 cycleDuration_,
    uint24 cycleStartOffset_,
    uint32 distributionDuration_
)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`governanceManager_`|`IGovernanceManagerRootstockCollective`|contract with permissioned roles|
|`rifToken_`|`address`|address of the token rewarded to builder and voters. Only tokens that adhere to the ERC-20 standard are supported.|
|`stakingToken_`|`address`|address of the staking token for builder and voters|
|`cycleDuration_`|`uint32`|Collective Rewards cycle time duration|
|`cycleStartOffset_`|`uint24`|offset to add to the first cycle, used to set an specific day to start the cycles|
|`distributionDuration_`|`uint32`|duration of the distribution window|


### initializeBuilderRegistry

builder registry contract initializer


```solidity
function initializeBuilderRegistry(BuilderRegistryRootstockCollective builderRegistry_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builderRegistry_`|`BuilderRegistryRootstockCollective`|address of the builder registry contract|


### initializeV3

contract version 3 initializer


```solidity
function initializeV3(uint256 maxDistributionsPerBatch_, address usdrifToken_) external reinitializer(3);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxDistributionsPerBatch_`|`uint256`|maximum number of distributions allowed per batch|
|`usdrifToken_`|`address`|address of the USDRIF reward token|


### supportsInterface

*See [IERC165-supportsInterface](/node_modules/forge-std/src/interfaces/IERC165.sol/interface.IERC165.md#supportsinterface).*


```solidity
function supportsInterface(bytes4 interfaceId_) public view override returns (bool);
```

### canWithdraw

returns true if can withdraw, remaining balance should exceed the current allocation

*user token balance should already account for the update, meaning the check
is applied AFTER the withdraw accounting has become effective.*


```solidity
function canWithdraw(address targetAddress_, uint256) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targetAddress_`|`address`|address who wants to withdraw stakingToken param value_ amount of stakingToken to withdraw, not used on current version|
|`<none>`|`uint256`||


### allocate

allocates votes for a gauge

*reverts if it is called during the distribution period
reverts if gauge does not have a builder associated*


```solidity
function allocate(
    GaugeRootstockCollective gauge_,
    uint256 allocation_
)
    external
    notInDistributionPeriod
    onlyOptedInBacker;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|address of the gauge where the votes will be allocated|
|`allocation_`|`uint256`|amount of votes to allocate|


### allocateBatch

allocates votes for a batch of gauges

*reverts if it is called during the distribution period
reverts if gauge does not have a builder associated*


```solidity
function allocateBatch(
    GaugeRootstockCollective[] calldata gauges_,
    uint256[] calldata allocations_
)
    external
    notInDistributionPeriod
    onlyOptedInBacker;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauges_`|`GaugeRootstockCollective[]`|array of gauges where the votes will be allocated|
|`allocations_`|`uint256[]`|array of amount of votes to allocate|


### notifyRewardAmount

transfers reward tokens from the sender to be distributed to the gauges

*reverts if it is called during the distribution period
reverts if there are no gauges available for the distribution*


```solidity
function notifyRewardAmount(uint256 amountRif_, uint256 amountUsdrif_) external payable notInDistributionPeriod;
```

### startDistribution

starts the distribution period blocking all the allocations
until all the gauges were distributed

*reverts if is called outside the distribution window
reverts if it is called during the distribution period*


```solidity
function startDistribution() external onlyInDistributionWindow notInDistributionPeriod returns (bool finished_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`finished_`|`bool`|true if distribution has finished|


### distribute

continues pagination to distribute accumulated reward tokens to the gauges

*reverts if distribution period has not yet started
This function is paginated and it finishes once all gauges distribution are completed,
ending the distribution period and voting restrictions.*


```solidity
function distribute() external returns (bool finished_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`finished_`|`bool`|true if distribution has finished|


### claimBackerRewards

claims backer rewards from a batch of gauges


```solidity
function claimBackerRewards(GaugeRootstockCollective[] memory gauges_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauges_`|`GaugeRootstockCollective[]`|array of gauges to claim|


### claimBackerRewards

claims backer rewards from a batch of gauges


```solidity
function claimBackerRewards(address rifToken_, GaugeRootstockCollective[] memory gauges_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rifToken_`|`address`|address of the token rewarded address(uint160(uint256(keccak256("NATIVE_ADDRESS")))) is used for native address|
|`gauges_`|`GaugeRootstockCollective[]`|array of gauges to claim|


### periodFinish

returns timestamp end of current rewards period
If it is called by a halted gauge returns the timestamp of the last period distributed
This is important because unclaimed rewards must stop accumulating rewards and halted gauges
are not updated on the distribution anymore


```solidity
function periodFinish() external view returns (uint256);
```

### optOutRewards

Allows a backer to opt out of rewards, preventing them from allocating votes
and claiming rewards in the future.
This action can only be performed by the backer themselves or by the foundation.


```solidity
function optOutRewards(address backer_) external onlyBackerOrKycApprover(backer_);
```

### optInRewards

Enables a backer to opt in for rewards, allowing them to allocate votes and claim rewards.
Backers are opted in by default; only those who have opted out can choose to opt in again.
This action can be performed only by the backer themselves or by the foundation.


```solidity
function optInRewards(address backer_) external onlyBackerOrKycApprover(backer_);
```

### updateMaxDistributionsPerBatch

Updates the maximum number of distributions allowed per batch.

*reverts if not called by the upgrader*

*permission will be delegated from upgrader to different role once the GovernanceManagerRootStockCollective
contract is upgraded*


```solidity
function updateMaxDistributionsPerBatch(uint256 maxDistributionsPerBatch_) external onlyConfigurator;
```

### _allocate

internal function used to allocate votes for a gauge or a batch of gauges


```solidity
function _allocate(
    GaugeRootstockCollective gauge_,
    uint256 allocation_,
    uint256 backerTotalAllocation_,
    uint256 totalPotentialReward_,
    uint256 timeUntilNextCycle_,
    BuilderRegistryRootstockCollective builderRegistry_
)
    internal
    returns (uint256 newBackerTotalAllocation_, uint256 newTotalPotentialReward_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|address of the gauge where the votes will be allocated|
|`allocation_`|`uint256`|amount of votes to allocate|
|`backerTotalAllocation_`|`uint256`|current backer total allocation|
|`totalPotentialReward_`|`uint256`|current total potential reward|
|`timeUntilNextCycle_`|`uint256`|time until next cycle|
|`builderRegistry_`|`BuilderRegistryRootstockCollective`|address of the builder registry contract, passed as parameter to avoid storage reads|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newBackerTotalAllocation_`|`uint256`|backer total allocation after new the allocation|
|`newTotalPotentialReward_`|`uint256`|total potential reward  after the new allocation|


### _updateAllocation

internal function used to update allocation variables

*reverts if backer doesn't have enough staking token balance*


```solidity
function _updateAllocation(
    address backer_,
    uint256 newBackerTotalAllocation_,
    uint256 newTotalPotentialReward_
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backer_`|`address`|address of the backer who allocates|
|`newBackerTotalAllocation_`|`uint256`|backer total allocation after new the allocation|
|`newTotalPotentialReward_`|`uint256`|total potential reward after the new allocation|


### _distribute

distribute accumulated reward tokens to the gauges
This function is paginated and it finishes once all gauges distribution are completed,
ending the distribution period and voting restrictions.


```solidity
function _distribute() internal returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if distribution has finished|


### _finishDistribution


```solidity
function _finishDistribution() internal;
```

### _gaugeDistribute

internal function used to distribute reward tokens to a gauge


```solidity
function _gaugeDistribute(
    GaugeRootstockCollective gauge_,
    uint256 rewardsRif_,
    uint256 rewardsUsdrif_,
    uint256 rewardsNative_,
    uint256 totalPotentialReward_,
    uint256 periodFinish_,
    uint256 cycleStart_,
    uint256 cycleDuration_
)
    internal
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|address of the gauge to distribute|
|`rewardsRif_`|`uint256`|ERC20 rewards to distribute|
|`rewardsUsdrif_`|`uint256`||
|`rewardsNative_`|`uint256`|Native rewards to distribute|
|`totalPotentialReward_`|`uint256`|cached total potential reward|
|`periodFinish_`|`uint256`|cached period finish|
|`cycleStart_`|`uint256`|cached cycle start timestamp|
|`cycleDuration_`|`uint256`|cached cycle duration|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|newGaugeRewardShares_ new gauge rewardShares, updated after the distribution|


### _notifyRewardAmountRif

Internal function to notify and transfer RIF reward tokens to this contract.


```solidity
function _notifyRewardAmountRif(uint256 amount_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount_`|`uint256`|The amount of RIF tokens to transfer and notify.|


### _notifyRewardAmountUsdrif

Internal function to notify and transfer USDRIF reward tokens to this contract.


```solidity
function _notifyRewardAmountUsdrif(uint256 amount_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount_`|`uint256`|The amount of USDRIF tokens to transfer and notify.|


### _notifyRewardAmount


```solidity
function _notifyRewardAmount(address token_, address sender_, uint256 amount_) internal;
```

### rifTokenApprove

approves rifTokens to a given gauge

*give full allowance when it is community approved and remove it when it is community banned
reverts if the reward token contract returns false on the approval*


```solidity
function rifTokenApprove(address gauge_, uint256 value_) external onlyBuilderRegistry;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`address`|gauge contract to approve rifTokens|
|`value_`|`uint256`|amount of rifTokens to approve|


### haltGaugeShares

removes halted gauge shares to not be accounted on the distribution anymore

*reverts if it is executed in distribution period because changing the totalPotentialReward
produce a miscalculation of rewards*


```solidity
function haltGaugeShares(GaugeRootstockCollective gauge_)
    external
    onlyBuilderRegistry
    notInDistributionPeriod
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|gauge contract to be halted|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|periodFinish_ timestamp indicating the end of the current rewards period|


### resumeGaugeShares

adds resumed gauge shares to be accounted on the distribution again

*reverts if it is executed in distribution period because changing the totalPotentialReward
produce a miscalculation of rewards*


```solidity
function resumeGaugeShares(
    GaugeRootstockCollective gauge_,
    uint256 haltedGaugeLastPeriodFinish_
)
    external
    onlyBuilderRegistry
    notInDistributionPeriod;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|gauge contract to be resumed|
|`haltedGaugeLastPeriodFinish_`|`uint256`||


## Events
### NewAllocation

```solidity
event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
```

### NotifyReward

```solidity
event NotifyReward(address indexed rifToken_, address indexed sender_, uint256 amount_);
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

### BackerRewardsOptedOut

```solidity
event BackerRewardsOptedOut(address indexed backer_);
```

### BackerRewardsOptedIn

```solidity
event BackerRewardsOptedIn(address indexed backer_);
```

### MaxDistributionsPerBatchUpdated

```solidity
event MaxDistributionsPerBatchUpdated(uint256 oldValue_, uint256 newValue_);
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

### NotAuthorized

```solidity
error NotAuthorized();
```

### BackerOptedOutRewards

```solidity
error BackerOptedOutRewards();
```

### AlreadyOptedInRewards

```solidity
error AlreadyOptedInRewards();
```

### BackerHasAllocations

```solidity
error BackerHasAllocations();
```

### ZeroAddressNotAllowed

```solidity
error ZeroAddressNotAllowed();
```

### RifTokenNotApproved

```solidity
error RifTokenNotApproved();
```

