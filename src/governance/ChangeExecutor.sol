// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";

/**
 * @title ChangeExecutor
 * @notice This contract is used to handle changes on the project when multiple function calls
 *  or validation are required.
 *  All the governed protected function can be executed when are called through this contract but only can be performed
 *  by the Governor.
 */
contract ChangeExecutor is ReentrancyGuard {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotGovernor();

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyGovernor() {
        if (msg.sender != governor) revert NotGovernor();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice governor address
    address public governor;
    /// @notice changer contract address to be executed
    address private currentChangeContract;

    /**
     * @notice Constructor
     * @param governor_ governor contract address
     */
    constructor(address governor_) {
        governor = governor_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice Function to be called to make the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function executeChange(IChangeContract changeContract_) external {
        _executeChange(changeContract_);
    }

    /**
     * @notice Returns true if the changer_ address is currently authorized to make
     * changes within the system
     * @param changer_ Address of the contract that will be tested
     */
    function isAuthorizedChanger(address changer_) external view virtual returns (bool) {
        return _isAuthorizedChanger(changer_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Function to be called to make the changes in changeContract
     * @dev reverts if is not called by the Governor
     * @param changeContract_ Address of the contract that will execute the changes
     */
    function _executeChange(IChangeContract changeContract_) internal nonReentrant onlyGovernor {
        _enableChangeContract(changeContract_);
        changeContract_.execute();
        _disableChangeContract();
    }

    /**
     * @notice Returns true if the changer_ address is currently authorized to make
     * changes within the system
     * @param changer_ Address of the contract that will be tested
     */
    function _isAuthorizedChanger(address changer_) internal view returns (bool) {
        return currentChangeContract == changer_;
    }

    /**
     * @notice Authorize the changeContract address to make changes
     * @param changeContract_ Address of the contract that will be authorized
     */
    function _enableChangeContract(IChangeContract changeContract_) internal {
        currentChangeContract = address(changeContract_);
    }

    /**
     * @notice UNAuthorize the currentChangeContract address to make changes
     */
    function _disableChangeContract() internal {
        currentChangeContract = address(0x0);
    }
}
