// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IChangeExecutorRootstockCollective } from "../interfaces/IChangeExecutorRootstockCollective.sol";

/**
 * @title Governed
 * @notice Base contract to be inherited by governed contracts
 * @dev This contract is not usable on its own since it does not have any _productive useful_ behavior
 * The only purpose of this contract is to define some useful modifiers and functions to be used on the
 * governance aspect of the child contract
 */
abstract contract Governed {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotGovernorOrAuthorizedChanger();
    error NotGovernor();

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

    /**
     * @notice Reverts if caller is not the governor
     */
    modifier onlyGovernor() {
        if (msg.sender != governor()) revert NotGovernor();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice contract that can articulate more complex changes executed from the governor
    IChangeExecutorRootstockCollective public changeExecutor;

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice maintains Governed interface. Returns governed address
     */
    function governor() public view virtual returns (address) { }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Checks if the msg sender is the governor or an authorized changer, reverts otherwise
     */
    function _checkIfGovernorOrAuthorizedChanger() internal view {
        if (msg.sender != governor() && !changeExecutor.isAuthorizedChanger(msg.sender)) {
            revert NotGovernorOrAuthorizedChanger();
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
