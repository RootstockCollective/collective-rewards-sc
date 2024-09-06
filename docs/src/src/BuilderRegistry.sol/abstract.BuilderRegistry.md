# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/41c5c643e00ea37977046df1020b30b6d7bc2d18/src/BuilderRegistry.sol)

**Inherits:** [Upgradeable](/src/governance/Upgradeable.sol/abstract.Upgradeable.md), Ownable2StepUpgradeable

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

### gauges

array of all the gauges created

```solidity
Gauge[] public gauges;
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

### kickbackCooldown

time that must elapse for a new kickback from a builder to be applied

```solidity
uint256 public kickbackCooldown;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### atState

```solidity
modifier atState(address builder_, BuilderState previousState_);
```

### \_\_BuilderRegistry_init

contract initializer

```solidity
function __BuilderRegistry_init(
    address changeExecutor_,
    address kycApprover_,
    address gaugeFactory_,
    uint256 kickbackCooldown_
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
| `kickbackCooldown_` | `uint256` | time that must elapse for a new kickback from a builder to be applied                        |

### activateBuilder

activates builder and set reward receiver

_reverts if is not called by the owner address reverts if builder state is not pending_

```solidity
function activateBuilder(
    address builder_,
    address rewardReceiver_,
    uint64 kickback_
)
    external
    onlyOwner
    atState(builder_, BuilderState.Pending);
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
function whitelistBuilder(address builder_)
    external
    onlyGovernorOrAuthorizedChanger
    atState(builder_, BuilderState.KYCApproved)
    returns (Gauge gauge_);
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

_reverts if is not called by the governor address or authorized changer reverts if builder state is not Whitelisted_

```solidity
function pauseBuilder(address builder_)
    external
    onlyGovernorOrAuthorizedChanger
    atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### permitBuilder

permit builder

_reverts if is not called by the governor address or authorized changer reverts if builder state is not Revoked_

```solidity
function permitBuilder(address builder_)
    external
    onlyGovernorOrAuthorizedChanger
    atState(builder_, BuilderState.Revoked);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### revokeBuilder

revoke builder

_reverts if is not called by the builder address reverts if builder state is not Whitelisted_

```solidity
function revokeBuilder(address builder_) external atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### setBuilderKickback

set a builder kickback

_reverts if is not called by the builder reverts if builder state is not Whitelisted_

```solidity
function setBuilderKickback(address builder_, uint64 kickback_) external atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name        | Type      | Description               |
| ----------- | --------- | ------------------------- |
| `builder_`  | `address` | address of the builder    |
| `kickback_` | `uint64`  | kickback(100% == 1 ether) |

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

### \_updateState

```solidity
function _updateState(address builder_, BuilderState newState_) internal;
```

## Events

### StateUpdate

```solidity
event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);
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

### NotAuthorized

```solidity
error NotAuthorized();
```

### InvalidBuilderKickback

```solidity
error InvalidBuilderKickback();
```

### RequiredState

```solidity
error RequiredState(BuilderState state_);
```

## Structs

### KickbackData

```solidity
struct KickbackData {
    uint64 previous;
    uint64 latest;
    uint128 cooldownEndTime;
}
```

## Enums

### BuilderState

```solidity
enum BuilderState {
    Pending,
    KYCApproved,
    Whitelisted,
    Paused,
    Revoked
}
```
