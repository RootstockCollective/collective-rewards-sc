# Governed

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/8b50b6318cc8362cde9fe692c46b17c03a0f97c2/src/governance/Governed.sol)

Base contract to be inherited by governed contracts

_This contract is not usable on its own since it does not have any *productive useful* behavior The only purpose of this
contract is to define some useful modifiers and functions to be used on the governance aspect of the child contract_

## State Variables

### changeExecutor

contract that can articulate more complex changes executed from the governor

```solidity
IChangeExecutor public changeExecutor;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyGovernorOrAuthorizedChanger

Modifier that protects the function

_You should use this modifier in any function that should be called through the governance system_

```solidity
modifier onlyGovernorOrAuthorizedChanger();
```

### onlyGovernor

Reverts if caller is not the governor

```solidity
modifier onlyGovernor();
```

### governor

maintains Governed interface. Returns governed address

```solidity
function governor() public view virtual returns (address);
```

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

### NotGovernor

```solidity
error NotGovernor();
```
