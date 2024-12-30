# GovernanceManagerRootstockCollective.sol
You can find bellow the permissions, roles, and functionalities within the `GovernanceManagerRootstockCollective` contract.

## User Roles and Permissions
### Governor
- Who: Defined by the `governor` state variable.
- Permissions and Capabilities:
    + Can call `Execute` from contracts implementing the `IChangeContractRootstockCollective` interface through `executeChange`.
    + View validation of their role using `validateGovernor`.
    + Upgrade the contract as defined in `validateAuthorizedUpgrader` function.
    + Update the `governor`, `foundationTreasury`, and `kycApprover` addresses as defined in `isAuthorizedChanger` function.

### Authorized Changer
- Who: Address stored in `_authorizedChanger`.
- Permissions and Capabilities:
    + Upgrade the contract as defined in `validateAuthorizedUpgrader`.
    + Update the `governor` address using `updateGovernor`.
    + Update the `foundationTreasury` address using `updateFoundationTreasury`.
    + Update the `kycApprover` address using `updateKYCApprover`.
    + Validate their role with `validateAuthorizedChanger`.

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

# BuilderRegistryRootstockCollective.sol
You can find bellow the permissions, roles, and functionalities within the `BuilderRegistryRootstockCollective` contract.  This also contains some definitions within `CycleTimeKeeperRootstockCollective` contract.

## User Roles and Permissions
### KYC Approver
- Who: Defined by the `kycApprover` state variable in the `GovernanceManagerRootstockCollective` contract.
- Permissions and Capabilities:
    + Approve builder's KYC using `approveBuilderKYC`.
    + Revoke builder's KYC using `revokeBuilderKYC`.
    + Approve builder's reward receiver replacement using `approveBuilderRewardReceiverReplacement`.
    + Activate builder using `activateBuilder`.
    + Pause and unpause builder using `pauseBuilder` and `unpauseBuilder`.
    + Migrate builder using `migrateBuilder`.

### Authorized Changer
- Who: Address stored in `_authorizedChanger` in the `GovernanceManagerRootstockCollective` contract.  Follow the path: BuilderRegistry -> CycleTimeKeeper -> UpgradeableRootstockCollective
- Permissions and Capabilities:
    + Community approve builder using `communityApproveBuilder`.
    + Dewhitelist builder using `dewhitelistBuilder`.
    + Schedule a new cycle duration using `setCycleDuration`. Defined at `CycleTimeKeeperRootstockCollective.sol`

### Foundation Treasury
- Who: Defined by the `foundationTreasury` state variable in the `GovernanceManagerRootstockCollective` contract.
- Permissions and Capabilities:
    + Set the duration of the distribution window using `setDistributionDuration`.  Defined at `CycleTimeKeeperRootstockCollective.sol`

**Obs.: GovernanceManagerRootstockCollective instance is loaded in the init function**

## Events
- `BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_)`
    + Triggered when a builder is activated.
- `KYCApproved(address indexed builder_)`
    + Triggered when a builder's KYC is approved.
- `KYCRevoked(address indexed builder_)`
    + Triggered when a builder's KYC is revoked.
- `CommunityApproved(address indexed builder_)`
    + Triggered when a builder is community approved.
- `Dewhitelisted(address indexed builder_)`
    + Triggered when a builder is dewhitelisted.
- `Paused(address indexed builder_, bytes20 reason_)`
    + Triggered when a builder is paused.
- `Unpaused(address indexed builder_)`
    + Triggered when a builder is unpaused.
- `Revoked(address indexed builder_)`
    + Triggered when a builder is revoked.
- `Permitted(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_)`
    + Triggered when a builder is permitted.
- `BackerRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_)`
    + Triggered when a builder's backer reward percentage update is scheduled.
- `BuilderRewardReceiverReplacementRequested(address indexed builder_, address newRewardReceiver_)`
    + Triggered when a builder requests a reward receiver replacement.
- `BuilderRewardReceiverReplacementCancelled(address indexed builder_, address newRewardReceiver_)`
    + Triggered when a builder cancels a reward receiver replacement request.
- `BuilderRewardReceiverReplacementApproved(address indexed builder_, address newRewardReceiver_)`
    + Triggered when a builder's reward receiver replacement is approved.
- `GaugeCreated(address indexed builder_, address indexed gauge_, address creator_)`
    + Triggered when a gauge is created for a builder.
- `BuilderMigrated(address indexed builder_, address indexed migrator_)`
    + Triggered when a builder is migrated.
- `NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_)`
    + Triggered when a new cycle duration is scheduled. Defined at `CycleTimeKeeperRootstockCollective.sol`
- `NewDistributionDuration(uint256 newDistributionDuration_, address by_)`
    + Triggered when a new distribution duration is set. Defined at `CycleTimeKeeperRootstockCollective.sol`
