# BuilderRegistry

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/93d5161844768d71b8f7420d54b86b3a341b2a7b/src/BuilderRegistry.sol)

**Inherits:** [EpochTimeKeeper](/src/EpochTimeKeeper.sol/abstract.EpochTimeKeeper.md), Ownable2StepUpgradeable

Keeps registers of the builders

## State Variables

### \_MAX_KICKBACK

```solidity
uint256 internal constant _MAX_KICKBACK = UtilsLib._PRECISION;
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

### builderRewardReceiver

map of builders reward receiver

```solidity
mapping(address builder => address rewardReceiver) public builderRewardReceiver;
```

### builderKickback

map of builders kickback data

```solidity
mapping(address builder => KickbackData kickbackData) public builderKickback;
```

### \_gauges

array of all the operational gauges

```solidity
EnumerableSet.AddressSet internal _gauges;
```

### \_haltedGauges

array of all the halted gauges

```solidity
EnumerableSet.AddressSet internal _haltedGauges;
```

### gaugeFactory

gauge factory contract address

```solidity
GaugeFactory public gaugeFactory;
```

### builderToGauge

gauge contract for a builder

```solidity
mapping(address builder => Gauge gauge) public builderToGauge;
```

### gaugeToBuilder

builder address for a gauge contract

```solidity
mapping(Gauge gauge => address builder) public gaugeToBuilder;
```

### haltedGaugeLastPeriodFinish

map of last period finish for halted gauges

```solidity
mapping(Gauge gauge => uint256 lastPeriodFinish) public haltedGaugeLastPeriodFinish;
```

### kickbackCooldown

time that must elapse for a new kickback from a builder to be applied

```solidity
uint128 public kickbackCooldown;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### \_\_BuilderRegistry_init

contract initializer

```solidity
function __BuilderRegistry_init(
    address changeExecutor_,
    address kycApprover_,
    address gaugeFactory_,
    address rewardDistributor_,
    uint32 epochDuration_,
    uint24 epochStartOffset_,
    uint128 kickbackCooldown_
)
    internal
    onlyInitializing;
```

**Parameters**

| Name                 | Type      | Description                                                                                  |
| -------------------- | --------- | -------------------------------------------------------------------------------------------- |
| `changeExecutor_`    | `address` | See Governed doc                                                                             |
| `kycApprover_`       | `address` | account responsible of approving Builder's Know you Costumer policies and Legal requirements |
| `gaugeFactory_`      | `address` | address of the GaugeFactory contract                                                         |
| `rewardDistributor_` | `address` | address of the rewardDistributor contract                                                    |
| `epochDuration_`     | `uint32`  | epoch time duration                                                                          |
| `epochStartOffset_`  | `uint24`  | offset to add to the first epoch, used to set an specific day to start the epochs            |
| `kickbackCooldown_`  | `uint128` | time that must elapse for a new kickback from a builder to be applied                        |

### activateBuilder

activates builder for the first time, setting the reward receiver and the kickback Sets activate flag to true. It cannot
be switched to false anymore

_reverts if it is not called by the owner address reverts if it is already activated_

```solidity
function activateBuilder(address builder_, address rewardReceiver_, uint64 kickback_) external onlyOwner;
```

**Parameters**

| Name              | Type      | Description                            |
| ----------------- | --------- | -------------------------------------- |
| `builder_`        | `address` | address of the builder                 |
| `rewardReceiver_` | `address` | address of the builder reward receiver |
| `kickback_`       | `uint64`  | kickback(100% == 1 ether)              |

### approveBuilderKYC

approves builder's KYC after a revocation

_reverts if it is not called by the owner address reverts if it is not activated reverts if it is already KYC approved
reverts if it does not have a gauge associated_

```solidity
function approveBuilderKYC(address builder_) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### revokeBuilderKYC

revokes builder's KYC and sent builder unclaimed rewards to rewardDistributor contract

_reverts if it is not called by the owner address reverts if it is not KYC approved_

```solidity
function revokeBuilderKYC(address builder_) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### whitelistBuilder

whitelist builder and create its gauge

_reverts if it is not called by the governor address or authorized changer reverts if is already whitelisted reverts if
it has a gauge associated_

```solidity
function whitelistBuilder(address builder_) external onlyGovernorOrAuthorizedChanger returns (Gauge gauge_);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

**Returns**

| Name     | Type    | Description    |
| -------- | ------- | -------------- |
| `gauge_` | `Gauge` | gauge contract |

### dewhitelistBuilder

de-whitelist builder

_reverts if it is not called by the governor address or authorized changer reverts if it does not have a gauge
associated reverts if it is not whitelisted_

```solidity
function dewhitelistBuilder(address builder_) external onlyGovernorOrAuthorizedChanger;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### pauseBuilder

pause builder

_reverts if it is not called by the owner address_

```solidity
function pauseBuilder(address builder_, bytes20 reason_) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |
| `reason_`  | `bytes20` | reason for the pause   |

### unpauseBuilder

unpause builder

_reverts if it is not called by the owner address reverts if it is not paused_

```solidity
function unpauseBuilder(address builder_) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### permitBuilder

permit builder

_reverts if it does not have a gauge associated reverts if it is not KYC approved reverts if it is not whitelisted
reverts if it is not revoked reverts if it is executed in distribution period because changing the totalPotentialReward
produce a miscalculation of rewards_

```solidity
function permitBuilder(uint64 kickback_) external;
```

**Parameters**

| Name        | Type     | Description               |
| ----------- | -------- | ------------------------- |
| `kickback_` | `uint64` | kickback(100% == 1 ether) |

### revokeBuilder

revoke builder

_reverts if it does not have a gauge associated reverts if it is not KYC approved reverts if it is not whitelisted
reverts if it is already revoked reverts if it is executed in distribution period because changing the
totalPotentialReward produce a miscalculation of rewards_

```solidity
function revokeBuilder() external;
```

### setBuilderKickback

set a builder kickback

_reverts if builder is not operational_

```solidity
function setBuilderKickback(uint64 kickback_) external;
```

**Parameters**

| Name        | Type     | Description               |
| ----------- | -------- | ------------------------- |
| `kickback_` | `uint64` | kickback(100% == 1 ether) |

### getKickbackToApply

returns kickback to apply. If there is a new one and cooldown time has expired, apply that one; otherwise, apply the
previous one

```solidity
function getKickbackToApply(address builder_) public view returns (uint64);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### isBuilderOperational

return true if builder is operational kycApproved == true && whitelisted == true && paused == false

```solidity
function isBuilderOperational(address builder_) public view returns (bool);
```

### isBuilderPaused

return true if builder is paused

```solidity
function isBuilderPaused(address builder_) public view returns (bool);
```

### isGaugeOperational

return true if gauge is operational kycApproved == true && whitelisted == true && paused == false

```solidity
function isGaugeOperational(Gauge gauge_) public view returns (bool);
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

get halted gauge from array at a given index

```solidity
function getHaltedGaugeAt(uint256 index_) public view returns (address);
```

### isGaugeHalted

return true is gauge is halted

```solidity
function isGaugeHalted(address gauge_) public view returns (bool);
```

### \_createGauge

creates a new gauge for a builder

```solidity
function _createGauge(address builder_) internal returns (Gauge gauge_);
```

**Parameters**

| Name       | Type      | Description                               |
| ---------- | --------- | ----------------------------------------- |
| `builder_` | `address` | builder address who can claim the rewards |

**Returns**

| Name     | Type    | Description    |
| -------- | ------- | -------------- |
| `gauge_` | `Gauge` | gauge contract |

### \_validateGauge

reverts if builder was not activated or approved by the community

```solidity
function _validateGauge(Gauge gauge_) internal view;
```

### \_haltGauge

halts a gauge moving it from the active array to the halted one

```solidity
function _haltGauge(Gauge gauge_) internal;
```

**Parameters**

| Name     | Type    | Description                 |
| -------- | ------- | --------------------------- |
| `gauge_` | `Gauge` | gauge contract to be halted |

### \_resumeGauge

resumes a gauge moving it from the halted array to the active one

_SponsorsManager override this function to restore its shares_

```solidity
function _resumeGauge(Gauge gauge_) internal;
```

**Parameters**

| Name     | Type    | Description                  |
| -------- | ------- | ---------------------------- |
| `gauge_` | `Gauge` | gauge contract to be resumed |

### \_canBeResumed

returns true if gauge can be resumed

_kycApproved == true && whitelisted == true && revoked == false_

```solidity
function _canBeResumed(Gauge gauge_) internal view returns (bool);
```

**Parameters**

| Name     | Type    | Description                  |
| -------- | ------- | ---------------------------- |
| `gauge_` | `Gauge` | gauge contract to be resumed |

### \_rewardTokenApprove

SponsorsManager override this function to modify gauge rewardToken allowance

```solidity
function _rewardTokenApprove(address gauge_, uint256 value_) internal virtual;
```

**Parameters**

| Name     | Type      | Description                            |
| -------- | --------- | -------------------------------------- |
| `gauge_` | `address` | gauge contract to approve rewardTokens |
| `value_` | `uint256` | amount of rewardTokens to approve      |

### \_haltGaugeShares

SponsorsManager override this function to remove its shares

```solidity
function _haltGaugeShares(Gauge gauge_) internal virtual;
```

**Parameters**

| Name     | Type    | Description                 |
| -------- | ------- | --------------------------- |
| `gauge_` | `Gauge` | gauge contract to be halted |

### \_resumeGaugeShares

SponsorsManager override this function to restore its shares

```solidity
function _resumeGaugeShares(Gauge gauge_) internal virtual;
```

**Parameters**

| Name     | Type    | Description                  |
| -------- | ------- | ---------------------------- |
| `gauge_` | `Gauge` | gauge contract to be resumed |

## Events

### BuilderActivated

```solidity
event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 kickback_);
```

### KYCApproved

```solidity
event KYCApproved(address indexed builder_);
```

### KYCRevoked

```solidity
event KYCRevoked(address indexed builder_);
```

### Whitelisted

```solidity
event Whitelisted(address indexed builder_);
```

### Dewhitelisted

```solidity
event Dewhitelisted(address indexed builder_);
```

### Paused

```solidity
event Paused(address indexed builder_, bytes20 reason_);
```

### Unpaused

```solidity
event Unpaused(address indexed builder_);
```

### Revoked

```solidity
event Revoked(address indexed builder_);
```

### Permitted

```solidity
event Permitted(address indexed builder_, uint256 kickback_, uint256 cooldown_);
```

### BuilderKickbackUpdateScheduled

```solidity
event BuilderKickbackUpdateScheduled(address indexed builder_, uint256 kickback_, uint256 cooldown_);
```

### GaugeCreated

```solidity
event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
```

## Errors

### AlreadyActivated

```solidity
error AlreadyActivated();
```

### AlreadyKYCApproved

```solidity
error AlreadyKYCApproved();
```

### AlreadyWhitelisted

```solidity
error AlreadyWhitelisted();
```

### AlreadyRevoked

```solidity
error AlreadyRevoked();
```

### NotActivated

```solidity
error NotActivated();
```

### NotKYCApproved

```solidity
error NotKYCApproved();
```

### NotWhitelisted

```solidity
error NotWhitelisted();
```

### NotPaused

```solidity
error NotPaused();
```

### NotRevoked

```solidity
error NotRevoked();
```

### IsRevoked

```solidity
error IsRevoked();
```

### CannotRevoke

```solidity
error CannotRevoke();
```

### NotOperational

```solidity
error NotOperational();
```

### InvalidBuilderKickback

```solidity
error InvalidBuilderKickback();
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

## Structs

### BuilderState

```solidity
struct BuilderState {
    bool activated;
    bool kycApproved;
    bool whitelisted;
    bool paused;
    bool revoked;
    bytes7 reserved;
    bytes20 pausedReason;
}
```

### KickbackData

```solidity
struct KickbackData {
    uint64 previous;
    uint64 next;
    uint128 cooldownEndTime;
}
```
