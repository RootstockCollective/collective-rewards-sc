// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IChangeContractRootstockCollective } from "../../interfaces/IChangeContractRootstockCollective.sol";
import { SponsorsManagerRootstockCollective } from "../../SponsorsManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "../../gauge/GaugeRootstockCollective.sol";

/**
 * @title WhitelistBuilderChangerTemplateRootstockCollective
 *   @notice ChangeContract used to whitelist a builder and create its Gauger contract
 */
contract WhitelistBuilderChangerTemplateRootstockCollective is IChangeContractRootstockCollective {
    /// @notice SponsorsManagerRootstockCollective contract address
    SponsorsManagerRootstockCollective public immutable sponsorsManager;
    /// @notice builder address to be whitelisted
    address public immutable builder;
    /// @notice new Gauge created;
    GaugeRootstockCollective public newGauge;

    /**
     * @notice Constructor
     * @param sponsorsManager_ Address of the SponsorsManger contract
     * @param builder_ Address of the builder
     */
    constructor(SponsorsManagerRootstockCollective sponsorsManager_, address builder_) {
        sponsorsManager = sponsorsManager_;
        builder = builder_;
    }

    /**
     * @notice Execute the changes.
     * @dev Should be called by the governor, but this contract does not check that explicitly
     * because it is not its responsibility in the current architecture
     */
    function execute() external {
        newGauge = sponsorsManager.whitelistBuilder(builder);
    }
}
