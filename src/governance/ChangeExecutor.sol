// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IChangeExecutor } from "../interfaces/IChangeExecutor.sol";

/**
 * @title ChangeExecutor
 * @notice Basic governor that handles its governed contracts changes
 * through trusting an external address
 */
contract ChangeExecutor is ReentrancyGuard, IChangeExecutor {
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
     * @param changeContract Address of the contract that will execute the changes
     */
    function executeChange(IChangeContract changeContract) external {
        _executeChange(changeContract);
    }

    /**
     * @notice Returns true if the _changer address is currently authorized to make
     * changes within the system
     * @param _changer Address of the contract that will be tested
     */
    function isAuthorizedChanger(address _changer) external view returns (bool) {
        return _isAuthorizedChanger(_changer);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Function to be called to make the changes in changeContract
     * @param changeContract Address of the contract that will execute the changes
     */
    function _executeChange(IChangeContract changeContract) internal nonReentrant onlyGovernor {
        enableChangeContract(changeContract);
        changeContract.execute();
        disableChangeContract();
    }

    /**
     * @notice Returns true if the _changer address is currently authorized to make
     * changes within the system
     * @param _changer Address of the contract that will be tested
     */
    function _isAuthorizedChanger(address _changer) internal view returns (bool) {
        return currentChangeContract == _changer;
    }

    /**
     * @notice Authorize the changeContract address to make changes
     * @param changeContract Address of the contract that will be authorized
     */
    function enableChangeContract(IChangeContract changeContract) internal {
        currentChangeContract = address(changeContract);
    }

    /**
     * @notice UNAuthorize the currentChangeContract address to make changes
     */
    function disableChangeContract() internal {
        currentChangeContract = address(0x0);
    }
}
