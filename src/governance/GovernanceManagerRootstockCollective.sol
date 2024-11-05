// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { IChangeContractRootstockCollective } from "src/interfaces/IChangeContractRootstockCollective.sol";

/**
 * @title GovernanceManagerRootstockCollective
 * @notice This contract manages governance addresses.
 * @notice It also allows the governor to execute contracts that implement the IChangeContractRootstockCollective
 * interface.
 * @dev This contract is upgradeable via the UUPS proxy pattern.
 */
contract GovernanceManagerRootstockCollective is UUPSUpgradeable, IGovernanceManagerRootstockCollective {
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

    modifier onlyValidChanger() {
        validateChanger(msg.sender);
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice The address of the governor.
    address public governor;
    /// @notice The address of the authorized changer.
    address internal _authorizedChanger;
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
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice Function to be called to make the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function executeChange(IChangeContractRootstockCollective changeContract_) external onlyGovernor {
        _authorizeChanger(address(changeContract_));
        changeContract_.execute();
        _authorizeChanger(address(0));
    }

    /**
     * @notice Allows the governor to update its own role to a new address.
     * @param governor_ The new governor address.
     * @dev Reverts if caller is not the current governor.
     */
    function updateGovernor(address governor_) public onlyValidChanger {
        _updateGovernor(governor_);
    }

    /**
     * @notice Allows the governor to update the foundation treasury address.
     * @param foundationTreasury_ The new foundation treasury address.
     * @dev Only callable by the governor. Reverts if the new address is invalid.
     */
    function updateFoundationTreasury(address foundationTreasury_) public onlyValidChanger {
        _updateFoundationTreasury(foundationTreasury_);
    }

    /**
     * @notice Allows the governor to update the KYC approver address.
     * @param kycApprover_ The new KYC approver address.
     * @dev Only callable by the governor. Reverts if the new address is invalid.
     */
    function updateKYCApprover(address kycApprover_) public onlyValidChanger {
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
     * @notice Validates if an account is authorized to perform changes.
     * @param account_ The address to be validated.
     * @dev Reverts with `NotAuthorizedChanger` if the account is not the authorized changer or governor.
     */
    function validateChanger(address account_) public view {
        if (account_ != _authorizedChanger && account_ != governor) revert NotAuthorizedChanger();
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
     * @notice Assigns a new authorized changer.
     * @param authorizedChanger_ The new authorized changer address.
     * @dev Allows zero address to be set to remove the current authorized changer
     */
    function _authorizeChanger(address authorizedChanger_) internal {
        _authorizedChanger = authorizedChanger_;
    }

    /**
     * @notice Authorizes an upgrade to a new contract implementation.
     * @param newImplementation_ The address of the new implementation contract.
     * @dev Only callable by the governor.
     */
    function _authorizeUpgrade(address newImplementation_) internal override onlyValidChanger { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
