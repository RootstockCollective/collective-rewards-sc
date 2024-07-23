# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/593a4330380586d483b11df54f093ffbc3b3a65a/src/BuilderRegistry.sol)

**Inherits:** [Governed](/src/governance/Governed.sol/abstract.Governed.md)

Keeps registers of the builders

## State Variables

### foundation

foundation address

```solidity
address public immutable foundation;
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

### builderKickbackPct

map of builders kickback percentage

```solidity
mapping(address builder => uint256 percentage) public builderKickbackPct;
```

## Functions

### onlyFoundation

```solidity
modifier onlyFoundation();
```

### atState

```solidity
modifier atState(address builder_, BuilderState previousState_);
```

### constructor

```solidity
constructor(address governor_, address changeExecutor_, address foundation_) Governed(governor_, changeExecutor_);
```

### activateBuilder

activates builder and set reward receiver

_reverts if is not called by the foundation address reverts if builder state is not pending_

```solidity
function activateBuilder(
    address builder_,
    address rewardReceiver_,
    uint256 builderKickbackPct_
)
    external
    onlyFoundation
    atState(builder_, BuilderState.Pending);
```

**Parameters**

| Name                  | Type      | Description                            |
| --------------------- | --------- | -------------------------------------- |
| `builder_`            | `address` | address of builder                     |
| `rewardReceiver_`     | `address` | address of the builder reward receiver |
| `builderKickbackPct_` | `uint256` | kickback percentage(100% == 1 ether)   |

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

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

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

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

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

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### revokeBuilder

revoke builder

_reverts if is not called by the builder address reverts if builder state is not Whitelisted_

```solidity
function revokeBuilder(address builder_) external atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### setBuilderKickbackPct

set builder kickback percentage

_reverts if is not called by the governor address or authorized changer reverts if builder state is not Whitelisted_

```solidity
function setBuilderKickbackPct(
    address builder_,
    uint256 builderKickbackPct_
)
    external
    onlyGovernorOrAuthorizedChanger
    atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name                  | Type      | Description                          |
| --------------------- | --------- | ------------------------------------ |
| `builder_`            | `address` | address of builder                   |
| `builderKickbackPct_` | `uint256` | kickback percentage(100% == 1 ether) |

### getState

get builder state

```solidity
function getState(address builder_) public view returns (BuilderState);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### getRewardReceiver

get builder reward receiver

```solidity
function getRewardReceiver(address builder_) public view returns (address);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### getBuilderKickbackPct

get builder kickback percentage

```solidity
function getBuilderKickbackPct(address builder_) public view returns (uint256);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### \_setBuilderKickbackPct

```solidity
function _setBuilderKickbackPct(address builder_, uint256 builderKickbackPct_) internal;
```

## Events

### StateUpdate

```solidity
event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);
```

### BuilderKickbackPctUpdate

```solidity
event BuilderKickbackPctUpdate(address indexed builder_, uint256 builderKickbackPct_);
```

## Errors

### NotFoundation

```solidity
error NotFoundation();
```

### NotAuthorized

```solidity
error NotAuthorized();
```

### InvalidBuilderKickbackPct

```solidity
error InvalidBuilderKickbackPct();
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
