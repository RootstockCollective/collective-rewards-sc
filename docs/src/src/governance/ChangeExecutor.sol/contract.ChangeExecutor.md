# ChangeExecutor

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/593a4330380586d483b11df54f093ffbc3b3a65a/src/governance/ChangeExecutor.sol)

**Inherits:** ReentrancyGuard

This contract is used to handle changes on the project when multiple function calls or validation are required. All the
governed protected function can be executed when are called through this contract but only can be performed by the
Governor.

## State Variables

### governor

governor address

```solidity
address public governor;
```

### currentChangeContract

changer contract address to be executed

```solidity
address private currentChangeContract;
```

## Functions

### onlyGovernor

```solidity
modifier onlyGovernor();
```

### constructor

Constructor

```solidity
constructor(address governor_);
```

**Parameters**

| Name        | Type      | Description               |
| ----------- | --------- | ------------------------- |
| `governor_` | `address` | governor contract address |

### executeChange

Function to be called to make the changes in changeContract

_reverts if is not called by the Governor_

```solidity
function executeChange(IChangeContract changeContract_) external;
```

**Parameters**

| Name              | Type              | Description                                           |
| ----------------- | ----------------- | ----------------------------------------------------- |
| `changeContract_` | `IChangeContract` | Address of the contract that will execute the changes |

### isAuthorizedChanger

Returns true if the changer\_ address is currently authorized to make changes within the system

```solidity
function isAuthorizedChanger(address changer_) external view virtual returns (bool);
```

**Parameters**

| Name       | Type      | Description                                 |
| ---------- | --------- | ------------------------------------------- |
| `changer_` | `address` | Address of the contract that will be tested |

### \_executeChange

Function to be called to make the changes in changeContract

_reverts if is not called by the Governor_

```solidity
function _executeChange(IChangeContract changeContract_) internal nonReentrant onlyGovernor;
```

**Parameters**

| Name              | Type              | Description                                           |
| ----------------- | ----------------- | ----------------------------------------------------- |
| `changeContract_` | `IChangeContract` | Address of the contract that will execute the changes |

### \_isAuthorizedChanger

Returns true if the changer\_ address is currently authorized to make changes within the system

```solidity
function _isAuthorizedChanger(address changer_) internal view returns (bool);
```

**Parameters**

| Name       | Type      | Description                                 |
| ---------- | --------- | ------------------------------------------- |
| `changer_` | `address` | Address of the contract that will be tested |

### \_enableChangeContract

Authorize the changeContract address to make changes

```solidity
function _enableChangeContract(IChangeContract changeContract_) internal;
```

**Parameters**

| Name              | Type              | Description                                     |
| ----------------- | ----------------- | ----------------------------------------------- |
| `changeContract_` | `IChangeContract` | Address of the contract that will be authorized |

### \_disableChangeContract

UNAuthorize the currentChangeContract address to make changes

```solidity
function _disableChangeContract() internal;
```

## Errors

### NotGovernor

```solidity
error NotGovernor();
```
