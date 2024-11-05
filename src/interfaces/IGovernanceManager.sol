// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IChangeContractRootstockCollective } from "src/interfaces/IChangeContractRootstockCollective.sol";

/**
 * @title IGovernanceManager
 */
interface IGovernanceManager {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    /**
     * @notice Thrown when an invalid address is provided.
     * @param account_ The invalid address provided.
     */
    error InvalidAddress(address account_);

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

    // -----------------------------
    // --------- Functions ---------
    // -----------------------------
    /**
     * @notice Initializes the contract with the initial governor, foundation treasury, and KYC approver.
     * @dev Used instead of a constructor for upgradeable contracts.
     * @param governor_ The initial governor address.
     * @param foundationTreasury_ The initial foundation treasury address.
     * @param kycApprover_ account responsible of approving Builder's Know you Costumer policies and Legal requirements
     */
    function initialize(address governor_, address foundationTreasury_, address kycApprover_) external;

    /**
     * @notice Function to be called to make the changes in changeContract
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
     * @notice Returns the address of the current changer.
     * @return The changer address.
     */
    function changer() external view returns (address);

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
     * @notice Validates if the given account is authorized as a changer
     * @param account_ The address to be validated as the changer.
     * @dev Reverts with `NotAuthorizedChanger` if the account is not the authorized changer.
     */
    function validateChanger(address account_) external view;

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
     * @dev Reverts with `NotFoundationTreasury` if the account is not the foundation treasury.
     */
    function validateFoundationTreasury(address account_) external view;

    /**
     * @notice Updates the governor
     * @param newGovernor_ The new address to be set as the governor.
     * @dev Only callable by the current governor. Reverts with `NotGovernor` if called by someone else.
     */
    function updateGovernor(address newGovernor_) external;

    /**
     * @notice Updates the foundation treasury
     * @param foundationTreasury_ The new address to be set as the foundation treasury.
     * @dev Only callable by the governor. Reverts with `NotGovernor` if called by someone else.
     */
    function updateFoundationTreasury(address foundationTreasury_) external;

    /**
     * @notice Updates the KYC approver
     * @param kycApprover_ The new address to be set as the KYC approver.
     * @dev Only callable by the governor. Reverts with `NotGovernor` if called by someone else.
     */
    function updateKYCApprover(address kycApprover_) external;
}
