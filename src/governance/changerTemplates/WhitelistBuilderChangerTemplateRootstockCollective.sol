// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IChangeContractRootstockCollective } from "../../interfaces/IChangeContractRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "../../BackersManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "../../gauge/GaugeRootstockCollective.sol";

/**
 * @title WhitelistBuilderChangerTemplateRootstockCollective
 *   @notice ChangeContract used to whitelist a builder and create its Gauger contract
 */
contract WhitelistBuilderChangerTemplateRootstockCollective is IChangeContractRootstockCollective {
    /// @notice BackersManagerRootstockCollective contract address
    BackersManagerRootstockCollective public immutable backersManager;
    /// @notice builder address to be whitelisted
    address public immutable builder;
    /// @notice new Gauge created;
    GaugeRootstockCollective public newGauge;

    /**
     * @notice Constructor
     * @param backersManager_ Address of the BackersManger contract
     * @param builder_ Address of the builder
     */
    constructor(BackersManagerRootstockCollective backersManager_, address builder_) {
        backersManager = backersManager_;
        builder = builder_;
    }

    /**
     * @notice Execute the changes.
     * @dev Should be called by the governor, but this contract does not check that explicitly
     * because it is not its responsibility in the current architecture
     */
    function execute() external {
        newGauge = backersManager.whitelistBuilder(builder);
    }
}
