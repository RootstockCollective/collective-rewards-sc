# Governed

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/d787bf9d642d60ab03ebe2323e7c89ea1ab0b880/src/governance/Governed.sol)

Base contract to be inherited by governed contracts

_This contract is not usable on its own since it does not have any *productive useful* behavior The only purpose of this
contract is to define some useful modifiers and functions to be used on the governance aspect of the child contract_

## State Variables

### governor

governor contract address

```solidity
address public immutable governor;
```

### changeExecutor

contract that can articulate more complex changes executed from the governor

```solidity
ChangeExecutor public immutable changeExecutor;
```

## Functions

### onlyGovernorOrAuthorizedChanger

Modifier that protects the function

_You should use this modifier in any function that should be called through the governance system_

```solidity
modifier onlyGovernorOrAuthorizedChanger();
```

### constructor

Constructor

```solidity
constructor(address governor_, address changeExecutor_);
```

**Parameters**

| Name              | Type      | Description                     |
| ----------------- | --------- | ------------------------------- |
| `governor_`       | `address` | governor contract address       |
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
