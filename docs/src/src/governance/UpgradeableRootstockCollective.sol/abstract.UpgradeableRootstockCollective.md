# UpgradeableRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/99cb2d8ed5962fe0d1a12a5277c2e7b1068aeff8/src/governance/UpgradeableRootstockCollective.sol)

**Inherits:**
UUPSUpgradeable

Base contract to be inherited by governed contracts

*This contract is not usable on its own since it does not have any _productive useful_ behavior
The only purpose of this contract is to define some useful modifiers and functions to be used on the
governance aspect of the child contract*


## State Variables
### governanceManager

```solidity
IGovernanceManagerRootstockCollective public governanceManager;
```


### __gap
*This empty reserved space is put in place to allow future versions to add new
variables without shifting down storage in the inheritance chain.
See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps*


```solidity
uint256[50] private __gap;
```


## Functions
### onlyValidChanger


```solidity
modifier onlyValidChanger();
```

### onlyAuthorizedUpgrader


```solidity
modifier onlyAuthorizedUpgrader();
```

### __Upgradeable_init

contract initializer


```solidity
function __Upgradeable_init(IGovernanceManagerRootstockCollective governanceManager_) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`governanceManager_`|`IGovernanceManagerRootstockCollective`|contract with permissioned roles|


### _authorizeUpgrade

*checks that the changer that will do the upgrade is currently authorized by governance to makes
changes within the system*


```solidity
function _authorizeUpgrade(address) internal override onlyAuthorizedUpgrader;
```

