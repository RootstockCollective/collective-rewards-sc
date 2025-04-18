// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IChangeContractRootstockCollective } from "src/interfaces/IChangeContractRootstockCollective.sol";

/**
 * @title IGovernanceManagerRootstockCollective
 */
interface IGovernanceManagerRootstockCollective {
    // -----------------------------
    // ---------- Events -----------
    // -----------------------------
    event GovernorUpdated(address governor_, address updatedBy_);
    event FoundationTreasuryUpdated(address foundationTreasury_, address updatedBy_);
    event KycApproverUpdated(address kycApprover_, address updatedBy_);
    event UpgraderUpdated(address upgrader_, address updatedBy_);
    event ChangeExecuted(IChangeContractRootstockCollective changeContract_, address executor_);

    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    /**
     * @notice Thrown when a zero address is provided.
     */
    error ZeroAddressNotAllowed();

    /**
     * @notice Thrown when the caller is not authorized as a changer.
     */
    error NotAuthorizedChanger();

    /**
     * @notice Thrown when the caller is not the foundation treasury.
     */
    error NotFoundationTreasury();

    /**
     * @notice Thrown when the caller is not the governor.
     */
    error NotGovernor();

    /**
     * @notice Thrown when the caller is not the KYC approver.
     */
    error NotKycApprover();

    /**
     * @notice Thrown when the caller is not authorized to upgrade the contracts
     */
    error NotAuthorizedUpgrader();

    /**
     * @notice Thrown when the caller is not the upgrader.
     */
    error NotUpgrader();

    // -----------------------------
    // --------- Functions ---------
    // -----------------------------
    /**
     * @notice Initializes the contract with the initial governor, foundation treasury, and KYC approver.
     * @dev Used instead of a constructor for upgradeable contracts.
     * @param governor_ The initial governor address.
     * @param foundationTreasury_ The initial foundation treasury address.
     * @param kycApprover_ account responsible of approving Builder's Know you Costumer policies and Legal requirements
     * @param upgrader_ The initial upgrader address.
     */
    function initialize(
        address governor_,
        address foundationTreasury_,
        address kycApprover_,
        address upgrader_
    )
        external;

    /**
     * @notice Function to be called to execute the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function executeChange(IChangeContractRootstockCollective changeContract_) external;

    /**
     * @notice Returns the address of the current governor.
     * @return The governor address.
     */
    function governor() external view returns (address);

    /**
     * @notice Returns the address of the foundation treasury.
     * @return The foundation treasury address.
     */
    function foundationTreasury() external view returns (address);

    /**
     * @notice Returns the address of the KYC approver.
     * @return The KYC approver address.
     */
    function kycApprover() external view returns (address);

    /**
     * @notice The upgrader address with contract upgradeability permissions.
     * @return The upgrader address.
     */
    function upgrader() external view returns (address);

    /**
     * @notice Validates if the given account is authorized as a changer
     * @param account_ The address to be validated as the changer.
     * @dev Reverts with `NotAuthorizedChanger` if the account is not the authorized changer.
     */
    function validateAuthorizedChanger(address account_) external view;

    /**
     * @notice Validates if the given account is authorized as the governor.
     * @param account_ The address to be validated as the governor.
     * @dev Reverts with `NotGovernor` if the account is not the governor.
     */
    function validateGovernor(address account_) external view;

    /**
     * @notice Validates if the given account is authorized as the KYC approver.
     * @param account_ The address to be validated as the KYC approver.
     * @dev Reverts with `NotKycApprover` if the account is not the KYC approver.
     */
    function validateKycApprover(address account_) external view;

    /**
     * @notice Validates if the given account is the foundation treasury.
     * @param account_ The address to be validated as the foundation treasury.
     * @dev Reverts with `NotFoundationTreasury` if the caller is not the foundation treasury.
     */
    function validateFoundationTreasury(address account_) external view;

    /**
     * @notice Validates if the given account is authorized to upgrade the contracts.
     * @param account_ The address to be validated.
     * @dev Reverts with `NotAuthorizedUpgrader` if the account is not the upgrader.
     */
    function validateAuthorizedUpgrader(address account_) external view;

    /**
     * @notice Updates the governor address
     * @param governor_ The new governor address.
     * @dev Reverts if caller is not a valid changer.
     * @dev Reverts if the new address is zero.
     */
    function updateGovernor(address governor_) external;

    /**
     * @notice Updates the foundation treasury address
     * @param foundationTreasury_ The new foundation treasury address.
     * @dev Reverts if caller is not a valid changer.
     * @dev Reverts if the new address is zero.
     */
    function updateFoundationTreasury(address foundationTreasury_) external;

    /**
     * @notice Updates the KYC approver address
     * @param kycApprover_ The new address to be set as the KYC approver.
     * @dev Reverts if caller is not a valid changer.
     * @dev Reverts if the new address is zero.
     */
    function updateKYCApprover(address kycApprover_) external;

    /**
     * @notice Validates if the given account is authorized as a changer
     * @param account_ The address to be validated as the changer.
     * @dev Reverts with `NotAuthorizedChanger` if the account is not the authorized changer.
     */
    function isAuthorizedChanger(address account_) external view returns (bool);

    /**
     * @dev Updates the account authorized to upgrade the contracts
     * @param upgrader_ The new upgrader address.
     * @dev Reverts if caller is the upgrader.
     * @dev allow update to zero address to disable the upgrader role
     */
    function updateUpgrader(address upgrader_) external;
}
