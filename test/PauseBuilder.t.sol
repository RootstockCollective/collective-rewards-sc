// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "./BaseTest.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract PauseBuilderTest is BaseTest {
    function _initialState() internal {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();

        // AND builder is paused
        vm.startPrank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");
        vm.stopPrank();
    }

    /**
     * SCENARIO: builder is paused in the middle of an epoch having allocation.
     *  Sponsors claim all the rewards
     */
    function test_PausedGaugeSponsorsReceiveRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is paused
        _initialState();
        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.startPrank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 25 = (100 * 8 / 16) * 0.5
        assertApproxEqAbs(rewardToken.balanceOf(alice), 25 ether, 100);
        // THEN alice coinbase balance is 2.5 = (10 * 8 / 16) * 0.5
        assertApproxEqAbs(alice.balance, 2.5 ether, 100);

        // WHEN bob claim rewards
        vm.startPrank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is 25 = (100 * 8 / 16) * 0.5
        assertApproxEqAbs(rewardToken.balanceOf(bob), 25 ether, 100);
        // THEN bob coinbase balance is 2.5 = (10 * 8 / 16) * 0.5
        assertApproxEqAbs(bob.balance, 2.5 ether, 100);
    }

    /**
     * SCENARIO: builder is paused in the middle of an epoch having allocation.
     *  If the builder calls claimBuilderReward the tx reverts
     */
    function test_PausedGaugeBuilderCannotReceiveRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is paused
        _initialState();
        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN builder claim rewards
        vm.startPrank(builder);
        // THEN tx reverts because builder rewards are locked
        vm.expectRevert(Gauge.BuilderRewardsLocked.selector);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 0
        assertEq(rewardToken.balanceOf(builder), 0);
        // THEN builder coinbase balance is 0
        assertEq(builder.balance, 0);
        // THEN builder rewardToken pending to claim are 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.builderRewards(address(rewardToken)), 6.25 ether);
        // THEN builder coinbase pending to claim are 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 0.625 ether);

        // WHEN builder2 claim rewards
        vm.startPrank(builder2);
        gauge2.claimBuilderReward();

        // THEN builder2Receiver rewardToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver coinbase balance is 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 4.375 ether);
    }

    /**
     * SCENARIO: builder is paused in the middle of an epoch having allocation.
     *  Alice can modify its allocation
     */
    function test_PausedGaugeModifyAllocation() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is paused
        _initialState();

        // WHEN alice removes allocations from paused builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);
        // THEN gauge rewardShares is 604800 ether = 2 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 604_800 ether);
        // THEN total allocation is 9072000 ether = 2 * 1/2 WEEK + 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 9_072_000 ether);

        // WHEN alice adds allocations to paused builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 4 ether);
        // THEN gauge rewardShares is 1814400 ether = 2 * 1/2 WEEK + 4 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 1_814_400 ether);
        // THEN total allocation is 10281600 ether =  2 * 1/2 WEEK + 4 * 1/2 WEEK + 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 10_281_600 ether);
    }

    /**
     * SCENARIO: builder is paused in the middle of an epoch having rewards to claim,
     *  is unpaused in the same epoch and can claim them
     */
    function test_ResumeGaugeInSameEpoch() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is paused
        _initialState();

        // AND 3/4 epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN gauge is unpaused
        vm.startPrank(kycApprover);
        sponsorsManager.unpauseBuilder(builder);

        // WHEN builder claim rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 6.25 ether);
        // THEN builder coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);
        // THEN builder rewardToken pending to claim are 0
        assertEq(gauge.builderRewards(address(rewardToken)), 0);
        // THEN builder coinbase pending to claim are 0
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 0);
    }

    /**
     * SCENARIO: builder is paused in the middle of an epoch having rewards to claim,
     *  is unpaused in the next epoch and can claim the previous rewards and the new ones
     */
    function test_ResumeGaugeInNextEpoch() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is paused
        _initialState();

        // AND epoch finish
        _skipAndStartNewEpoch();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN gauge is unpaused
        vm.startPrank(kycApprover);
        sponsorsManager.unpauseBuilder(builder);

        // WHEN builder claim rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 12.5 = (200 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 12.5 ether);
        // THEN builder coinbase balance is 1.25 = (20 * 2 / 16) * 0.5
        assertEq(builder.balance, 1.25 ether);
        // THEN builder rewardToken pending to claim are 0
        assertEq(gauge.builderRewards(address(rewardToken)), 0);
        // THEN builder coinbase pending to claim are 0
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 0);
    }

    /**
     * SCENARIO: revoked builder is paused
     *  If the builder calls claimBuilderReward the tx reverts
     */
    function test_RevokedGaugeIsPaused() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();
        // AND builder is revoked
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        // AND builder is paused
        vm.startPrank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");

        // WHEN builder claim rewards
        vm.startPrank(builder);
        // THEN tx reverts because builder rewards are locked
        vm.expectRevert(Gauge.BuilderRewardsLocked.selector);
        gauge.claimBuilderReward();
    }
}
