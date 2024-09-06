# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/65787984373194e94a67c67ddefd555e11be2eaa/src/BuilderRegistry.sol)

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

map of builders kickback

```solidity
mapping(address builder => uint256 percentage) public builderKickback;
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
    address gaugeFactory_
)
    internal
    onlyInitializing;
```

**Parameters**

| Name              | Type      | Description                                                                                  |
| ----------------- | --------- | -------------------------------------------------------------------------------------------- |
| `changeExecutor_` | `address` | See Governed doc                                                                             |
| `kycApprover_`    | `address` | account responsible of approving Builder's Know you Costumer policies and Legal requirements |
| `gaugeFactory_`   | `address` | address of the GaugeFactory contract                                                         |

### activateBuilder

activates builder and set reward receiver

_reverts if is not called by the owner address reverts if builder state is not pending_

```solidity
function activateBuilder(address builder_, address rewardReceiver_, uint256 builderKickback_) external onlyOwner;
```

**Parameters**

| Name               | Type      | Description                            |
| ------------------ | --------- | -------------------------------------- |
| `builder_`         | `address` | address of the builder                 |
| `rewardReceiver_`  | `address` | address of the builder reward receiver |
| `builderKickback_` | `uint256` | kickback(100% == 1 ether)              |

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

_reverts if is not called by the governor address or authorized changer reverts if builder state is not Whitelisted
reverts trying to revoke_

```solidity
function pauseBuilder(address builder_, bytes29 reason_) external onlyGovernorOrAuthorizedChanger;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |
| `reason_`  | `bytes29` | reason for the pause   |

### permitBuilder

permit builder

_reverts if is not called by the governor address or authorized changer reverts if builder state is not Revoked_

```solidity
function permitBuilder(address builder_) external;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### revokeBuilder

revoke builder

_reverts if is not called by the builder address reverts if builder state is not Whitelisted_

```solidity
function revokeBuilder(address builder_) external;
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### setBuilderKickback

set builder kickback

_reverts if is not called by the governor address or authorized changer reverts if builder is not operational_

```solidity
function setBuilderKickback(address builder_, uint256 builderKickback_) external onlyGovernorOrAuthorizedChanger;
```

**Parameters**

| Name               | Type      | Description               |
| ------------------ | --------- | ------------------------- |
| `builder_`         | `address` | address of the builder    |
| `builderKickback_` | `uint256` | kickback(100% == 1 ether) |

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

### \_setBuilderKickback

```solidity
function _setBuilderKickback(address builder_, uint256 builderKickback_) internal;
```

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
event Paused(address indexed builder_, bytes29 reason_);
```

### Revoked

```solidity
event Revoked(address indexed builder_);
```

### Permitted

```solidity
event Permitted(address indexed builder_);
```

### BuilderKickbackUpdate

```solidity
event BuilderKickbackUpdate(address indexed builder_, uint256 builderKickback_);
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

### AlreadyPaused

```solidity
error AlreadyPaused();
```

### NotPaused

```solidity
error NotPaused();
```

### NotRevoked

```solidity
error NotRevoked();
```

### CannotRevoke

```solidity
error CannotRevoke();
```

### NotAuthorized

```solidity
error NotAuthorized();
```

### NotOperational

```solidity
error NotOperational();
```

### InvalidBuilderKickback

```solidity
error InvalidBuilderKickback();
```

## Structs

### BuilderState

```solidity
struct BuilderState {
    bool kycApproved;
    bool whitelisted;
    bool paused;
    bytes29 pausedReason;
}
```
