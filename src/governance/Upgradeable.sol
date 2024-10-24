// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IGoverned } from "src/interfaces/IGoverned.sol";

/**
 * @title Upgradeable
 * @notice Base contract to be inherited by governed contracts
 * @dev This contract is not usable on its own since it does not have any _productive useful_ behavior
 * The only purpose of this contract is to define some useful modifiers and functions to be used on the
 * governance aspect of the child contract
 */
abstract contract Upgradeable is UUPSUpgradeable {
    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyValidChanger() {
        _governed.validateChanger(msg.sender);
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    IGoverned internal _governed;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param governed_ contract with permissioned roles
     */
    /* solhint-disable-next-line func-name-mixedcase */
    function __Upgradeable_init(IGoverned governed_) internal onlyInitializing {
        __UUPSUpgradeable_init();
        _governed = governed_;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev checks that the changer that will do the upgrade is currently authorized by governance to makes
     * changes within the system
     */
    function _authorizeUpgrade(address) internal override onlyValidChanger { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
