# SimplifiedBuilderRegistry

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/33911ca68a491fee724a3840f51836068065402e/src/mvp/SimplifiedBuilderRegistry.sol)

**Inherits:** [SimplifiedGoverned](/src/mvp/SimplifiedGoverned.sol/abstract.SimplifiedGoverned.md), Ownable2Step

Simplified and non-upgradeable version for the MVP. Keeps registers of the builders

## State Variables

### builderState

map of builders state

```solidity
mapping(address builder => BuilderState state) public builderState;
```

### builderRewardReceiver

map of builders reward receiver

```solidity
mapping(address builder => address payable rewardReceiver) public builderRewardReceiver;
```

### whitelistedBuilders

```solidity
address[] public whitelistedBuilders;
```

## Functions

### atState

```solidity
modifier atState(address builder_, BuilderState previousState_);
```

### constructor

constructor initializes base roles to manipulate the registry

```solidity
constructor(address changeExecutor_, address kycApprover_) SimplifiedGoverned(changeExecutor_) Ownable(kycApprover_);
```

**Parameters**

| Name              | Type      | Description                                                                                  |
| ----------------- | --------- | -------------------------------------------------------------------------------------------- |
| `changeExecutor_` | `address` | See SimplifiedGoverned doc                                                                   |
| `kycApprover_`    | `address` | account responsible of approving Builder's Know you Costumer policies and Legal requirements |

### activateBuilder

activates builder and set reward receiver

_reverts if is not called by the owner address reverts if builder state is not pending_

```solidity
function activateBuilder(
    address builder_,
    address payable rewardReceiver_
)
    external
    onlyOwner
    atState(builder_, BuilderState.Pending);
```

**Parameters**

| Name              | Type              | Description                            |
| ----------------- | ----------------- | -------------------------------------- |
| `builder_`        | `address`         | address of the builder                 |
| `rewardReceiver_` | `address payable` | address of the builder reward receiver |

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

### getWhitelistedBuildersLength

get length of whitelisted builders array

```solidity
function getWhitelistedBuildersLength() public view returns (uint256);
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

## Errors

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
    Whitelisted
}
```
