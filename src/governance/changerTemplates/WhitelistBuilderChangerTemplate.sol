// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { SponsorsManager } from "../../SponsorsManager.sol";
import { Gauge } from "../../gauge/Gauge.sol";

/**
 * @title WhitelistBuilderChangerTemplate
 *   @notice ChangeContract used to whitelist a builder and create its Gauger contract
 */
contract WhitelistBuilderChangerTemplate is IChangeContract {
    /// @notice SponsorsManager contract address
    SponsorsManager public immutable sponsorsManager;
    /// @notice builder address to be whitelisted
    address public immutable builder;
    /// @notice new Gauge created;
    Gauge public newGauge;

    /**
     * @notice Constructor
     * @param sponsorsManager_ Address of the SponsorsManger contract
     * @param builder_ Address of the builder
     */
    constructor(SponsorsManager sponsorsManager_, address builder_) {
        sponsorsManager = sponsorsManager_;
        builder = builder_;
    }

    /**
     * @notice Execute the changes.
     * @dev Should be called by the governor, but this contract does not check that explicitly
     * because it is not its responsibility in the current architecture
     */
    function execute() external {
        // TODO: whitelist the builder on the BuilderRegistry once
        // https://rsklabs.atlassian.net/browse/TOK-117 is completed
        newGauge = sponsorsManager.createGauge(builder);
    }
}
