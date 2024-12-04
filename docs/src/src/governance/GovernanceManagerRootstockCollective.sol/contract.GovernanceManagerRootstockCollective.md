# GovernanceManagerRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/6d0eca4e2c61e833bcb70c54d8668e5644ba180e/src/governance/GovernanceManagerRootstockCollective.sol)

**Inherits:** UUPSUpgradeable,
[IGovernanceManagerRootstockCollective](/src/interfaces/IGovernanceManagerRootstockCollective.sol/interface.IGovernanceManagerRootstockCollective.md)

This contract manages governance addresses.

It also allows the governor to execute contracts that implement the IChangeContractRootstockCollective interface.

_Complete documentation is provided in the IGovernanceManagerRootstockCollective interface_

_This contract is upgradeable via the UUPS proxy pattern._

## State Variables

### governor

The address of the governor.

```solidity
address public governor;
```

### \_authorizedChanger

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

### \_\_gap

_This empty reserved space is put in place to allow future versions to add new variables without shifting down storage
in the inheritance chain. See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps_

```solidity
uint256[50] private __gap;
```

## Functions

### onlyValidAddress

```solidity
modifier onlyValidAddress(address account_);
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

_Disables initializers for the contract. This ensures the contract is upgradeable._

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

### validateFoundationTreasury

```solidity
function validateFoundationTreasury(address account_) external view;
```

### isAuthorizedChanger

```solidity
function isAuthorizedChanger(address account_) public view returns (bool);
```

### \_updateGovernor

```solidity
function _updateGovernor(address governor_) private onlyValidAddress(governor_);
```

### \_updateFoundationTreasury

```solidity
function _updateFoundationTreasury(address foundationTreasury_) private onlyValidAddress(foundationTreasury_);
```

### \_updateKYCApprover

```solidity
function _updateKYCApprover(address kycApprover_) private onlyValidAddress(kycApprover_);
```

### \_updateUpgrader

```solidity
function _updateUpgrader(address upgrader_) private;
```

### \_authorizeChanger

```solidity
function _authorizeChanger(address authorizedChanger_) internal;
```

### \_authorizeUpgrade

```solidity
function _authorizeUpgrade(address newImplementation_) internal override onlyAuthorizedUpgrader;
```
