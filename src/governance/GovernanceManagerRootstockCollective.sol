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
 * @dev Complete documentation is provided in the IGovernanceManagerRootstockCollective interface
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

    modifier onlyAuthorizedUpgrader() {
        validateAuthorizedUpgrader(msg.sender);
        _;
    }

    modifier onlyAuthorizedChanger() {
        validateAuthorizedChanger(msg.sender);
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
    /// @notice The upgrader address with contract upgradeability permissions
    address public upgrader;

    /**
     * @dev Disables initializers for the contract. This ensures the contract is upgradeable.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address governor_,
        address foundationTreasury_,
        address kycApprover_,
        address upgrader_
    )
        public
        initializer
    {
        __UUPSUpgradeable_init();

        _updateGovernor(governor_);
        _updateFoundationTreasury(foundationTreasury_);
        _updateKYCApprover(kycApprover_);
        _updateUpgrader(upgrader_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    function executeChange(IChangeContractRootstockCollective changeContract_) external onlyGovernor {
        _authorizeChanger(address(changeContract_));
        changeContract_.execute();
        _authorizeChanger(address(0));

        emit ChangeExecuted(changeContract_, msg.sender);
    }

    function updateGovernor(address governor_) public onlyAuthorizedChanger {
        _updateGovernor(governor_);
    }

    function updateFoundationTreasury(address foundationTreasury_) public onlyAuthorizedChanger {
        _updateFoundationTreasury(foundationTreasury_);
    }

    function updateKYCApprover(address kycApprover_) public onlyAuthorizedChanger {
        _updateKYCApprover(kycApprover_);
    }

    function updateUpgrader(address upgrader_) public {
        if (msg.sender != upgrader) revert NotUpgrader();
        _updateUpgrader(upgrader_);
    }

    function validateGovernor(address account_) external view {
        if (account_ != governor) revert NotGovernor();
    }

    function validateAuthorizedChanger(address account_) public view {
        if (!isAuthorizedChanger(account_)) revert NotAuthorizedChanger();
    }

    function validateAuthorizedUpgrader(address account_) public view {
        if (account_ != _authorizedChanger && account_ != governor && account_ != upgrader) {
            revert NotAuthorizedUpgrader();
        }
    }

    function validateKycApprover(address account_) external view {
        if (account_ != kycApprover) revert NotKycApprover();
    }

    function validateFoundationTreasury(address account_) external view {
        if (account_ != foundationTreasury) revert NotFoundationTreasury();
    }

    function isAuthorizedChanger(address account_) public view returns (bool) {
        return account_ == _authorizedChanger || account_ == governor;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    function _updateGovernor(address governor_) private onlyValidAddress(governor_) {
        governor = governor_;
        emit GovernorUpdated(governor_, msg.sender);
    }

    function _updateFoundationTreasury(address foundationTreasury_) private onlyValidAddress(foundationTreasury_) {
        foundationTreasury = foundationTreasury_;
        emit FoundationTreasuryUpdated(foundationTreasury_, msg.sender);
    }

    function _updateKYCApprover(address kycApprover_) private onlyValidAddress(kycApprover_) {
        kycApprover = kycApprover_;
        emit KycApproverUpdated(kycApprover_, msg.sender);
    }

    function _updateUpgrader(address upgrader_) private {
        upgrader = upgrader_;
        emit UpgraderUpdated(upgrader_, msg.sender);
    }

    function _authorizeChanger(address authorizedChanger_) internal {
        _authorizedChanger = authorizedChanger_;
    }

    function _authorizeUpgrade(address newImplementation_) internal override onlyAuthorizedUpgrader { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
