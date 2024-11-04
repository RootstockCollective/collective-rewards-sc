// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";

abstract contract ResumeBuilderBehavior is BaseTest {
    function _initialState() internal virtual { }
    function _resumeGauge() internal virtual { }

    /**
     * SCENARIO: builder is halted in the middle of an epoch having allocation
     *  and is resumed in the same epoch
     */
    function test_ResumeGaugeInSameEpoch() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is halted
        _initialState();

        // AND 3/4 epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN gauge is resumed
        _resumeGauge();

        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation didn't change is 9676800 ether = 16 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 9_676_800 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 50 = (200 * 8 / 16) * 0.5
        assertApproxEqAbs(rewardToken.balanceOf(alice), 50 ether, 100);
        // THEN alice coinbase balance is 5 = (20 * 8 / 16) * 0.5
        assertApproxEqAbs(alice.balance, 5 ether, 100);

        // WHEN bob claim rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is 50 = (200 * 8 / 16) * 0.5
        assertApproxEqAbs(rewardToken.balanceOf(bob), 50 ether, 100);
        // THEN bob coinbase balance is 5 = (10 * 8 / 16) * 0.5
        assertApproxEqAbs(bob.balance, 5 ether, 100);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder2Receiver rewardToken balance is 87.5 = (200 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 87.5 ether);
        // THEN builder2Receiver coinbase balance is 8.75 = (20 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 8.75 ether);
    }

    /**
     * SCENARIO: builder is revoked in the middle of an epoch having allocation
     *  and is permitted 2 epochs later
     */
    function test_ResumeGaugeTwoEpochsLater() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is halted
        _initialState();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN gauge is resumed
        _resumeGauge();

        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation didn't change is 9676800 ether = 16 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 9_676_800 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is:
        //  epoch 1 = 25 = (100 * 8 / 16) * 0.5
        //  epoch 2 = 21.42 = (100 * 6 / 14) * 0.5
        //  epoch 3 = 21.42 = (100 * 6 / 14) * 0.5
        //  epoch 4 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(alice), 92_857_142_857_142_857_120);
        // THEN alice coinbase balance is:
        //  epoch 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  epoch 2 = 2.142 = (10 * 6 / 14) * 0.5
        //  epoch 3 = 2.142 = (10 * 6 / 14) * 0.5
        //  epoch 4 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(alice.balance, 9_285_714_285_714_285_688);

        // WHEN bob claim rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is:
        //  epoch 1 = 25 = (100 * 8 / 16) * 0.5
        //  epoch 2 = 28.57 = (100 * 8 / 14) * 0.5
        //  epoch 3 = 28.57 = (100 * 8 / 14) * 0.5
        //  epoch 4 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(bob), 107_142_857_142_857_142_832);
        // THEN bob coinbase balance is:
        //  epoch 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  epoch 2 = 2.857 = (10 * 8 / 14) * 0.5
        //  epoch 3 = 2.857 = (10 * 8 / 14) * 0.5
        //  epoch 4 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(bob.balance, 10_714_285_714_285_714_256);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder2Receiver rewardToken balance is:
        //  epoch 1 = 43.75 = (100 * 14 / 16) * 0.5
        //  epoch 2 = 50 = (100 * 14 / 14) * 0.5
        //  epoch 3 = 50 = (100 * 14 / 14) * 0.5
        //  epoch 4 = 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 187.5 ether);
        // THEN builder2Receiver coinbase balance is:
        //  epoch 1 = 4.375 = (10 * 14 / 16) * 0.5
        //  epoch 2 = 5 = (10 * 14 / 14) * 0.5
        //  epoch 3 = 5 = (10 * 14 / 14) * 0.5
        //  epoch 4 = 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 18.75 ether);
    }

    /**
     * SCENARIO: builder is halted in the middle of an epoch having allocation.
     *  Alice removes all its allocation and after it is resumed, adds them again
     */
    function test_HaltedGaugeLoseAllocation() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is halted
        _initialState();

        // WHEN alice removes allocations from revoked builder
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND gauge is resumed
        _resumeGauge();

        // AND alice adds allocations again
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is:
        //  epoch 1 = 21.875 = 3.125 + 18.75 = (100 * 2 / 16) * 0.5 * 0.5 WEEKS + (100 * 6 / 16) * 0.5
        //  epoch 2 = 21.42 = (100 * 6 / 14) * 0.5
        //  epoch 3 = 28.125 = 3.125(missingRewards) + (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(alice), 71_428_571_428_571_428_550);
        // THEN alice coinbase balance is:
        //  epoch 1 = 2.1875 = 0.3125 + 1.875 = (10 * 2 / 16) * 0.5 * 0.5 WEEKS + (10 * 6 / 16) * 0.5
        //  epoch 2 = 2.142 = (10 * 6 / 14) * 0.5
        //  epoch 3 = 2.8125 = 0.3125(missingRewards) + (10 * 8 / 16) * 0.5
        assertEq(alice.balance, 7_142_857_142_857_142_834);

        // WHEN bob claim rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is:
        //  epoch 1 = 25 = (100 * 8 / 16) * 0.5
        //  epoch 2 = 28.57 = (100 * 8 / 14) * 0.5
        //  epoch 3 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(bob), 78_571_428_571_428_571_408);
        // THEN bob coinbase balance is:
        //  epoch 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  epoch 2 = 2.857 = (10 * 8 / 14) * 0.5
        //  epoch 3 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(bob.balance, 7_857_142_857_142_857_120);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN gauge rewardToken balance is 0, there is no remaining rewards
        assertApproxEqAbs(rewardToken.balanceOf(address(gauge)), 0, 100);
        // THEN gauge coinbase balance is 0, there is no remaining rewards
        assertApproxEqAbs(address(gauge).balance, 0, 100);
    }

    /**
     * SCENARIO: builder is halted in the middle of an epoch, lose some allocations
     *  when is resumed in the same epoch it does not recover the full reward shares
     */
    function test_ResumeGaugeInSameEpochDoNotRecoverShares() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is halted
        _initialState();

        // WHEN alice adds allocations to halted builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // THEN gauge rewardShares is 907200 ether = 2 * 1/2 WEEK + 1 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 907_200 ether);
        // THEN total allocation didn't change is 8467200 ether = 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);

        // skip some time to resume on another timestamp
        skip(10);

        // WHEN gauge is resumed
        _resumeGauge();

        // THEN gauge rewardShares is 907200 ether = 2 * 1/2 WEEK + 1 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 907_200 ether);
        // THEN total allocation didn't change is 9374400 ether = gauge(2 * 1/2 WEEK + 1 * 1/2 WEEK) + gauge2(14 * 1
        // WEEK)
        assertEq(sponsorsManager.totalPotentialReward(), 9_374_400 ether);
    }
}
