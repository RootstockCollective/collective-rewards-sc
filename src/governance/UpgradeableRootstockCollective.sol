// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

/**
 * @title UpgradeableRootstockCollective
 * @notice Base contract to be inherited by governed contracts
 * @dev This contract is not usable on its own since it does not have any _productive useful_ behavior
 * The only purpose of this contract is to define some useful modifiers and functions to be used on the
 * governance aspect of the child contract
 */
abstract contract UpgradeableRootstockCollective is UUPSUpgradeable {
    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyValidChanger() {
        governanceManager.validateAuthorizedChanger(msg.sender);
        _;
    }

    modifier onlyAuthorizedUpgrader() {
        governanceManager.validateAuthorizedUpgrader(msg.sender);
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    IGovernanceManagerRootstockCollective public governanceManager;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param governanceManager_ contract with permissioned roles
     */
    /* solhint-disable-next-line func-name-mixedcase */
    function __Upgradeable_init(IGovernanceManagerRootstockCollective governanceManager_) internal onlyInitializing {
        __UUPSUpgradeable_init();
        governanceManager = governanceManager_;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev checks that the changer that will do the upgrade is currently authorized by governance to makes
     * changes within the system
     */
    function _authorizeUpgrade(address) internal override onlyAuthorizedUpgrader { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
