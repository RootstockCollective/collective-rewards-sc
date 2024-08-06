# SimplifiedGoverned

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/33911ca68a491fee724a3840f51836068065402e/src/mvp/SimplifiedGoverned.sol)

Simplified and non-upgradeable version for the MVP. Base contract to be inherited by governed contracts

_This contract is not usable on its own since it does not have any *productive useful* behavior The only purpose of this
contract is to define some useful modifiers and functions to be used on the governance aspect of the child contract_

## State Variables

### governor

governor contract address

```solidity
address public governor;
```

### changeExecutor

contract that can articulate more complex changes executed from the governor

```solidity
ChangeExecutor public changeExecutor;
```

## Functions

### onlyGovernorOrAuthorizedChanger

Modifier that protects the function

_You should use this modifier in any function that should be called through the governance system_

```solidity
modifier onlyGovernorOrAuthorizedChanger();
```

### constructor

constructor

```solidity
constructor(address changeExecutor_);
```

**Parameters**

| Name              | Type      | Description                     |
| ----------------- | --------- | ------------------------------- |
| `changeExecutor_` | `address` | ChangeExecutor contract address |

### \_checkIfGovernorOrAuthorizedChanger

Checks if the msg sender is the governor or an authorized changer, reverts otherwise

```solidity
function _checkIfGovernorOrAuthorizedChanger() internal view;
```

## Errors

### NotGovernorOrAuthorizedChanger

```solidity
error NotGovernorOrAuthorizedChanger();
```
