# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/5faae52322bedd1d2c4eb8f24dbb918c0ac8fcbf/src/BuilderRegistry.sol)

**Inherits:** [Governed](/src/governance/Governed.sol/abstract.Governed.md), Ownable2StepUpgradeable

Keeps registers of the builders

## State Variables

### MAX_KICKBACK

```solidity
uint256 internal constant MAX_KICKBACK = UtilsLib.PRECISION;
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

### constructor

```solidity
constructor();
```

### initialize

contract initializer

```solidity
function initialize(address changeExecutor_, address kycApprover_) external initializer;
```

**Parameters**

| Name              | Type      | Description                                                                                  |
| ----------------- | --------- | -------------------------------------------------------------------------------------------- |
| `changeExecutor_` | `address` | See Governed doc                                                                             |
| `kycApprover_`    | `address` | account responsible of approving Builder's Know you Costumer policies and Legal requirements |

### activateBuilder

activates builder and set reward receiver

_reverts if is not called by the owner address reverts if builder state is not pending_

```solidity
function activateBuilder(
    address builder_,
    address rewardReceiver_,
    uint256 builderKickback_
)
    external
    onlyOwner
    atState(builder_, BuilderState.Pending);
```

**Parameters**

| Name               | Type      | Description                            |
| ------------------ | --------- | -------------------------------------- |
| `builder_`         | `address` | address of the builder                 |
| `rewardReceiver_`  | `address` | address of the builder reward receiver |
| `builderKickback_` | `uint256` | kickback(100% == 1 ether)              |

### whitelistBuilder

whitelist builder

_reverts if is not called by the governor address or authorized changer reverts if builder state is not KYCApproved_

```solidity
function whitelistBuilder(address builder_)
    external
    onlyGovernorOrAuthorizedChanger
    atState(builder_, BuilderState.KYCApproved);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

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

set builder kickback

_reverts if is not called by the governor address or authorized changer reverts if builder state is not Whitelisted_

```solidity
function setBuilderKickback(
    address builder_,
    uint256 builderKickback_
)
    external
    onlyGovernorOrAuthorizedChanger
    atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name               | Type      | Description               |
| ------------------ | --------- | ------------------------- |
| `builder_`         | `address` | address of the builder    |
| `builderKickback_` | `uint256` | kickback(100% == 1 ether) |

### getState

get builder state

```solidity
function getState(address builder_) public view returns (BuilderState);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### getRewardReceiver

get builder reward receiver

```solidity
function getRewardReceiver(address builder_) public view returns (address);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### getBuilderKickback

get builder kickback

```solidity
function getBuilderKickback(address builder_) public view returns (uint256);
```

**Parameters**

| Name       | Type      | Description            |
| ---------- | --------- | ---------------------- |
| `builder_` | `address` | address of the builder |

### applyBuilderKickback

apply builder kickback

```solidity
function applyBuilderKickback(address builder_, uint256 amount_) public view returns (uint256);
```

**Parameters**

| Name       | Type      | Description                  |
| ---------- | --------- | ---------------------------- |
| `builder_` | `address` | address of the builder       |
| `amount_`  | `uint256` | amount to apply the kickback |

### \_setBuilderKickback

```solidity
function _setBuilderKickback(address builder_, uint256 builderKickback_) internal;
```

### \_updateState

```solidity
function _updateState(address builder_, BuilderState newState_) internal;
```

## Events

### StateUpdate

```solidity
event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);
```

### BuilderKickbackUpdate

```solidity
event BuilderKickbackUpdate(address indexed builder_, uint256 builderKickback_);
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
error RequiredState(BuilderState state);
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
