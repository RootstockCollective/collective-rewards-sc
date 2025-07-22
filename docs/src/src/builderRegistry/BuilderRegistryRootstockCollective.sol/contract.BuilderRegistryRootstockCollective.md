# BuilderRegistryRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/f946f53322702b68bdb68a4c01ed6360683360e6/src/builderRegistry/BuilderRegistryRootstockCollective.sol)

**Inherits:**
[UpgradeableRootstockCollective](/src/governance/UpgradeableRootstockCollective.sol/abstract.UpgradeableRootstockCollective.md)

Keeps registers of the builders


## State Variables
### _MAX_REWARD_PERCENTAGE

```solidity
uint256 internal constant _MAX_REWARD_PERCENTAGE = UtilsLib._PRECISION;
```


### rewardDistributor
reward distributor address. If a builder is KYC revoked their unclaimed rewards will sent back here


```solidity
address public rewardDistributor;
```


### builderState
map of builders state


```solidity
mapping(address builder => BuilderState state) public builderState;
```


### rewardReceiver
map of builders reward receiver


```solidity
mapping(address builder => address rewardReceiver) public rewardReceiver;
```


### rewardReceiverUpdate
map of builders reward receiver updates, used as a buffer until the new address is accepted


```solidity
mapping(address builder => address update) public rewardReceiverUpdate;
```


### backerRewardPercentage
map of builder's backers reward percentage data


```solidity
mapping(address builder => RewardPercentageData rewardPercentageData) public backerRewardPercentage;
```


### _gauges
array of all the operational gauges


```solidity
EnumerableSet.AddressSet internal _gauges;
```


### _haltedGauges
array of all the halted gauges


```solidity
EnumerableSet.AddressSet internal _haltedGauges;
```


### gaugeFactory
gauge factory contract address


```solidity
GaugeFactoryRootstockCollective public gaugeFactory;
```


### builderToGauge
gauge contract for a builder


```solidity
mapping(address builder => GaugeRootstockCollective gauge) public builderToGauge;
```


### gaugeToBuilder
builder address for a gauge contract


```solidity
mapping(GaugeRootstockCollective gauge => address builder) public gaugeToBuilder;
```


### haltedGaugeLastPeriodFinish
map of last period finish for halted gauges


```solidity
mapping(GaugeRootstockCollective gauge => uint256 lastPeriodFinish) public haltedGaugeLastPeriodFinish;
```


### rewardPercentageCooldown
time that must elapse for a new reward percentage from a builder to be applied


```solidity
uint128 public rewardPercentageCooldown;
```


### backersManager
address of the BackersManagerRootstockCollective contract


```solidity
BackersManagerRootstockCollective public backersManager;
```


### __gap
*This empty reserved space is put in place to allow future versions to add new
variables without shifting down storage in the inheritance chain.
See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps*


```solidity
uint256[50] private __gap;
```


## Functions
### onlyKycApprover


```solidity
modifier onlyKycApprover();
```

### onlyUpgrader


```solidity
modifier onlyUpgrader();
```

### onlyBackersManager


```solidity
modifier onlyBackersManager();
```

### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

contract initializer


```solidity
function initialize(
    BackersManagerRootstockCollective backersManager_,
    address gaugeFactory_,
    address rewardDistributor_,
    uint128 rewardPercentageCooldown_
)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`backersManager_`|`BackersManagerRootstockCollective`|address of the BackersManagerRootstockCollective contract|
|`gaugeFactory_`|`address`|address of the GaugeFactoryRootstockCollective contract|
|`rewardDistributor_`|`address`|address of the rewardDistributor contract|
|`rewardPercentageCooldown_`|`uint128`|time that must elapse for a new reward percentage from a builder to be applied|


### requestRewardReceiverUpdate

Builder submits a request to update his rewardReceiver address,
the request will then need to be approved by `approveNewRewardReceiver`

*reverts if Builder is not Operational*


```solidity
function requestRewardReceiverUpdate(address newRewardReceiver_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRewardReceiver_`|`address`|new address the builder is requesting to use|


### cancelRewardReceiverUpdate

Builder cancels his request to update his rewardReceiver address

*reverts if Builder is not Operational*


```solidity
function cancelRewardReceiverUpdate() external;
```

### approveNewRewardReceiver

KYCApprover approves Builder request to update his rewardReceiver address

*reverts if provided `newRewardReceiver_` doesn't match Builder's request*


```solidity
function approveNewRewardReceiver(address builder_, address newRewardReceiver_) external onlyKycApprover;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|
|`newRewardReceiver_`|`address`|new address the builder is requesting to use|


### isRewardReceiverUpdatePending

returns true if the builder has an open request to update his receiver address


```solidity
function isRewardReceiverUpdatePending(address builder_) public view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|


### initializeBuilder

initializes builder, setting the reward receiver and the reward percentage
Sets initialized flag to true. It cannot be switched to false anymore

*reverts if it is not called by the owner address
reverts if it is already initialized*


```solidity
function initializeBuilder(
    address builder_,
    address rewardReceiver_,
    uint64 rewardPercentage_
)
    external
    onlyKycApprover;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|
|`rewardReceiver_`|`address`|address of the builder reward receiver|
|`rewardPercentage_`|`uint64`|reward percentage(100% == 1 ether)|


### approveBuilderKYC

approves builder's KYC after a revocation

*reverts if it is not called by the owner address
reverts if it is not initialized
reverts if it is already KYC approved
reverts if it does not have a gauge associated*


```solidity
function approveBuilderKYC(address builder_) external onlyKycApprover;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|


### revokeBuilderKYC

revokes builder's KYC and sent builder unclaimed rewards to rewardDistributor contract

*reverts if it is not called by the owner address
reverts if it is not KYC approved*


```solidity
function revokeBuilderKYC(address builder_) external onlyKycApprover;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|


### communityApproveBuilder

community approve builder and create its gauge

*reverts if it is not called by the governor or the authorized changer
reverts if is already community approved
reverts if it has a gauge associated*


```solidity
function communityApproveBuilder(address builder_)
    external
    onlyValidChanger
    returns (GaugeRootstockCollective gauge_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|gauge contract|


### communityBanBuilder

community ban builder. This process is effectively irreversible, as community approval requires a gauge
to not exist fo given builder

*reverts if it is not called by the governor address or authorized changer
reverts if it does not have a gauge associated
reverts if it is not community approved*


```solidity
function communityBanBuilder(address builder_) external onlyValidChanger;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|


### dewhitelistBuilder

Removes a builder from the whitelist. This function is maintained for compatibility with the previous
naming convention

*reverts if it is not called by the governor address or authorized changer
reverts if it does not have a gauge associated
reverts if it is not community approved
Internally calls `_communityBanBuilder` to perform the operation.*


```solidity
function dewhitelistBuilder(address builder_) external onlyValidChanger;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|


### pauseBuilderKYC

pause builder KYC

*reverts if it is not called by the owner address*


```solidity
function pauseBuilderKYC(address builder_, bytes20 reason_) external onlyKycApprover;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|
|`reason_`|`bytes20`|reason for the pause|


### unpauseBuilderKYC

unpause builder KYC

*reverts if it is not called by the owner address
reverts if it is not paused*


```solidity
function unpauseBuilderKYC(address builder_) external onlyKycApprover;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|


### unpauseSelf

Builder unpauses himself

*reverts if it does not have a gauge associated
reverts if it is not KYC approved
reverts if it is not community approved
reverts if it is not self paused
reverts if it is executed in distribution period because changing the totalPotentialReward produce a
miscalculation of rewards*


```solidity
function unpauseSelf(uint64 rewardPercentage_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardPercentage_`|`uint64`|reward percentage(100% == 1 ether)|


### pauseSelf

Builder pauses himself - this action will also halt the gauge

*reverts if caller does not have a gauge associated
reverts if caller is not KYC approved
reverts if caller is not community approved
reverts if caller is already self paused
reverts if caller is executed in distribution period because changing the totalPotentialReward produce a
miscalculation of rewards*


```solidity
function pauseSelf() external;
```

### setBackerRewardPercentage

allows a builder to set his backers reward percentage

*reverts if builder is not operational*


```solidity
function setBackerRewardPercentage(uint64 rewardPercentage_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardPercentage_`|`uint64`|reward percentage(100% == 1 ether)|


### getRewardPercentageToApply

returns reward percentage to apply.
If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one


```solidity
function getRewardPercentageToApply(address builder_) public view returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|address of the builder|


### canClaimBuilderReward

returns the reward receiver address for a builder

*reverts if conditions for the builder to claim are not met*


```solidity
function canClaimBuilderReward(address claimer_) external view returns (address rewardReceiver_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`claimer_`|`address`|address of the claimer|


### validateGaugeHalted

Validates if a gauge is halted and can accept allocations

*This function first checks if the gauge is initialized and then checks if it is halted.
Halted gauges can only have negative allocations (withdrawals) and are not considered for rewards.*


```solidity
function validateGaugeHalted(GaugeRootstockCollective gauge_) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|The gauge contract to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the gauge is halted, false otherwise|


### isBuilderOperational

return true if builder is operational
kycApproved == true &&
communityApproved == true &&
paused == false


```solidity
function isBuilderOperational(address builder_) public view returns (bool);
```

### isBuilderPaused

return true if builder is paused


```solidity
function isBuilderPaused(address builder_) public view returns (bool);
```

### isGaugeOperational

return true if gauge is operational
kycApproved == true &&
communityApproved == true &&
paused == false


```solidity
function isGaugeOperational(GaugeRootstockCollective gauge_) public view returns (bool);
```

### getGaugesLength

get length of gauges array


```solidity
function getGaugesLength() public view returns (uint256);
```

### getGaugeAt

get gauge from array at a given index


```solidity
function getGaugeAt(uint256 index_) public view returns (address);
```

### getGaugesInRange

Get gauges in a specified range.


```solidity
function getGaugesInRange(uint256 start_, uint256 length_) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`start_`|`uint256`|The starting index (inclusive).|
|`length_`|`uint256`|The number of gauge addresses we want to retrieve.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|gauges_ An array of gauge addresses within the specified range.|


### isGaugeRewarded

return true is gauge is rewarded


```solidity
function isGaugeRewarded(address gauge_) public view returns (bool);
```

### getHaltedGaugesLength

get length of halted gauges array


```solidity
function getHaltedGaugesLength() public view returns (uint256);
```

### getHaltedGaugeAt

get halted gauge by index


```solidity
function getHaltedGaugeAt(uint256 index_) public view returns (address);
```

### isGaugeHalted

return true is gauge is halted


```solidity
function isGaugeHalted(address gauge_) public view returns (bool);
```

### _createGauge

creates a new gauge for a builder


```solidity
function _createGauge(address builder_) internal returns (GaugeRootstockCollective gauge_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builder_`|`address`|builder address who can claim the rewards|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|gauge contract|


### _requestRewardReceiverUpdate

Builder submits a request to update his rewardReceiver address,
the request will then need to be approved by `approveNewRewardReceiver`

*reverts if Builder is not Operational*


```solidity
function _requestRewardReceiverUpdate(address newRewardReceiver_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRewardReceiver_`|`address`|new address the builder is requesting to use|


### requireInitializedBuilder

Ensures the builder associated with the given gauge exists and builder is initialized

*Reverts if the builder gauge does not exist or if the builder is not initialized.*

*reverts if it is not called by the backers manager*


```solidity
function requireInitializedBuilder(GaugeRootstockCollective gauge_) public view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|The gauge to validate.|


### _haltGauge

halts a gauge moving it from the active array to the halted one


```solidity
function _haltGauge(GaugeRootstockCollective gauge_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|gauge contract to be halted|


### _resumeGauge

resumes a gauge moving it from the halted array to the active one

*BackersManagerRootstockCollective override this function to restore its shares*


```solidity
function _resumeGauge(GaugeRootstockCollective gauge_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|gauge contract to be resumed|


### _canBeResumed

returns true if gauge can be resumed

*kycApproved == true &&
communityApproved == true &&
selfPaused == false*


```solidity
function _canBeResumed(GaugeRootstockCollective gauge_) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`gauge_`|`GaugeRootstockCollective`|gauge contract to be resumed|


### _initializeBuilder

*Initializes builder for the first time, setting the reward receiver and the reward percentage
Sets initialized flag to true. It cannot be switched to false anymore
See [initializeBuilder](/src/builderRegistry/BuilderRegistryRootstockCollective.sol/contract.BuilderRegistryRootstockCollective.md#initializebuilder) for details.*


```solidity
function _initializeBuilder(address builder_, address rewardReceiver_, uint64 rewardPercentage_) private;
```

### _communityApproveBuilder

*Internal function to community approve and create its gauge
See [communityApproveBuilder](/src/builderRegistry/BuilderRegistryRootstockCollective.sol/contract.BuilderRegistryRootstockCollective.md#communityapprovebuilder) for details.*


```solidity
function _communityApproveBuilder(address builder_) private returns (GaugeRootstockCollective gauge_);
```

### _communityBanBuilder

*Internal function to community ban and halt its gauge
See [communityBanBuilder](/src/builderRegistry/BuilderRegistryRootstockCollective.sol/contract.BuilderRegistryRootstockCollective.md#communitybanbuilder) for details.*


```solidity
function _communityBanBuilder(address builder_) private;
```

## Events
### BuilderInitialized

```solidity
event BuilderInitialized(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
```

### KYCApproved

```solidity
event KYCApproved(address indexed builder_);
```

### KYCRevoked

```solidity
event KYCRevoked(address indexed builder_);
```

### CommunityApproved

```solidity
event CommunityApproved(address indexed builder_);
```

### CommunityBanned

```solidity
event CommunityBanned(address indexed builder_);
```

### KYCPaused

```solidity
event KYCPaused(address indexed builder_, bytes20 reason_);
```

### KYCResumed

```solidity
event KYCResumed(address indexed builder_);
```

### SelfPaused

```solidity
event SelfPaused(address indexed builder_);
```

### SelfResumed

```solidity
event SelfResumed(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
```

### BackerRewardPercentageUpdateScheduled

```solidity
event BackerRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
```

### RewardReceiverUpdateRequested

```solidity
event RewardReceiverUpdateRequested(address indexed builder_, address newRewardReceiver_);
```

### RewardReceiverUpdateCancelled

```solidity
event RewardReceiverUpdateCancelled(address indexed builder_, address newRewardReceiver_);
```

### RewardReceiverUpdated

```solidity
event RewardReceiverUpdated(address indexed builder_, address newRewardReceiver_);
```

### GaugeCreated

```solidity
event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
```

## Errors
### BuilderAlreadyKYCApproved

```solidity
error BuilderAlreadyKYCApproved();
```

### BuilderAlreadyCommunityApproved

```solidity
error BuilderAlreadyCommunityApproved();
```

### BuilderAlreadySelfPaused

```solidity
error BuilderAlreadySelfPaused();
```

### NotActivated

```solidity
error NotActivated();
```

### BuilderNotKYCApproved

```solidity
error BuilderNotKYCApproved();
```

### BuilderNotCommunityApproved

```solidity
error BuilderNotCommunityApproved();
```

### BuilderNotKYCPaused

```solidity
error BuilderNotKYCPaused();
```

### BuilderNotSelfPaused

```solidity
error BuilderNotSelfPaused();
```

### BuilderNotOperational

```solidity
error BuilderNotOperational();
```

### InvalidBackerRewardPercentage

```solidity
error InvalidBackerRewardPercentage();
```

### InvalidRewardReceiver

```solidity
error InvalidRewardReceiver();
```

### BuilderAlreadyInitialized

```solidity
error BuilderAlreadyInitialized();
```

### BuilderNotInitialized

```solidity
error BuilderNotInitialized();
```

### BuilderAlreadyExists

```solidity
error BuilderAlreadyExists();
```

### BuilderDoesNotExist

```solidity
error BuilderDoesNotExist();
```

### GaugeDoesNotExist

```solidity
error GaugeDoesNotExist();
```

### NotAuthorized

```solidity
error NotAuthorized();
```

### ZeroAddressNotAllowed

```solidity
error ZeroAddressNotAllowed();
```

### BuilderRewardsLocked

```solidity
error BuilderRewardsLocked();
```

### InvalidIndex

```solidity
error InvalidIndex();
```

## Structs
### BuilderState

```solidity
struct BuilderState {
    bool initialized;
    bool kycApproved;
    bool communityApproved;
    bool kycPaused;
    bool selfPaused;
    bytes7 reserved;
    bytes20 pausedReason;
}
```

### RewardPercentageData

```solidity
struct RewardPercentageData {
    uint64 previous;
    uint64 next;
    uint128 cooldownEndTime;
}
```

