# BuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/570d7f7acfcf922ef9eb9a54cef5dc11cb1bbfe3/src/BuilderRegistry.sol)

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

### builderState

map of builders state

```solidity
mapping(address builder => BuilderState state) public builderState;
```

### builderAuthClaimer

map of builders authorized claimer

```solidity
mapping(address builder => address payable claimer) public builderAuthClaimer;
```

### rewardSplitPercentages

map of builders reward split percentage

```solidity
mapping(address builder => uint8 percentage) public rewardSplitPercentages;
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
modifier atState(address builder_, BuilderState previousState_);
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

activates builder and set authorized claimer

_reverts if is not called by the foundation address reverts if builder state is not pending_

```solidity
function activateBuilder(
    address builder_,
    address payable authClaimer
)
    external
    onlyFoundation
    atState(builder_, BuilderState.Pending);
```

**Parameters**

| Name          | Type              | Description                               |
| ------------- | ----------------- | ----------------------------------------- |
| `builder_`    | `address`         | address of builder                        |
| `authClaimer` | `address payable` | address of the builder authorized claimer |

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

### getAuthClaimer

get builder authorized claimer

```solidity
function getAuthClaimer(address builder_) public view returns (address);
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
event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);
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
