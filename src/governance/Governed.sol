// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ChangeExecutor } from "./ChangeExecutor.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Governed
 * @notice Base contract to be inherited by governed contracts
 * @dev This contract is not usable on its own since it does not have any _productive useful_ behavior
 * The only purpose of this contract is to define some useful modifiers and functions to be used on the
 * governance aspect of the child contract
 */
abstract contract Governed is UUPSUpgradeable {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotGovernorOrAuthorizedChanger();

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------

    /**
     * @notice Modifier that protects the function
     * @dev You should use this modifier in any function that should be called through
     * the governance system
     */
    modifier onlyGovernorOrAuthorizedChanger() {
        _checkIfGovernorOrAuthorizedChanger();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice governor contract address
    address public governor;
    /// @notice contract that can articulate more complex changes executed from the governor
    ChangeExecutor public changeExecutor;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param changeExecutor_ ChangeExecutor contract address
     */
    function __Governed_init(address changeExecutor_) internal onlyInitializing {
        __UUPSUpgradeable_init();
        changeExecutor = ChangeExecutor(changeExecutor_);
        governor = ChangeExecutor(changeExecutor_).governor();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Checks if the msg sender is the governor or an authorized changer, reverts otherwise
     */
    function _checkIfGovernorOrAuthorizedChanger() internal view {
        if (msg.sender != governor && !changeExecutor.isAuthorizedChanger(msg.sender)) {
            revert NotGovernorOrAuthorizedChanger();
        }
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev checks that the changer that will do the upgrade is currently authorized by governance to makes
     * changes within the system
     * @param newImplementation_ new implementation contract address
     */
    /* solhint-disable-next-line no-empty-blocks */
    function _authorizeUpgrade(address newImplementation_) internal override onlyGovernorOrAuthorizedChanger { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
