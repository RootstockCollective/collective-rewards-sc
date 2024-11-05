// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "../BaseTest.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract InitializationTest is BaseTest {
    /**
     * SCENARIO: SponsorsManager cannot be initialized twice
     */
    function test_RevertSponsorsManagerInitialize() public {
        // GIVEN a SponsorsManager initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        uint32 _cycleDuration = 1 weeks;
        uint24 _cycleStartOffset = 1 days;
        uint128 _kickbackCooldown = 2 weeks;
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sponsorsManager.initialize(
            governanceManager,
            address(rewardToken),
            address(stakingToken),
            address(gaugeFactory),
            address(rewardDistributor),
            _cycleDuration,
            _cycleStartOffset,
            _kickbackCooldown
        );
    }

    /**
     * SCENARIO: RewardDistributor cannot be initialized twice
     */
    function test_RevertRewardDistributorInitialize() public {
        // GIVEN a RewardDistributor initialized
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
        gauge.initialize(address(rewardToken), address(sponsorsManager));
    }

    /**
     * SCENARIO: GovernanceManager cannot be initialized twice
     */
    function test_RevertGovernanceManagerInitialize() public {
        // GIVEN a GovernanceManager initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.prank(governor);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        governanceManager.initialize(governor, foundation, kycApprover);
    }
}
