# GovernanceManagerRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/0c4368dc418c200f21d2a798619d1dd68234c5c1/src/governance/GovernanceManagerRootstockCollective.sol)

**Inherits:** UUPSUpgradeable,
[IGovernanceManagerRootstockCollective](/src/interfaces/IGovernanceManagerRootstockCollective.sol/interface.IGovernanceManagerRootstockCollective.md)

This contract manages governance addresses.

It also allows the governor to execute contracts that implement the IChangeContractRootstockCollective interface.

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

### onlyValidChanger

```solidity
modifier onlyValidChanger();
```

### constructor

_Disables initializers for the contract. This ensures the contract is upgradeable._

```solidity
constructor();
```

### initialize

Initializes the contract with the initial governor, foundation treasury, and KYC approver.

_Used instead of a constructor for upgradeable contracts._

```solidity
function initialize(address governor_, address foundationTreasury_, address kycApprover_) public initializer;
```

**Parameters**

| Name                  | Type      | Description                              |
| --------------------- | --------- | ---------------------------------------- |
| `governor_`           | `address` | The initial governor address.            |
| `foundationTreasury_` | `address` | The initial foundation treasury address. |
| `kycApprover_`        | `address` | The initial KYC approver address.        |

### executeChange

Function to be called to make the changes in changeContract

_reverts if is not called by the Governor_

```solidity
function executeChange(IChangeContractRootstockCollective changeContract_) external onlyGovernor;
```

**Parameters**

| Name              | Type                                 | Description                                           |
| ----------------- | ------------------------------------ | ----------------------------------------------------- |
| `changeContract_` | `IChangeContractRootstockCollective` | Address of the contract that will execute the changes |

### updateGovernor

Allows the governor to update its own role to a new address.

_Reverts if caller is not the current governor._

```solidity
function updateGovernor(address governor_) public onlyValidChanger;
```

**Parameters**

| Name        | Type      | Description               |
| ----------- | --------- | ------------------------- |
| `governor_` | `address` | The new governor address. |

### updateFoundationTreasury

Allows the governor to update the foundation treasury address.

_Only callable by the governor. Reverts if the new address is invalid._

```solidity
function updateFoundationTreasury(address foundationTreasury_) public onlyValidChanger;
```

**Parameters**

| Name                  | Type      | Description                          |
| --------------------- | --------- | ------------------------------------ |
| `foundationTreasury_` | `address` | The new foundation treasury address. |

### updateKYCApprover

Allows the governor to update the KYC approver address.

_Only callable by the governor. Reverts if the new address is invalid._

```solidity
function updateKYCApprover(address kycApprover_) public onlyValidChanger;
```

**Parameters**

| Name           | Type      | Description                   |
| -------------- | --------- | ----------------------------- |
| `kycApprover_` | `address` | The new KYC approver address. |

### validateGovernor

Validates if an account is authorized as the governor.

_Reverts with `NotGovernor` if the account is not the governor._

```solidity
function validateGovernor(address account_) external view;
```

**Parameters**

| Name       | Type      | Description                  |
| ---------- | --------- | ---------------------------- |
| `account_` | `address` | The address to be validated. |

### validateChanger

Validates if an account is authorized to perform changes.

_Reverts with `NotAuthorizedChanger` if the account is not the authorized changer or governor._

```solidity
function validateChanger(address account_) public view;
```

**Parameters**

| Name       | Type      | Description                  |
| ---------- | --------- | ---------------------------- |
| `account_` | `address` | The address to be validated. |

### validateKycApprover

Validates if an account is authorized as the KYC approver.

_Reverts with `NotKycApprover` if the account is not the KYC approver._

```solidity
function validateKycApprover(address account_) external view;
```

**Parameters**

| Name       | Type      | Description                  |
| ---------- | --------- | ---------------------------- |
| `account_` | `address` | The address to be validated. |

### validateFoundationTreasury

Validates if the caller is the foundation treasury.

_Reverts with `NotFoundationTreasury` if the caller is not the foundation treasury._

```solidity
function validateFoundationTreasury(address account_) external view;
```

### \_updateGovernor

_Updates the governor address._

_Reverts if the new address is invalid (zero address)._

```solidity
function _updateGovernor(address governor_) private onlyValidAddress(governor_);
```

**Parameters**

| Name        | Type      | Description               |
| ----------- | --------- | ------------------------- |
| `governor_` | `address` | The new governor address. |

### \_updateFoundationTreasury

_Updates the foundation treasury address._

_Reverts if the new address is invalid (zero address)._

```solidity
function _updateFoundationTreasury(address foundationTreasury_) private onlyValidAddress(foundationTreasury_);
```

**Parameters**

| Name                  | Type      | Description                          |
| --------------------- | --------- | ------------------------------------ |
| `foundationTreasury_` | `address` | The new foundation treasury address. |

### \_updateKYCApprover

_Updates the KYC approver address._

_Reverts if the new address is invalid (zero address)._

```solidity
function _updateKYCApprover(address kycApprover_) private onlyValidAddress(kycApprover_);
```

**Parameters**

| Name           | Type      | Description                   |
| -------------- | --------- | ----------------------------- |
| `kycApprover_` | `address` | The new KYC approver address. |

### \_authorizeChanger

Assigns a new authorized changer.

_Allows zero address to be set to remove the current authorized changer_

```solidity
function _authorizeChanger(address authorizedChanger_) internal;
```

**Parameters**

| Name                 | Type      | Description                         |
| -------------------- | --------- | ----------------------------------- |
| `authorizedChanger_` | `address` | The new authorized changer address. |

### \_authorizeUpgrade

Authorizes an upgrade to a new contract implementation.

_Only callable by the governor._

```solidity
function _authorizeUpgrade(address newImplementation_) internal override onlyValidChanger;
```

**Parameters**

| Name                 | Type      | Description                                     |
| -------------------- | --------- | ----------------------------------------------- |
| `newImplementation_` | `address` | The address of the new implementation contract. |
