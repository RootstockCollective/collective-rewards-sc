// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IGovernanceManager } from "src/interfaces/IGovernanceManager.sol";

/**
 * @title GovernanceManager
 * @notice This contract manages roles
 * @dev This contract is upgradeable via the UUPS proxy pattern.
 */
contract GovernanceManager is UUPSUpgradeable, IGovernanceManager {
    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------

    modifier onlyValidAddress(address account_) {
        if (account_ == address(0)) revert InvalidAddress(account_);
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert NotGovernor();
        _;
    }

    modifier onlyChangerAdmin() {
        if (msg.sender != changerAdmin) revert NotChangerAdmin();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice The address of the governor.
    address public governor;
    /// @notice The address of the changer admin.
    address public changerAdmin;
    /// @notice The address of the changer.
    address public changer;
    /// @notice The address of the foundation treasury.
    address public foundationTreasury;
    /// @notice The address of the KYC approver.
    address public kycApprover;

    /**
     * @dev Disables initializers for the contract. This ensures the contract is upgradeable.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the initial governor, foundation treasury, and KYC approver.
     * @dev Used instead of a constructor for upgradeable contracts.
     * @param governor_ The initial governor address.
     * @param foundationTreasury_ The initial foundation treasury address.
     * @param kycApprover_ The initial KYC approver address.
     */
    function initialize(address governor_, address foundationTreasury_, address kycApprover_) public initializer {
        __UUPSUpgradeable_init();

        _updateGovernor(governor_);
        _updateFoundationTreasury(foundationTreasury_);
        _updateKYCApprover(kycApprover_);

        // GovernanceManager contract is dependency of the ChangeExecutor during construction
        // So changer admin can only be set after initialization
        changerAdmin = address(0);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice Allows the governor to update its own role to a new address.
     * @param governor_ The new governor address.
     * @dev Reverts if caller is not the current governor.
     */
    function updateGovernor(address governor_) public onlyGovernor {
        _updateGovernor(governor_);
    }

    /**
     * @notice Allows the governor to update the changer admin.
     * @param changerAdmin_ The new changer admin address.
     * @dev Only callable by the governor. Reverts if the new address is invalid.
     */
    function updateChangerAdmin(address changerAdmin_) public onlyGovernor onlyValidAddress(changerAdmin_) {
        changerAdmin = changerAdmin_;
    }

    /**
     * @notice Allows the changer admin to assign a new changer.
     * @param changer_ The new changer address.
     * @dev Only callable by the changer admin. Allows zero address to be set to prevent
     */
    function updateChanger(address changer_) public onlyChangerAdmin {
        changer = changer_;
    }

    /**
     * @notice Allows the governor to update the foundation treasury address.
     * @param foundationTreasury_ The new foundation treasury address.
     * @dev Only callable by the governor. Reverts if the new address is invalid.
     */
    function updateFoundationTreasury(address foundationTreasury_) public onlyGovernor {
        _updateFoundationTreasury(foundationTreasury_);
    }

    /**
     * @notice Allows the governor to update the KYC approver address.
     * @param kycApprover_ The new KYC approver address.
     * @dev Only callable by the governor. Reverts if the new address is invalid.
     */
    function updateKYCApprover(address kycApprover_) public onlyGovernor {
        _updateKYCApprover(kycApprover_);
    }

    /**
     * @notice Validates if an account is authorized as the governor.
     * @param account_ The address to be validated.
     * @dev Reverts with `NotGovernor` if the account is not the governor.
     */
    function validateGovernor(address account_) external view {
        if (account_ != governor) revert NotGovernor();
    }

    /**
     * @notice Validates if an account is authorized as the changer.
     * @param account_ The address to be validated.
     * @dev Reverts with `NotAuthorizedChanger` if the account is not the changer or governor.
     */
    function validateChanger(address account_) external view {
        if (account_ != changer && account_ != governor) revert NotAuthorizedChanger();
    }

    /**
     * @notice Validates if an account is authorized as the KYC approver.
     * @param account_ The address to be validated.
     * @dev Reverts with `NotKycApprover` if the account is not the KYC approver.
     */
    function validateKycApprover(address account_) external view {
        if (account_ != kycApprover) revert NotKycApprover();
    }

    /**
     * @notice Validates if the caller is the foundation treasury.
     * @dev Reverts with `NotFoundationTreasury` if the caller is not the foundation treasury.
     */
    function validateFoundationTreasury(address account_) external view {
        if (account_ != foundationTreasury) revert NotFoundationTreasury();
    }

    /**
     * @notice Validates if the caller is the changer admin.
     * @dev Reverts with `NotChangerAdmin` if the caller is not the changer admin.
     */
    function validateChangerAdmin(address account_) public view {
        if (account_ != changerAdmin) revert NotChangerAdmin();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @dev Updates the governor address.
     * @param governor_ The new governor address.
     * @dev Reverts if the new address is invalid (zero address).
     */
    function _updateGovernor(address governor_) private onlyValidAddress(governor_) {
        governor = governor_;
    }

    /**
     * @dev Updates the foundation treasury address.
     * @param foundationTreasury_ The new foundation treasury address.
     * @dev Reverts if the new address is invalid (zero address).
     */
    function _updateFoundationTreasury(address foundationTreasury_) private onlyValidAddress(foundationTreasury_) {
        foundationTreasury = foundationTreasury_;
    }

    /**
     * @dev Updates the KYC approver address.
     * @param kycApprover_ The new KYC approver address.
     * @dev Reverts if the new address is invalid (zero address).
     */
    function _updateKYCApprover(address kycApprover_) private onlyValidAddress(kycApprover_) {
        kycApprover = kycApprover_;
    }

    /**
     * @notice Authorizes an upgrade to a new contract implementation.
     * @param newImplementation_ The address of the new implementation contract.
     * @dev Only callable by the governor.
     */
    function _authorizeUpgrade(address newImplementation_) internal override onlyGovernor { }
}
