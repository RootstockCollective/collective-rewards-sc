# GovernanceManagerRootstockCollective.sol
You can find bellow the permissions, roles, and functionalities within the `GovernanceManagerRootstockCollective` contract.

## User Roles and Permissions
### Governor
- Who: Defined by the `governor` state variable.
- Permissions and Capabilities:
    + Can call `Execute` from contracts implementing the `IChangeContractRootstockCollective` interface through `executeChange`.
    + Validate if actual caller is the governor using `validateGovernor`.
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

### Configurator
- Who: Defined by the `configurator` state variable.
- Permissions and Capabilities:
    + Update the configurator address using `updateConfigurator`.
    + Set some protocol parameters:
        - `maxDistributionsPerBatch`.

# BuilderRegistryRootstockCollective.sol
You can find bellow the permissions, roles, and functionalities within the `BuilderRegistryRootstockCollective` contract.  This also contains some definitions within `CycleTimeKeeperRootstockCollective` contract.

## User Roles and Permissions
### KYC Approver
- Who: Defined by the `kycApprover` state variable in the `GovernanceManagerRootstockCollective` contract.
- Permissions and Capabilities:
    + Approve builder's KYC using `approveBuilderKYC`.
    + Revoke builder's KYC using `revokeBuilderKYC`.
    + Approve builder's new reward receiver using `approveNewRewardReceiver`.
    + Pause and unpause builder KYC using `pauseBuilderKYC` and `unpauseBuilderKYC`.
    + Initialize builder using `initializeBuilder`.
    + Migrate builder using `migrateBuilder`.

### Authorized Changer
- Who: Address stored in `_authorizedChanger` in the `GovernanceManagerRootstockCollective` contract.  Follow the path: BuilderRegistry -> CycleTimeKeeper -> UpgradeableRootstockCollective
- Permissions and Capabilities:
    + Community approve builder using `communityApproveBuilder`.
    + Ban builder permanently using `communityBanBuilder`.
    + Schedule a new cycle duration using `setCycleDuration`. Defined at `CycleTimeKeeperRootstockCollective.sol`

### Foundation Treasury
- Who: Defined by the `foundationTreasury` state variable in the `GovernanceManagerRootstockCollective` contract.
- Permissions and Capabilities:
    + Set the duration of the distribution window using `setDistributionDuration`.  Defined at `CycleTimeKeeperRootstockCollective.sol`

**Obs.: GovernanceManagerRootstockCollective instance is loaded in the init function**

# RewardDistributorRootstockCollective.sol
You can find below the permissions, roles, and functionalities within the `RewardDistributorRootstockCollective` contract.

## User Roles and Permissions
### Foundation Treasury
- Who: Defined by the `foundationTreasury` state variable in the `GovernanceManagerRootstockCollective` contract.
- Permissions and Capabilities:
    + Send rewards to the `backersManager` contract using `sendRewards`.
    + Send rewards and start distribution using `sendRewardsAndStartDistribution`.
    + Set the default reward amounts using `setDefaultRewardAmount`.
    + Send rewards with default amounts using `sendRewardsWithDefaultAmount`.
    + Send rewards and start distribution with default amounts using `sendRewardsAndStartDistributionWithDefaultAmount`.

# GaugeRootstockCollective.sol
You can find below the permissions, roles, and functionalities within the `GaugeRootstockCollective` contract.

## User Roles and Permissions
### Backers Manager
- Who: Defined by the `backersManager` state variable.
- Permissions and Capabilities:
    + Allocate staking tokens using `allocate`.
    + Notify reward amount and update shares using `notifyRewardAmountAndUpdateShares`.
    + Move builder unclaimed rewards using `moveBuilderUnclaimedRewards`.
    + Claim backer rewards using `claimBackerReward`.
    + Claim builder rewards using `claimBuilderReward`.

### Backer
- Who: Address registered as a backer.
- Permissions and Capabilities:
    + Claim backer rewards using `claimBackerReward`.

### Builder
- Who: Address registered as a builder.
- Permissions and Capabilities:
    + Claim builder rewards using `claimBuilderReward`.
