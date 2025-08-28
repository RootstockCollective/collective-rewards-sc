# GovernanceManagerRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/dddd380a18864fe36c9ec409abd3170e82ca6a46/src/governance/GovernanceManagerRootstockCollective.sol)

**Inherits:**
UUPSUpgradeable, [IGovernanceManagerRootstockCollective](/src/interfaces/IGovernanceManagerRootstockCollective.sol/interface.IGovernanceManagerRootstockCollective.md)

This contract manages governance addresses.

It also allows the governor to execute contracts that implement the IChangeContractRootstockCollective
interface.

*Complete documentation is provided in the IGovernanceManagerRootstockCollective interface*

*This contract is upgradeable via the UUPS proxy pattern.*


## State Variables
### governor
The address of the governor.


```solidity
address public governor;
```


### _authorizedChanger
The address of the authorized changer.


```solidity
address internal _authorizedChanger;
```


### foundationTreasury
The address of the foundation treasury.


```solidity
address public foundationTreasury;
```


### kycApprover
The address of the KYC approver.


```solidity
address public kycApprover;
```


### upgrader
The upgrader address with contract upgradeability permissions


```solidity
address public upgrader;
```


### configurator
The address with the right to change contract parameters


```solidity
address public configurator;
```


### __gap
*This empty reserved space is put in place to allow future versions to add new
variables without shifting down storage in the inheritance chain.
See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps*


```solidity
uint256[50] private __gap;
```


## Functions
### onlyNonZeroAddress


```solidity
modifier onlyNonZeroAddress(address account_);
```

### onlyGovernor


```solidity
modifier onlyGovernor();
```

### onlyAuthorizedUpgrader


```solidity
modifier onlyAuthorizedUpgrader();
```

### onlyAuthorizedChanger


```solidity
modifier onlyAuthorizedChanger();
```

### constructor

*Disables initializers for the contract. This ensures the contract is upgradeable.*

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(
    address governor_,
    address foundationTreasury_,
    address kycApprover_,
    address upgrader_
)
    public
    initializer;
```

### initializeV2


```solidity
function initializeV2(address configurator_) public reinitializer(2) onlyAuthorizedUpgrader;
```

### executeChange


```solidity
function executeChange(IChangeContractRootstockCollective changeContract_) external onlyGovernor;
```

### updateGovernor


```solidity
function updateGovernor(address governor_) public onlyAuthorizedChanger;
```

### updateFoundationTreasury


```solidity
function updateFoundationTreasury(address foundationTreasury_) public onlyAuthorizedChanger;
```

### updateKYCApprover


```solidity
function updateKYCApprover(address kycApprover_) public onlyAuthorizedChanger;
```

### updateUpgrader


```solidity
function updateUpgrader(address upgrader_) public;
```

### updateConfigurator


```solidity
function updateConfigurator(address configurator_) public;
```

### validateGovernor


```solidity
function validateGovernor(address account_) external view;
```

### validateAuthorizedChanger


```solidity
function validateAuthorizedChanger(address account_) public view;
```

### validateAuthorizedUpgrader


```solidity
function validateAuthorizedUpgrader(address account_) public view;
```

### validateKycApprover


```solidity
function validateKycApprover(address account_) external view;
```

### validateConfigurator


```solidity
function validateConfigurator(address account_) external view;
```

### validateFoundationTreasury


```solidity
function validateFoundationTreasury(address account_) external view;
```

### isAuthorizedChanger


```solidity
function isAuthorizedChanger(address account_) public view returns (bool);
```

### _updateGovernor


```solidity
function _updateGovernor(address governor_) private onlyNonZeroAddress(governor_);
```

### _updateFoundationTreasury


```solidity
function _updateFoundationTreasury(address foundationTreasury_) private onlyNonZeroAddress(foundationTreasury_);
```

### _updateKYCApprover


```solidity
function _updateKYCApprover(address kycApprover_) private onlyNonZeroAddress(kycApprover_);
```

### _updateUpgrader


```solidity
function _updateUpgrader(address upgrader_) private onlyNonZeroAddress(upgrader_);
```

### _updateConfigurator


```solidity
function _updateConfigurator(address configurator_) private onlyNonZeroAddress(configurator_);
```

### _authorizeChanger


```solidity
function _authorizeChanger(address authorizedChanger_) internal;
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation_) internal override onlyAuthorizedUpgrader;
```

### _validateConfigurator


```solidity
function _validateConfigurator(address account_) internal view;
```

