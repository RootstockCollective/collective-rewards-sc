// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "../BaseTest.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract InitializationTest is BaseTest {
    /**
     * SCENARIO: SupportHub cannot be initialized twice
     */
    function test_RevertSponsorsManagerInitialize() public {
        // GIVEN a SupportHub initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        supportHub.initialize(
            address(changeExecutorMock),
            address(rewardToken),
            address(stakingToken),
            address(builderGaugeFactory),
            address(builderRegistry)
        );
    }

    /**
     * SCENARIO: BuilderRegistry cannot be initialized twice
     */
    function test_RevertBuilderRegistryInitialize() public {
        // GIVEN a BuilderRegistry initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        builderRegistry.initialize(address(changeExecutorMock), foundation);
    }

    /**
     * SCENARIO: RewardDistributor cannot be initialized twice
     */
    function test_RevertRewardDistributorInitialize() public {
        // GIVEN a RewardDistributor initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rewardDistributor.initialize(address(changeExecutorMock), address(foundation), address(supportHub));
    }

    /**
     * SCENARIO: ChangeExecutor cannot be initialized twice
     */
    function test_RevertChangeExecutorInitialize() public {
        // GIVEN a ChangeExecutor initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        changeExecutorMock.initialize(governor);
    }
}
