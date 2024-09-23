// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";

contract RevokeBuilderTest is BaseTest {
    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(sponsorsManager), 100_000 ether);
    }

    function _initialState() internal {
        // GIVEN alice allocates to builder and builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND builder is revoked
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        vm.stopPrank();
    }

    /**
     * SCENARIO: builder is revoked in the middle of an epoch having allocation. Sponsor and builder
     *  receive all the rewards for the current epoch
     */
    function test_HaltedGaugeReceiveCurrentRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();
        // AND epoch finish
        _skipAndStartNewEpoch();

        // THEN total allocation is 8467200 ether = 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);

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

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 6.25 ether);
        // THEN builder coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rewardToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver coinbase balance is 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 4.375 ether);
    }

    /**
     * SCENARIO: builder is revoked in the middle of an epoch having allocation. Sponsor and builder
     *  don't receive those rewards on the next epoch
     */
    function test_HaltedGaugeDoNotReceiveNextRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN total allocation is 8467200 ether = 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.startPrank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 25 + increment of 21.42 = (100 * 6 / 14) * 0.5
        // builder allocations are not considered anymore. Alice lose those rewards
        assertEq(rewardToken.balanceOf(alice), 46_428_571_428_571_428_558);
        // THEN alice coinbase balance is 2.5 + increment of 2.142 = (10 * 6 / 14) * 0.5
        // builder allocations are not considered anymore. Alice lose those rewards
        assertEq(alice.balance, 4_642_857_142_857_142_842);

        // WHEN bob claim rewards
        vm.startPrank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is 25 + increment of 28.57 = (100 * 8 / 14) * 0.5
        assertEq(rewardToken.balanceOf(bob), 53_571_428_571_428_571_416);
        // THEN bob coinbase balance is 2.5 + increment of 2.857 = (10 * 8 / 14) * 0.5
        assertEq(bob.balance, 5_357_142_857_142_857_128);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is the same. It didn't receive rewards
        assertEq(rewardToken.balanceOf(builder), 6.25 ether);
        // THEN builder coinbase balance is the same. It didn't receive rewards
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rewardToken balance is 43.75 + 50. All the rewards are to him
        assertEq(rewardToken.balanceOf(builder2Receiver), 93.75 ether);
        // THEN builder2Receiver coinbase balance is 43.75 + 50. All the rewards are to him
        assertEq(builder2Receiver.balance, 9.375 ether);
    }

    /**
     * SCENARIO: builder is revoked in the middle of an epoch having allocation
     *  and is permitted in the same epoch
     */
    function test_ResumeGaugeInSameEpoch() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        // AND 3/4 epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN gauge is permitted
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.5 ether);

        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation didn't change is 9676800 ether = 16 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 9_676_800 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.startPrank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 50 = (200 * 8 / 16) * 0.5
        assertApproxEqAbs(rewardToken.balanceOf(alice), 50 ether, 100);
        // THEN alice coinbase balance is 5 = (20 * 8 / 16) * 0.5
        assertApproxEqAbs(alice.balance, 5 ether, 100);

        // WHEN bob claim rewards
        vm.startPrank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is 50 = (200 * 8 / 16) * 0.5
        assertApproxEqAbs(rewardToken.balanceOf(bob), 50 ether, 100);
        // THEN bob coinbase balance is 5 = (10 * 8 / 16) * 0.5
        assertApproxEqAbs(bob.balance, 5 ether, 100);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is 12.5 = (200 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 12.5 ether);
        // THEN builder coinbase balance is 1.25 = (20 * 2 / 16) * 0.5
        assertEq(builder.balance, 1.25 ether);

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
        //    AND builder is revoked
        _initialState();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN gauge is permitted
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.5 ether);
        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation didn't change is 9676800 ether = 16 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 9_676_800 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.startPrank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is:
        //  epoch 1 = 25 = (100 * 8 / 16) * 0.5
        //  epoch 2 = 21.42 = (100 * 6 / 14) * 0.5
        //  epoch 3 = 21.42 = (100 * 6 / 14) * 0.5
        //  epoch 4 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(alice), 92_857_142_857_142_857_118);
        // THEN alice coinbase balance is:
        //  epoch 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  epoch 2 = 2.142 = (10 * 6 / 14) * 0.5
        //  epoch 3 = 2.142 = (10 * 6 / 14) * 0.5
        //  epoch 4 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(alice.balance, 9_285_714_285_714_285_686);

        // WHEN bob claim rewards
        vm.startPrank(bob);
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

        // THEN builder rewardToken balance is:
        //  epoch 1 = 6.25 = (100 * 2 / 16) * 0.5
        //  epoch 2 = 0
        //  epoch 3 = 0
        //  epoch 4 = 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 12.5 ether);
        // THEN builder coinbase balance is:
        //  epoch 1 = 0.625 = (10 * 2 / 16) * 0.5
        //  epoch 2 = 0
        //  epoch 3 = 0
        //  epoch 4 = 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 1.25 ether);

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
     * SCENARIO: builder is revoked in the middle of an epoch having allocation.
     *  Alice modifies its allocation but the total reward shares don't change
     *  and the sponsorTotalAllocation is updated
     */
    function test_HaltedGaugeModifyAllocation() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        // WHEN alice removes allocations from revoked builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);
        // THEN gauge rewardShares is 604800 ether = 2 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 604_800 ether);
        // THEN alice total allocation is 6
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 6 ether);
        // THEN total allocation didn't change is 8467200 ether = 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);

        // WHEN alice adds allocations to revoked builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 4 ether);
        // THEN gauge rewardShares is 1814400 ether = 2 * 1/2 WEEK + 4 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 1_814_400 ether);
        // THEN alice total allocation is 10
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 10 ether);
        // THEN total allocation didn't change is 8467200 ether = 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);
    }

    /**
     * SCENARIO: builder is revoked in the middle of an epoch having allocation.
     *  Alice removes all its allocation and after it is permitted, adds them again
     */
    function test_HaltedGaugeLoseAllocation() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        // WHEN alice removes allocations from revoked builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND gauge is permitted
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.5 ether);

        // AND alice adds allocations again
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.startPrank(alice);
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
        vm.startPrank(bob);
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

        // THEN builder rewardToken balance is:
        //  epoch 1 = 6.25 = (100 * 2 / 16) * 0.5
        //  epoch 2 = 0
        //  epoch 3 = 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 12.5 ether);
        // THEN builder coinbase balance is:
        //  epoch 1 = 0.625 = (10 * 2 / 16) * 0.5
        //  epoch 2 = 0
        //  epoch 3 = 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 1.25 ether);

        // THEN builder2Receiver rewardToken balance is:
        //  epoch 1 = 43.75 = (100 * 14 / 16) * 0.5
        //  epoch 2 = 50 = (100 * 14 / 14) * 0.5
        //  epoch 3 = 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 137.5 ether);
        // THEN builder2Receiver coinbase balance is:
        //  epoch 1 = 4.375 = (10 * 14 / 16) * 0.5
        //  epoch 2 = 5 = (10 * 14 / 14) * 0.5
        //  epoch 3 = 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 13.75 ether);

        // THEN gauge rewardToken balance is 0, there is no remaining rewards
        assertApproxEqAbs(rewardToken.balanceOf(address(gauge)), 0, 100);
        // THEN gauge coinbase balance is 0, there is no remaining rewards
        assertApproxEqAbs(address(gauge).balance, 0, 100);
    }

    /**
     * SCENARIO: builder is permitted with a new kickback before the cooldown end time
     *  and it is not applied
     */
    function test_PermitBuilderBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN builder kickback cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time didn't end
        vm.warp(_cooldownEndTime - 1);

        // WHEN gauge is permitted with a new kickback of 80%
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.8 ether);
        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN previous builder kickback is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder kickback is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder kickback cooldown finishes in 1 sec
        assertEq(_cooldownEndTime, block.timestamp + 1);
        // THEN builder kickback to apply is 50%
        assertEq(sponsorsManager.getKickbackToApply(builder), 0.5 ether);

        // THEN cooldown time ends
        skip(1);
        // THEN builder kickback to apply is 80%
        assertEq(sponsorsManager.getKickbackToApply(builder), 0.8 ether);
    }

    /**
     * SCENARIO: builder is permitted with a new kickback after the cooldown end time
     *  and it is applied
     */
    function test_PermitBuilderAfterCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN builder kickback cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time ends
        vm.warp(_cooldownEndTime);

        // WHEN gauge is permitted with a new kickback of 80%
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.8 ether);
        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN previous builder kickback is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder kickback is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder kickback cooldown finished
        assertEq(_cooldownEndTime, block.timestamp);
        // THEN builder kickback to apply is 80%
        assertEq(sponsorsManager.getKickbackToApply(builder), 0.8 ether);
    }
}
