// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IChangeExecutor } from "../interfaces/IChangeExecutor.sol";

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

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------

    /**
     * @notice Modifier that protects the function
     * @dev You should use this modifier in any function that should be called through
     * the governance system
     */
    modifier onlyGovernorOrAuthorizedChanger() {
        checkIfGovernorOrAuthorizedChanger();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice governor contract address
    address public immutable governor;
    /// @notice contract that can articulate more complex changes executed from the governor
    IChangeExecutor public immutable changeExecutor;

    /**
     * @notice Constructor
     * @param governor_ governor contract address
     * @param changeExecutor_ ChangeExecutor contract address
     */
    constructor(address governor_, address changeExecutor_) {
        governor = governor_;
        changeExecutor = IChangeExecutor(changeExecutor_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Checks if the msg sender is the governor or an authorized changer, reverts otherwise
     */
    function checkIfGovernorOrAuthorizedChanger() internal view {
        if (msg.sender != governor && !changeExecutor.isAuthorizedChanger(msg.sender)) {
            revert NotGovernorOrAuthorizedChanger();
        }
    }
}
