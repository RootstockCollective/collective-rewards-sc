// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { BaseTest } from "../BaseTest.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract InitializationTest is BaseTest {
    /**
     * SCENARIO: BackersManagerRootstockCollective cannot be initialized twice
     */
    function test_RevertBackersManagerRootstockCollectiveInitialize() public {
        // GIVEN a BackersManagerRootstockCollective initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        backersManager.initialize(
            governanceManager,
            address(rifToken),
            address(usdrifToken),
            address(stakingToken),
            cycleDuration,
            cycleStartOffset,
            distributionDuration,
            maxDistributionsPerBatch
        );
    }

    /**
     * SCENARIO: RewardDistributorRootstockCollective cannot be initialized twice
     */
    function test_RevertRewardDistributorRootstockCollectiveInitialize() public {
        // GIVEN a RewardDistributorRootstockCollective initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rewardDistributor.initialize(governanceManager);
    }

    /**
     * SCENARIO: Gauge cannot be initialized twice
     */
    function test_RevertGaugeInitialize() public {
        // GIVEN a Gauge initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        gauge.initialize(address(rifToken), address(usdrifToken), address(backersManager));
    }

    /**
     * SCENARIO: GovernanceManagerRootstockCollective cannot be initialized twice
     */
    function test_RevertGovernanceManagerRootstockCollectiveInitialize() public {
        // GIVEN a GovernanceManagerRootstockCollective initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.prank(governor);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        governanceManager.initialize(governor, foundation, kycApprover, upgrader);
    }
}
