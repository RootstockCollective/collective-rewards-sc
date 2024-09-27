// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";

abstract contract HaltedBuilderBehavior is BaseTest {
    function _initialState() internal virtual { }

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
    }

    /**
     * SCENARIO: builder is halted in the middle of an epoch having allocation.
     *  Alice modifies its allocation but the total reward shares don't change
     *  and the sponsorTotalAllocation is updated
     */
    function test_HaltedGaugeModifyAllocation() public {
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
}
