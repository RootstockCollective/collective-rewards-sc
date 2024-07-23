# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/9e5650b8576ed38cbee2c0a3ec521c14bf14f352/src/BuilderRegistry.sol)

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

### rewardSplitPercentages

map of builders reward split percentage

```solidity
mapping(address builder => uint256 percentage) public rewardSplitPercentages;
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

constructor

```solidity
constructor(address governor_, address changeExecutor_, address foundation_) Governed(governor_, changeExecutor_);
```

**Parameters**

| Name              | Type      | Description               |
| ----------------- | --------- | ------------------------- |
| `governor_`       | `address` | address of the governor   |
| `changeExecutor_` | `address` |                           |
| `foundation_`     | `address` | address of the foundation |

### activateBuilder

activates builder and set reward receiver

_reverts if is not called by the foundation address reverts if builder state is not pending_

```solidity
function activateBuilder(
    address builder_,
    address rewardReceiver_,
    uint256 rewardSplitPercentage_
)
    external
    onlyFoundation
    atState(builder_, BuilderState.Pending);
```

**Parameters**

| Name                     | Type      | Description                                 |
| ------------------------ | --------- | ------------------------------------------- |
| `builder_`               | `address` | address of builder                          |
| `rewardReceiver_`        | `address` | address of the builder reward receiver      |
| `rewardSplitPercentage_` | `uint256` | percentage of reward split(100% == 1 ether) |

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

### setRewardSplitPercentage

set builder reward split percentage

_reverts if is not called by the governor address or authorized changer reverts if builder state is not Whitelisted_

```solidity
function setRewardSplitPercentage(
    address builder_,
    uint256 rewardSplitPercentage_
)
    external
    onlyGovernorOrAuthorizedChanger
    atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name                     | Type      | Description                                 |
| ------------------------ | --------- | ------------------------------------------- |
| `builder_`               | `address` | address of builder                          |
| `rewardSplitPercentage_` | `uint256` | percentage of reward split(100% == 1 ether) |

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

### getRewardSplitPercentage

get builder reward split percentage

```solidity
function getRewardSplitPercentage(address builder_) public view returns (uint256);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### \_setRewardSplitPercentage

```solidity
function _setRewardSplitPercentage(address builder_, uint256 rewardSplitPercentage_) internal;
```

## Events

### StateUpdate

```solidity
event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);
```

### RewardSplitPercentageUpdate

```solidity
event RewardSplitPercentageUpdate(address indexed builder_, uint256 rewardSplitPercentage_);
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

### InvalidRewardSplitPercentage

```solidity
error InvalidRewardSplitPercentage();
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
