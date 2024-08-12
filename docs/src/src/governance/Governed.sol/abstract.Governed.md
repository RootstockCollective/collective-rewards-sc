# Governed

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/c4d78ff998298ce9e3dffdd99f32430a3c5ed3af/src/governance/Governed.sol)

**Inherits:** UUPSUpgradeable

Base contract to be inherited by governed contracts

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

### \_\_Governed_init

contract initializer

```solidity
function __Governed_init(address changeExecutor_) internal onlyInitializing;
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

### \_authorizeUpgrade

_checks that the changer that will do the upgrade is currently authorized by governance to makes changes within the
system_

```solidity
function _authorizeUpgrade(address newImplementation_) internal override onlyGovernorOrAuthorizedChanger;
```

**Parameters**

| Name                 | Type      | Description                         |
| -------------------- | --------- | ----------------------------------- |
| `newImplementation_` | `address` | new implementation contract address |

## Errors

### NotGovernorOrAuthorizedChanger

```solidity
error NotGovernorOrAuthorizedChanger();
```
