# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/d2969cf48df5747a801872ec11a9e5369ab00a1a/src/BuilderRegistry.sol)

Keeps registers of the builders

## State Variables

### foundation

foundation address

```solidity
address public immutable foundation;
```

### governor

governor address

```solidity
address public immutable governor;
```

### builders

map of builders with their information

```solidity
mapping(address builder => Builder registry) public builders;
```

## Functions

### onlyFoundation

```solidity
modifier onlyFoundation();
```

### onlyGovernor

```solidity
modifier onlyGovernor();
```

### atState

```solidity
modifier atState(address builder_, BuilderState preState_);
```

### constructor

constructor

```solidity
constructor(address foundation_, address governor_);
```

**Parameters**

| Name          | Type      | Description               |
| ------------- | --------- | ------------------------- |
| `foundation_` | `address` | address of the foundation |
| `governor_`   | `address` | address of the governor   |

### activateBuilder

activates builder and set rewards receiver

_reverts if is not called by the foundation address reverts if builder state is not pending_

```solidity
function activateBuilder(
    address builder_,
    address rewardsReceiver_
)
    external
    onlyFoundation
    atState(builder_, BuilderState.Pending);
```

**Parameters**

| Name               | Type      | Description                             |
| ------------------ | --------- | --------------------------------------- |
| `builder_`         | `address` | address of builder                      |
| `rewardsReceiver_` | `address` | address of the builder rewards receiver |

### whitelistBuilder

whitelist builder

_reverts if is not called by the governor address reverts if builder state is not KYCApproved_

```solidity
function whitelistBuilder(address builder_) external onlyGovernor atState(builder_, BuilderState.KYCApproved);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### pauseBuilder

pause builder

_reverts if is not called by the governor address reverts if builder state is not Whitelisted_

```solidity
function pauseBuilder(address builder_) external onlyGovernor atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### permitBuilder

permit builder

_reverts if is not called by the governor address reverts if builder state is not Revoked_

```solidity
function permitBuilder(address builder_) external onlyGovernor atState(builder_, BuilderState.Revoked);
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

_reverts if is not called by the governor address reverts if builder state is not Whitelisted_

```solidity
function setRewardSplitPercentage(
    address builder_,
    uint8 rewardSplitPercentage_
)
    external
    onlyGovernor
    atState(builder_, BuilderState.Whitelisted);
```

**Parameters**

| Name                     | Type      | Description                |
| ------------------------ | --------- | -------------------------- |
| `builder_`               | `address` | address of builder         |
| `rewardSplitPercentage_` | `uint8`   | percentage of reward split |

### getState

get builder state

```solidity
function getState(address builder_) public view returns (BuilderState);
```

**Parameters**

| Name       | Type      | Description        |
| ---------- | --------- | ------------------ |
| `builder_` | `address` | address of builder |

### getRewardsReceiver

get builder rewards receiver

```solidity
function getRewardsReceiver(address builder_) public view returns (address);
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

## Events

### StateUpdate

```solidity
event StateUpdate(address indexed builder_, BuilderState indexed state_);
```

### RewardSplitPercentageUpdate

```solidity
event RewardSplitPercentageUpdate(address indexed builder_, uint8 rewardSplitPercentage_);
```

## Errors

### NotFoundation

```solidity
error NotFoundation();
```

### NotGovernor

```solidity
error NotGovernor();
```

### NotAuthorized

```solidity
error NotAuthorized();
```

### RequiredState

```solidity
error RequiredState(BuilderState state);
```

## Structs

### Builder

```solidity
struct Builder {
    BuilderState state;
    address rewardsReceiver;
    uint256 rewardSplitPercentage;
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
