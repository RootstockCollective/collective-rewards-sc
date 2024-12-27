# GovernanceManagerRootstockCollective Access Control
This document describes the permissions, roles, and functionalities within the `GovernanceManagerRootstockCollective` contract.

## User Roles and Abilities
### Governor
- Who: Defined by the `governor` state variable.
* Abilities:
    + Execute contracts implementing the `IChangeContractRootstockCollective` interface through executeChange.
    + View validation of their role using `validateGovernor`.

### Authorized Changer
- Who: Address stored in `_authorizedChanger` or `governor`.
* Abilities:
    + Update the `governor` address using `updateGovernor`.
    + Update the `foundationTreasury` address using `updateFoundationTreasury`.
    + Update the `kycApprover` address using `updateKYCApprover`.
    + Validate their role with `validateAuthorizedChanger`.
### Authorized Upgrader
- Who: Address specified as `_authorizedChanger`, `governor`, or `upgrader`.
* Abilities:
    + Upgrade the contract implementation using `_authorizeUpgrade`.
    + Validate their role using `validateAuthorizedUpgrader`.
### KYC Approver
- Who: Defined by the `kycApprover` state variable.
* Abilities:
    + Validate the KYC approver role using `validateKycApprover`.
### Foundation Treasury
- Who: Defined by the `foundationTreasury` state variable.
* Abilities:
    + Validate their role using `validateFoundationTreasury`.
### Upgrader
- Who: Defined by the `upgrader` state variable.
* Abilities:
    + Update the upgrader address using `updateUpgrader`.

## Permissions List
### Governor
- Execute changes using `executeChange`.
- Update the `governor`, `foundationTreasury`, and `kycApprover` addresses if granted the Authorized Changer role.

### Authorized Changer
- Manage critical roles:
    + Governor through `updateGovernor`.
    + Foundation Treasury through `updateFoundationTreasury`.

### KYC Approver through updateKYCApprover.
- Authorized Upgrader
- Upgrade the contract through `_authorizeUpgrade`.

### KYC Approver
- Review and validate KYC-related transactions.

### Foundation Treasury
- Secure funds and validate treasury actions.
- 
### Upgrader
- Replace or upgrade the contract implementation.

## Events
- `ChangeExecuted(IChangeContractRootstockCollective changeContract_, address executor)`
    + Triggered when the governor executes a change contract.
- `GovernorUpdated(address newGovernor, address updater)`
    + Triggered when the governor is updated.
- `FoundationTreasuryUpdated(address newTreasury, address updater)`
    + Triggered when the foundationTreasury is updated.
- `KycApproverUpdated(address newApprover, address updater)`
    + Triggered when the kycApprover is updated.
- `UpgraderUpdated(address newUpgrader, address updater)`
    + Triggered when the upgrader is updated.

## Functions and Capabilities
### Role Management
- Governor:
    + `updateGovernor`: Assigns a new governor.
    + `validateGovernor`: Verifies if the address is the current governor.
- Authorized Changer:
    + `validateAuthorizedChanger`: Ensures the caller has the Authorized Changer role.
- Upgrader:
    + `updateUpgrader`: Assigns a new upgrader.
    + `validateAuthorizedUpgrader`: Ensures the caller can upgrade the contract.
- KYC Approver:
    + `updateKYCApprover`: Updates the KYC Approver address.
    + `validateKycApprover`: Verifies if the address is the current KYC Approver.
- Foundation Treasury:
    + `updateFoundationTreasury`: Updates the Foundation Treasury address.
    + `validateFoundationTreasury`: Verifies if the address is the Foundation Treasury.
### Contract Execution
- `executeChange(IChangeContractRootstockCollective changeContract_)`
- Allows the governor to execute contracts implementing the `IChangeContractRootstockCollective` interface.
### Upgradeable Contract
- `_authorizeUpgrade(address newImplementation_)`
- Ensures only authorized upgraders can modify the contract logic.