// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { SponsorsManager } from "../../SponsorsManager.sol";
import { BuilderRegistry } from "../../BuilderRegistry.sol";
import { BuilderGauge } from "../../builder/BuilderGauge.sol";

/**
 * @title WhitelistBuilderChangerTemplate
 *   @notice ChangeContract used to whitelist a builder and create their BuilderGauge contract
 */
contract WhitelistBuilderChangerTemplate is IChangeContract {
    /// @notice SponsorsManager contract address
    SponsorsManager public immutable sponsorsManager;
    /// @notice builder address to be whitelisted
    address public immutable builder;
    /// @notice new BuilderGauge created;
    BuilderGauge public newBuilderGauge;

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
        sponsorsManager.builderRegistry().whitelistBuilder(builder);
        newBuilderGauge = sponsorsManager.createBuilderGauge(builder);
    }
}
