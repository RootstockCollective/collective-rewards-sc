// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, SponsorsManager } from "./BaseTest.sol";

abstract contract HaltedBuilderBehavior is BaseTest {
    function _initialState() internal virtual { }

    function _haltGauge() internal virtual { }

    /**
     * SCENARIO: builder is halted in the middle of an epoch having allocation.
     *  Sponsors receive all the rewards for the current epoch
     */
    function test_HaltedGaugeReceiveCurrentRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is halted
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
    }

    /**
     * SCENARIO: builder is halted in the middle of an epoch having allocation.  and builder
     *  don't receive those rewards on the next epoch
     */
    function test_HaltedGaugeDoNotReceiveNextRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is halted
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
        assertEq(rewardToken.balanceOf(alice), 46_428_571_428_571_428_560);
        // THEN alice coinbase balance is 2.5 + increment of 2.142 = (10 * 6 / 14) * 0.5
        // builder allocations are not considered anymore. Alice lose those rewards
        assertEq(alice.balance, 4_642_857_142_857_142_844);

        // WHEN bob claim rewards
        vm.startPrank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is 25 + increment of 28.57 = (100 * 8 / 14) * 0.5
        assertEq(rewardToken.balanceOf(bob), 53_571_428_571_428_571_416);
        // THEN bob coinbase balance is 2.5 + increment of 2.857 = (10 * 8 / 14) * 0.5
        assertEq(bob.balance, 5_357_142_857_142_857_128);
    }

    /**
     * SCENARIO: builder is halted in the middle of an epoch having allocation.
     *  Alice reduce its allocation but the total reward shares don't change
     *  and the sponsorTotalAllocation is updated
     */
    function test_NegativeAllocationOnHaltedGauge() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is halted
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
    }

    /**
     * SCENARIO: builder is halted in a new epoch but before a distribution
     *  so, lastUpdateTime > periodFinish, rewardPerToken should not revert by underflow
     */
    function test_HaltedGaugeBeforeDistributionRewardPerToken() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        _initialDistribution();

        // AND epoch finish
        _skipAndStartNewEpoch();

        // skip some time to halt on another timestamp
        skip(10);

        // AND builder is halted before a distribution
        _haltGauge();

        // WHEN rewardPerToken is called
        // THEN tx does not revert
        gauge.rewardPerToken(address(rewardToken));

        // WHEN alice claim rewards
        vm.startPrank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 25 = (100 * 8 / 16) * 0.5
        assertApproxEqAbs(rewardToken.balanceOf(alice), 25 ether, 100);
        // THEN alice coinbase balance is 2.5 = (10 * 8 / 16) * 0.5
        assertApproxEqAbs(alice.balance, 2.5 ether, 100);
    }

    /**
     * SCENARIO: builder is halted in a new epoch but before a distribution
     *  so, lastUpdateTime > periodFinish, rewardMissing should not revert by underflow
     */
    function test_HaltedGaugeBeforeDistributionRewardMissing() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        _initialDistribution();

        // AND epoch finish
        _skipAndStartNewEpoch();

        // skip some time to halt on another timestamp
        skip(10);

        // AND builder is halted before a distribution
        _haltGauge();

        // WHEN alice removes allocations from halted gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);
    }

    /**
     * SCENARIO: builder increase allocations in the middle of the epoch and is halted.
     *  totalPotentialReward decreases by builder shares
     */
    function test_GaugeIncreaseAllocationMiddleEpochBeforeHalt() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();

        // AND alice adds allocations
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 100 ether);

        // WHEN builder is halted
        _haltGauge();

        // THEN gauge rewardShares is 30844800 ether = 2 * 1/2 WEEK + 100 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 30_844_800 ether);
        // THEN alice total allocation is 106
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 106 ether);
        // THEN totalPotentialReward is 8467200 ether = 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);
    }

    /**
     * SCENARIO: builder decrease allocations in the middle of the epoch and is halted.
     *  totalPotentialReward decreases by builder shares
     */
    function test_GaugeDecreaseAllocationMiddleEpochBeforeHalt() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        _initialDistribution();
        // AND epoch finish
        _skipAndStartNewEpoch();
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 100 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND alice removes allocations
        sponsorsManager.allocate(gauge, 0 ether);

        // WHEN builder is halted
        _haltGauge();

        // // THEN gauge rewardShares is 30240000 ether = 100 * 1/2 WEEK
        // assertEq(gauge.rewardShares(), 30_240_000 ether);
        // // THEN alice total allocation is 6
        // assertEq(sponsorsManager.sponsorTotalAllocation(alice), 6 ether);
        // // THEN totalPotentialReward is 8467200 ether = 14 * 1 WEEK
        // assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);
    }

    /**
     * SCENARIO: builder with lot of allocations is halted and remove all of them
     *  totalPotentialReward decreases by builder shares
     */
    function test_GaugeWithLotAllocationMiddleEpochBeforeHalt() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();

        // AND alice adds allocations
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 100 ether);

        // AND a quarter epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN builder is halted
        _haltGauge();

        // AND alice removes allocations
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0 ether);

        // THEN gauge rewardShares is 15724800 ether = 2 * 1/2 WEEK + 100 * 1/4 WEEK
        assertEq(gauge.rewardShares(), 15_724_800 ether);
        // THEN alice total allocation is 6
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 6 ether);
        // THEN totalPotentialReward is 8467200 ether = 14 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 8_467_200 ether);
    }

    /**
     * SCENARIO: builder is halted in the middle of an epoch having allocation.
     *  If the builder increases allocations tx fails
     */
    function test_HaltedGaugeCannotIncreaseAllocations() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();

        // WHEN builder is halted
        _haltGauge();

        // WHEN alice adds allocations
        vm.startPrank(alice);
        // THEN tx reverts
        vm.expectRevert(SponsorsManager.PositiveAllocationOnHaltedGauge.selector);
        sponsorsManager.allocate(gauge, 100 ether);
    }
}
