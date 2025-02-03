# IGovernanceManagerRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/99cb2d8ed5962fe0d1a12a5277c2e7b1068aeff8/src/interfaces/IGovernanceManagerRootstockCollective.sol)


## Functions
### initialize

Initializes the contract with the initial governor, foundation treasury, and KYC approver.

*Used instead of a constructor for upgradeable contracts.*


```solidity
function initialize(address governor_, address foundationTreasury_, address kycApprover_, address upgrader_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`governor_`|`address`|The initial governor address.|
|`foundationTreasury_`|`address`|The initial foundation treasury address.|
|`kycApprover_`|`address`|account responsible of approving Builder's Know you Costumer policies and Legal requirements|
|`upgrader_`|`address`|The initial upgrader address.|


### executeChange

Function to be called to execute the changes in changeContract

*reverts if is not called by the Governor*


```solidity
function executeChange(IChangeContractRootstockCollective changeContract_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`changeContract_`|`IChangeContractRootstockCollective`|Address of the contract that will execute the changes|


### governor

Returns the address of the current governor.


```solidity
function governor() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The governor address.|


### foundationTreasury

Returns the address of the foundation treasury.


```solidity
function foundationTreasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The foundation treasury address.|


### kycApprover

Returns the address of the KYC approver.


```solidity
function kycApprover() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The KYC approver address.|


### validateAuthorizedChanger

Validates if the given account is authorized as a changer

*Reverts with `NotAuthorizedChanger` if the account is not the authorized changer.*


```solidity
function validateAuthorizedChanger(address account_) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account_`|`address`|The address to be validated as the changer.|


### validateGovernor

Validates if the given account is authorized as the governor.

*Reverts with `NotGovernor` if the account is not the governor.*


```solidity
function validateGovernor(address account_) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account_`|`address`|The address to be validated as the governor.|


### validateKycApprover

Validates if the given account is authorized as the KYC approver.

*Reverts with `NotKycApprover` if the account is not the KYC approver.*


```solidity
function validateKycApprover(address account_) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account_`|`address`|The address to be validated as the KYC approver.|


### validateFoundationTreasury

Validates if the given account is the foundation treasury.

*Reverts with `NotFoundationTreasury` if the caller is not the foundation treasury.*


```solidity
function validateFoundationTreasury(address account_) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account_`|`address`|The address to be validated as the foundation treasury.|


### validateAuthorizedUpgrader

Validates if the given account is authorized to upgrade the contracts.

*Reverts with `NotAuthorizedUpgrader` if the account is not the upgrader.*


```solidity
function validateAuthorizedUpgrader(address account_) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account_`|`address`|The address to be validated.|


### updateGovernor

Updates the governor address

*Reverts if caller is not a valid changer.*

*Reverts if the new address is zero.*


```solidity
function updateGovernor(address governor_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`governor_`|`address`|The new governor address.|


### updateFoundationTreasury

Updates the foundation treasury address

*Reverts if caller is not a valid changer.*

*Reverts if the new address is zero.*


```solidity
function updateFoundationTreasury(address foundationTreasury_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`foundationTreasury_`|`address`|The new foundation treasury address.|


### updateKYCApprover

Updates the KYC approver address

*Reverts if caller is not a valid changer.*

*Reverts if the new address is zero.*


```solidity
function updateKYCApprover(address kycApprover_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`kycApprover_`|`address`|The new address to be set as the KYC approver.|


### isAuthorizedChanger

Validates if the given account is authorized as a changer

*Reverts with `NotAuthorizedChanger` if the account is not the authorized changer.*


```solidity
function isAuthorizedChanger(address account_) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account_`|`address`|The address to be validated as the changer.|


### updateUpgrader

*Updates the account authorized to upgrade the contracts*

*Reverts if caller is the upgrader.*

*allow update to zero address to disable the upgrader role*


```solidity
function updateUpgrader(address upgrader_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`upgrader_`|`address`|The new upgrader address.|


## Events
### GovernorUpdated

```solidity
event GovernorUpdated(address governor_, address updatedBy_);
```

### FoundationTreasuryUpdated

```solidity
event FoundationTreasuryUpdated(address foundationTreasury_, address updatedBy_);
```

### KycApproverUpdated

```solidity
event KycApproverUpdated(address kycApprover_, address updatedBy_);
```

### UpgraderUpdated

```solidity
event UpgraderUpdated(address upgrader_, address updatedBy_);
```

### ChangeExecuted

```solidity
event ChangeExecuted(IChangeContractRootstockCollective changeContract_, address executor_);
```

## Errors
### InvalidAddress
Thrown when an invalid address is provided.


```solidity
error InvalidAddress(address account_);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account_`|`address`|The invalid address provided.|

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

### NotAuthorizedUpgrader
Thrown when the caller is not authorized to upgrade the contracts


```solidity
error NotAuthorizedUpgrader();
```

### NotUpgrader
Thrown when the caller is not the upgrader.


```solidity
error NotUpgrader();
```

