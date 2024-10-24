// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IGoverned } from "src/interfaces/IGoverned.sol";

contract GaugeBeacon is UpgradeableBeacon {
    IGoverned private _governed;

    /**
     * @notice constructor
     * @param governed_ contract with permissioned roles
     * @param gaugeImplementation_ address of the Gauge initial implementation
     */
    constructor(
        IGoverned governed_,
        address gaugeImplementation_
    )
        UpgradeableBeacon(gaugeImplementation_, governed_.governor())
    {
        _governed = governed_;
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
        _governed.validateChanger(msg.sender);
    }
}
