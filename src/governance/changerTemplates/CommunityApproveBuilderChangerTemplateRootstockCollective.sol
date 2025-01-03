// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IChangeContractRootstockCollective } from "../../interfaces/IChangeContractRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "../../backersManager/BuilderRegistryRootstockCollective.sol";
import { GaugeRootstockCollective } from "../../gauge/GaugeRootstockCollective.sol";

/**
 * @title CommunityApproveBuilderChangerTemplateRootstockCollective
 *   @notice ChangeContract used to community approve a builder and create its Gauger contract
 */
contract CommunityApproveBuilderChangerTemplateRootstockCollective is IChangeContractRootstockCollective {
    /// @notice BuilderRegistryRootstockCollective contract address
    BuilderRegistryRootstockCollective public immutable builderRegistry;
    /// @notice builder address to be community approved
    address public immutable builder;
    /// @notice new Gauge created;
    GaugeRootstockCollective public newGauge;

    /**
     * @notice Constructor
     * @param builderRegistry_ Address of the BackersManger contract
     * @param builder_ Address of the builder
     */
    constructor(BuilderRegistryRootstockCollective builderRegistry_, address builder_) {
        builderRegistry = builderRegistry_;
        builder = builder_;
    }

    /**
     * @notice Execute the changes.
     * @dev Should be called by the governor, but this contract does not check that explicitly
     * because it is not its responsibility in the current architecture
     */
    function execute() external {
        newGauge = builderRegistry.communityApproveBuilder(builder);
    }
}
