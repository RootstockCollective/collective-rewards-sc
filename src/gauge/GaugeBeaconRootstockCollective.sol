// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract GaugeBeaconRootstockCollective is UpgradeableBeacon {
    IGovernanceManagerRootstockCollective public governanceManager;

    /**
     * @notice constructor
     * @param governanceManager_ contract with permissioned roles
     * @param gaugeImplementation_ address of the Gauge initial implementation
     */
    constructor(
        IGovernanceManagerRootstockCollective governanceManager_,
        address gaugeImplementation_
    )
        UpgradeableBeacon(gaugeImplementation_, governanceManager_.governor())
    {
        governanceManager = governanceManager_;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice The owner is the governor but we need more flexibility to allow changes.
     *  So, ownable protected functions can be executed also by an authorized changer executed by the governor
     * @dev Due we cannot override UpgradeableBeacon.sol to remove the OnlyOwner modifier on upgradeTo function
     *  we need to override this function to allow upgrade the beacon by a changer
     */
    function _checkOwner() internal view override {
        governanceManager.validateChanger(msg.sender);
    }
}