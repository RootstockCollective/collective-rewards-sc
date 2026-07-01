// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { BaseTest } from "./BaseTest.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";

/**
 * @notice Proof of vulnerability #21: a backer can pollute a gauge's `rewardShares` by
 *  allocating in the window after a cycle ends (`block.timestamp >= periodFinish`) but before
 *  `startDistribution()` is called, stealing the previous cycle's rewards from other gauges.
 *
 * @dev This test asserts the SAFE behaviour (equal allocations => equal rewards). It therefore
 *  FAILS while the attack succeeds, and would pass once allocations are blocked in that window.
 */
contract PollutedRewardSharesTest is BaseTest {
    function test_attack_allocationBeforeDistributionStealsRewards() public {
        // GIVEN during the cycle, gauge and gauge2 get identical allocations (10 stRIF each)
        vm.prank(alice);
        backersManager.allocate(gauge, 10 ether);
        vm.prank(bob);
        backersManager.allocate(gauge2, 10 ether);

        // AND the cycle ends: we are in the distribution window, past periodFinish,
        // but startDistribution() has not run yet (allocations are still open)
        _skipToStartDistributionWindow();
        assertGe(block.timestamp, backersManager.periodFinish());
        assertFalse(backersManager.onDistributionPeriod());

        // WHEN the attacker (alice) tries to front-run the distribution — this is now blocked
        vm.expectRevert(BackersManagerRootstockCollective.CycleEnded.selector);
        vm.prank(alice);
        backersManager.allocate(gauge, 10_000 ether);

        // AND the previous cycle's 100 RIF are distributed
        rifToken.mint(address(rewardDistributor), 100 ether);
        vm.prank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(100 ether, 0, 0);
        while (backersManager.onDistributionPeriod()) {
            backersManager.distribute();
        }

        // THEN both gauges had identical allocations during the rewarded cycle, so each must
        // receive ~50 RIF. This assertion FAILS if the attack succeeds (gauge drains gauge2).
        assertApproxEqAbs(
            rifToken.balanceOf(address(gauge)),
            rifToken.balanceOf(address(gauge2)),
            1e15,
            "rewards were diverted by the post-periodFinish allocation"
        );
    }

    /**
     * @notice Same attack, followed all the way to what the backers can actually CLAIM.
     *  alice backs `gauge`, bob backs `gauge2`, both with 10 stRIF during the rewarded cycle, so
     *  each should end up claiming the same backer rewards. After alice's pollution allocation,
     *  she walks away with ~all backer rewards while bob is left with ~nothing.
     *  This assertion FAILS while the attack succeeds.
     */
    function test_attack_backerRewardsStolenEndToEnd() public {
        // GIVEN alice backs gauge and bob backs gauge2 with identical 10 stRIF allocations
        vm.prank(alice);
        backersManager.allocate(gauge, 10 ether);
        vm.prank(bob);
        backersManager.allocate(gauge2, 10 ether);

        // AND the cycle ends; allocations are still open before startDistribution()
        _skipToStartDistributionWindow();

        // WHEN alice tries to front-run the distribution — this is now blocked
        vm.expectRevert(BackersManagerRootstockCollective.CycleEnded.selector);
        vm.prank(alice);
        backersManager.allocate(gauge, 10_000 ether);

        // AND the previous cycle's 100 RIF are distributed
        rifToken.mint(address(rewardDistributor), 100 ether);
        vm.prank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(100 ether, 0, 0);
        while (backersManager.onDistributionPeriod()) {
            backersManager.distribute();
        }

        // AND the full cycle elapses so the backer rewards fully accrue, then both backers claim
        _skipAndStartNewCycle();
        vm.prank(alice);
        gauge.claimBackerReward(address(rifToken), alice);
        vm.prank(bob);
        gauge2.claimBackerReward(address(rifToken), bob);

        // THEN alice and bob allocated equally during the rewarded cycle, so they must claim
        // equal backer rewards. This FAILS if the attack succeeds (alice took bob's rewards).
        assertApproxEqAbs(
            rifToken.balanceOf(alice),
            rifToken.balanceOf(bob),
            1e15,
            "alice stole bob's backer rewards via the post-periodFinish allocation"
        );
    }
}
