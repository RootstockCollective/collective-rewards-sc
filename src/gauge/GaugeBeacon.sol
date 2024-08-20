// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ChangeExecutor } from "../governance/ChangeExecutor.sol";

contract GaugeBeacon is UpgradeableBeacon {
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

    /// @notice contract that can articulate more complex changes executed from the governor
    ChangeExecutor public immutable changeExecutor;

    /**
     * @notice constructor
     * @param changeExecutor_ ChangeExecutor contract address
     * @param gaugeImplementation_ address of the Gauge initial implementation
     */
    constructor(
        address changeExecutor_,
        address gaugeImplementation_
    )
        UpgradeableBeacon(gaugeImplementation_, ChangeExecutor(changeExecutor_).governor())
    {
        changeExecutor = ChangeExecutor(changeExecutor_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice maintains Governed interface. Returns governed address
     */
    function governor() public view returns (address) {
        return owner();
    }

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
     * @notice The owner is the governor but we need more flexibility to allow changes.
     *  So, ownable protected functions can be executed also by an authorized changer executed by the governor
     * @dev Due we cannot override UpgradeableBeacon.sol to remove the OnlyOwner modifier on upgradeTo function
     *  we need to override this function to allow upgrade the beacon by a changer
     */
    function _checkOwner() internal view override onlyGovernorOrAuthorizedChanger { }
}
