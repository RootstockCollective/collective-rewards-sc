# GovernanceManagerRootstockCollective Access Control
This document describes the permissions, roles, and functionalities within the `GovernanceManagerRootstockCollective` contract.

## User Roles and Permissions
### Governor
- Who: Defined by the `governor` state variable.
- Permissions and Capabilities:
    + Execute contracts implementing the `IChangeContractRootstockCollective` interface through `executeChange`.
    + View validation of their role using `validateGovernor`.
    + Update the `governor`, `foundationTreasury`, and `kycApprover` addresses if granted the Authorized Changer role.

### Authorized Changer
- Who: Address stored in `_authorizedChanger` or `governor`.
- Permissions and Capabilities:
    + Update the `governor` address using `updateGovernor`.
    + Update the `foundationTreasury` address using `updateFoundationTreasury`.
    + Update the `kycApprover` address using `updateKYCApprover`.
    + Validate their role with `validateAuthorizedChanger`.

### Authorized Upgrader
- Who: Address specified as `_authorizedChanger`, `governor`, or `upgrader`.
- Permissions and Capabilities:
    + Upgrade the contract implementation using `_authorizeUpgrade`.
    + Validate their role using `validateAuthorizedUpgrader`.

### KYC Approver
- Who: Defined by the `kycApprover` state variable.
- Permissions and Capabilities:
    + Validate the KYC approver role using `validateKycApprover`.
    + Review and validate KYC-related transactions.

### Foundation Treasury
- Who: Defined by the `foundationTreasury` state variable.
- Permissions and Capabilities:
    + Validate their role using `validateFoundationTreasury`.
    + Secure funds and validate treasury actions.

### Upgrader
- Who: Defined by the `upgrader` state variable.
- Permissions and Capabilities:
    + Update the upgrader address using `updateUpgrader`.
    + Replace or upgrade the contract implementation.

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