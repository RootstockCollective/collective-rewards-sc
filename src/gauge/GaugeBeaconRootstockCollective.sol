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
     * @dev We override _checkOwner so that OnlyOwner modifier uses governanceManager to authorize the caller
     */
    function _checkOwner() internal view override {
        governanceManager.validateUpgrader(msg.sender);
    }
}
