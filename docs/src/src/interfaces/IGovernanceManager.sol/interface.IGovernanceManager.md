# IGovernanceManager

[Git Source](https://github.com/rsksmart/collective-rewards-sc/blob/ae40e66d2b99b4caf83133f94d38374097b51ea3/src/interfaces/IGovernanceManager.sol)

## Functions

### initialize

Initializes the contract with the initial governor, foundation treasury, and KYC approver.

_Used instead of a constructor for upgradeable contracts._

```solidity
function initialize(address governor_, address foundationTreasury_, address kycApprover_) external;
```

**Parameters**

| Name                  | Type      | Description                                                                                  |
| --------------------- | --------- | -------------------------------------------------------------------------------------------- |
| `governor_`           | `address` | The initial governor address.                                                                |
| `foundationTreasury_` | `address` | The initial foundation treasury address.                                                     |
| `kycApprover_`        | `address` | account responsible of approving Builder's Know you Costumer policies and Legal requirements |

### executeChange

Function to be called to make the changes in changeContract

_reverts if is not called by the Governor_

```solidity
function executeChange(IChangeContractRootstockCollective changeContract_) external;
```

**Parameters**

| Name              | Type                                 | Description                                           |
| ----------------- | ------------------------------------ | ----------------------------------------------------- |
| `changeContract_` | `IChangeContractRootstockCollective` | Address of the contract that will execute the changes |

### governor

Returns the address of the current governor.

```solidity
function governor() external view returns (address);
```

**Returns**

| Name     | Type      | Description           |
| -------- | --------- | --------------------- |
| `<none>` | `address` | The governor address. |

### foundationTreasury

Returns the address of the foundation treasury.

```solidity
function foundationTreasury() external view returns (address);
```

**Returns**

| Name     | Type      | Description                      |
| -------- | --------- | -------------------------------- |
| `<none>` | `address` | The foundation treasury address. |

### kycApprover

Returns the address of the KYC approver.

```solidity
function kycApprover() external view returns (address);
```

**Returns**

| Name     | Type      | Description               |
| -------- | --------- | ------------------------- |
| `<none>` | `address` | The KYC approver address. |

### validateChanger

Validates if the given account is authorized as a changer

_Reverts with `NotAuthorizedChanger` if the account is not the authorized changer._

```solidity
function validateChanger(address account_) external view;
```

**Parameters**

| Name       | Type      | Description                                 |
| ---------- | --------- | ------------------------------------------- |
| `account_` | `address` | The address to be validated as the changer. |

### validateGovernor

Validates if the given account is authorized as the governor.

_Reverts with `NotGovernor` if the account is not the governor._

```solidity
function validateGovernor(address account_) external view;
```

**Parameters**

| Name       | Type      | Description                                  |
| ---------- | --------- | -------------------------------------------- |
| `account_` | `address` | The address to be validated as the governor. |

### validateKycApprover

Validates if the given account is authorized as the KYC approver.

_Reverts with `NotKycApprover` if the account is not the KYC approver._

```solidity
function validateKycApprover(address account_) external view;
```

**Parameters**

| Name       | Type      | Description                                      |
| ---------- | --------- | ------------------------------------------------ |
| `account_` | `address` | The address to be validated as the KYC approver. |

### validateFoundationTreasury

Validates if the given account is the foundation treasury.

_Reverts with `NotFoundationTreasury` if the account is not the foundation treasury._

```solidity
function validateFoundationTreasury(address account_) external view;
```

**Parameters**

| Name       | Type      | Description                                             |
| ---------- | --------- | ------------------------------------------------------- |
| `account_` | `address` | The address to be validated as the foundation treasury. |

### updateGovernor

Updates the governor

_Only callable by the current governor. Reverts with `NotGovernor` if called by someone else._

```solidity
function updateGovernor(address newGovernor_) external;
```

**Parameters**

| Name           | Type      | Description                                |
| -------------- | --------- | ------------------------------------------ |
| `newGovernor_` | `address` | The new address to be set as the governor. |

### updateFoundationTreasury

Updates the foundation treasury

_Only callable by the governor. Reverts with `NotGovernor` if called by someone else._

```solidity
function updateFoundationTreasury(address foundationTreasury_) external;
```

**Parameters**

| Name                  | Type      | Description                                           |
| --------------------- | --------- | ----------------------------------------------------- |
| `foundationTreasury_` | `address` | The new address to be set as the foundation treasury. |

### updateKYCApprover

Updates the KYC approver

_Only callable by the governor. Reverts with `NotGovernor` if called by someone else._

```solidity
function updateKYCApprover(address kycApprover_) external;
```

**Parameters**

| Name           | Type      | Description                                    |
| -------------- | --------- | ---------------------------------------------- |
| `kycApprover_` | `address` | The new address to be set as the KYC approver. |

## Errors

### InvalidAddress

Thrown when an invalid address is provided.

```solidity
error InvalidAddress(address account_);
```

**Parameters**

| Name       | Type      | Description                   |
| ---------- | --------- | ----------------------------- |
| `account_` | `address` | The invalid address provided. |

### NotAuthorizedChanger

Thrown when the caller is not authorized as a changer.

```solidity
error NotAuthorizedChanger();
```

### NotFoundationTreasury

Thrown when the caller is not the foundation treasury.

```solidity
error NotFoundationTreasury();
```

### NotGovernor

Thrown when the caller is not the governor.

```solidity
error NotGovernor();
```

### NotKycApprover

Thrown when the caller is not the KYC approver.

```solidity
error NotKycApprover();
```
