# Upgradeable

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/41c5c643e00ea37977046df1020b30b6d7bc2d18/src/governance/Upgradeable.sol)

**Inherits:** UUPSUpgradeable, [Governed](/src/governance/Governed.sol/abstract.Governed.md)

Base contract to be inherited by governed contracts

_This contract is not usable on its own since it does not have any *productive useful* behavior The only purpose of this
contract is to define some useful modifiers and functions to be used on the governance aspect of the child contract_

## State Variables

### \_governor

governor contract address

```solidity
address internal _governor;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### \_\_Upgradeable_init

contract initializer

```solidity
function __Upgradeable_init(address changeExecutor_) internal onlyInitializing;
```

**Parameters**

| Name              | Type      | Description                     |
| ----------------- | --------- | ------------------------------- |
| `changeExecutor_` | `address` | ChangeExecutor contract address |

### governor

maintains Governed interface. Returns governed address

```solidity
function governor() public view override returns (address);
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
