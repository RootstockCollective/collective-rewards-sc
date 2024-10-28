// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Governed, IChangeExecutorRootstockCollective } from "../governance/Governed.sol";

contract GaugeBeacon is UpgradeableBeacon, Governed {
    /**
     * @notice constructor
     * @param changeExecutor_ ChangeExecutorRootstockCollective contract address
     * @param gaugeImplementation_ address of the Gauge initial implementation
     */
    constructor(
        address changeExecutor_,
        address gaugeImplementation_
    )
        UpgradeableBeacon(gaugeImplementation_, IChangeExecutorRootstockCollective(changeExecutor_).governor())
    {
        changeExecutor = IChangeExecutorRootstockCollective(changeExecutor_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice maintains Governed interface. Returns governed address
     */
    function governor() public view override returns (address) {
        return owner();
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
    function _checkOwner() internal view override onlyGovernorOrAuthorizedChanger { }
}
