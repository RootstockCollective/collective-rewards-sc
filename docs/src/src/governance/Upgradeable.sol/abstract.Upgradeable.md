# Upgradeable

[Git Source](https://github.com/rsksmart/collective-rewards-sc/blob/6055db6ff187da599d0ad220410df3adfbe4a79d/src/governance/Upgradeable.sol)

**Inherits:** UUPSUpgradeable

Base contract to be inherited by governed contracts

_This contract is not usable on its own since it does not have any *productive useful* behavior The only purpose of this
contract is to define some useful modifiers and functions to be used on the governance aspect of the child contract_

## State Variables

### governanceManager

```solidity
IGovernanceManager public governanceManager;
```

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyValidChanger

```solidity
modifier onlyValidChanger();
```

### \_\_Upgradeable_init

contract initializer

```solidity
function __Upgradeable_init(IGovernanceManager governanceManager_) internal onlyInitializing;
```

**Parameters**

| Name                 | Type                 | Description                      |
| -------------------- | -------------------- | -------------------------------- |
| `governanceManager_` | `IGovernanceManager` | contract with permissioned roles |

### \_authorizeUpgrade

_checks that the changer that will do the upgrade is currently authorized by governance to makes changes within the
system_

```solidity
function _authorizeUpgrade(address) internal override onlyValidChanger;
```
