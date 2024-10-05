# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/478670c448ae0727d9c690bc82b9249b7907e8dc/src/BuilderRegistry.sol)

**Inherits:** [EpochTimeKeeper](/src/EpochTimeKeeper.sol/abstract.EpochTimeKeeper.md), Ownable2StepUpgradeable

Keeps registers of the builders

## State Variables

### \_MAX_KICKBACK

```solidity
uint256 internal constant _MAX_KICKBACK = UtilsLib._PRECISION;
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
    uint32 epochDuration_,
    uint24 epochStartOffset_,
    uint128 kickbackCooldown_
)
    internal
    onlyInitializing;
```

**Parameters**

| Name                | Type      | Description                                                                                  |
| ------------------- | --------- | -------------------------------------------------------------------------------------------- |
| `changeExecutor_`   | `address` | See Governed doc                                                                             |
| `kycApprover_`      | `address` | account responsible of approving Builder's Know you Costumer policies and Legal requirements |
| `gaugeFactory_`     | `address` | address of the GaugeFactory contract                                                         |
| `epochDuration_`    | `uint32`  | epoch time duration                                                                          |
| `epochStartOffset_` | `uint24`  | offset to add to the first epoch, used to set an specific day to start the epochs            |
| `kickbackCooldown_` | `uint128` | time that must elapse for a new kickback from a builder to be applied                        |

### activateBuilder

activates builder and set reward receiver

_reverts if is not called by the owner address reverts if builder state is not pending_

```solidity
function activateBuilder(address builder_, address rewardReceiver_, uint64 kickback_) external onlyOwner;
```

**Parameters**

| Name              | Type      | Description                            |
| ----------------- | --------- | -------------------------------------- |
| `builder_`        | `address` | address of the builder                 |
| `rewardReceiver_` | `address` | address of the builder reward receiver |
| `kickback_`       | `uint64`  | kickback(100% == 1 ether)              |

### whitelistBuilder

whitelist builder and create its gauge

_reverts if is not called by the governor address or authorized changer reverts if builder state is not KYCApproved_

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

### pauseBuilder

pause builder

_reverts if is not called by the owner address_

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

_reverts if is not called by the owner address reverts if builder state is not paused_

```solidity
function unpauseBuilder(address builder_) external onlyOwner;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### permitBuilder

permit builder

_reverts if builder state is not Revoked_

```solidity
function permitBuilder(uint64 kickback_) external;
```

**Parameters**

| Name        | Type     | Description               |
| ----------- | -------- | ------------------------- |
| `kickback_` | `uint64` | kickback(100% == 1 ether) |

### revokeBuilder

revoke builder

_reverts if builder is already revoked_

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

### \_haltGauge

halts a gauge moving it from the active array to the halted one

_SponsorsManager override this function to remove its shares_

```solidity
function _haltGauge(Gauge gauge_) internal virtual;
```

**Parameters**

| Name     | Type    | Description                 |
| -------- | ------- | --------------------------- |
| `gauge_` | `Gauge` | gauge contract to be halted |

### \_resumeGauge

resumes a gauge moving it from the halted array to the active one

_SponsorsManager override this function to restore its shares_

```solidity
function _resumeGauge(Gauge gauge_) internal virtual;
```

**Parameters**

| Name     | Type    | Description                  |
| -------- | ------- | ---------------------------- |
| `gauge_` | `Gauge` | gauge contract to be resumed |

## Events

### KYCApproved

```solidity
event KYCApproved(address indexed builder_);
```

### Whitelisted

```solidity
event Whitelisted(address indexed builder_);
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

### BuilderDoesNotExist

```solidity
error BuilderDoesNotExist();
```

## Structs

### BuilderState

```solidity
struct BuilderState {
    bool kycApproved;
    bool whitelisted;
    bool paused;
    bool revoked;
    bytes8 reserved;
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
