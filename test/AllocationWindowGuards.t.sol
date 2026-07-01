// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { BaseTest } from "./BaseTest.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { stdStorage, StdStorage } from "forge-std/src/Test.sol";

/**
 * @notice Regression and boundary tests for allocation guards around cycle/distribution windows.
 */
contract AllocationWindowGuardsTest is BaseTest {
    using stdStorage for StdStorage;

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

    /**
     * @notice If the cycle ended and distribution is skipped, allocations remain blocked for the
     * entire distribution window.
     */
    function test_skipDistribution_allocationBlockedUntilWindowEnd() public {
        // GIVEN the cycle just ended and no distribution started
        _skipToStartDistributionWindow();
        uint256 _windowEnd = backersManager.endDistributionWindow(block.timestamp);
        assertFalse(backersManager.onDistributionPeriod());

        // WHEN trying to allocate at different moments before window end
        vm.expectRevert(BackersManagerRootstockCollective.CycleEnded.selector);
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);

        vm.warp(_windowEnd - 1);
        vm.expectRevert(BackersManagerRootstockCollective.CycleEnded.selector);
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
    }

    /**
     * @notice Once the distribution window closes, allocations are enabled again even if no
     * distribution was executed.
     */
    function test_skipDistribution_allocationEnabledAfterWindowEnd() public {
        // GIVEN the cycle ended and no distribution started
        _skipToStartDistributionWindow();
        uint256 _windowEnd = backersManager.endDistributionWindow(block.timestamp);
        assertFalse(backersManager.onDistributionPeriod());

        // WHEN we move to the first second after the distribution window
        vm.warp(_windowEnd);
        vm.prank(alice);
        backersManager.allocate(gauge, 3 ether);

        // THEN allocation succeeds
        assertEq(gauge.allocationOf(alice), 3 ether);
    }

    /**
     * @notice During active distribution, allocate reverts due to distribution-period guard first.
     */
    function test_distributionPeriod_revertPrecedenceNotInDistributionPeriod() public {
        // GIVEN we are in the blocked window and distribution period is active
        _skipToStartDistributionWindow();
        stdstore.target(address(backersManager)).sig("onDistributionPeriod()").checked_write(true);

        // WHEN allocating
        vm.expectRevert(BackersManagerRootstockCollective.NotInDistributionPeriod.selector);
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
    }

    /**
     * @notice At the exact periodFinish timestamp, both allocation entrypoints are blocked.
     */
    function test_boundary_periodFinish_blocksAllocateAndAllocateBatch() public {
        // GIVEN exact periodFinish
        _skipToStartDistributionWindow();
        assertEq(block.timestamp, backersManager.periodFinish());

        // THEN allocate reverts
        vm.expectRevert(BackersManagerRootstockCollective.CycleEnded.selector);
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);

        // THEN allocateBatch reverts
        GaugeRootstockCollective[] memory _gauges = new GaugeRootstockCollective[](1);
        _gauges[0] = gauge;
        uint256[] memory _allocations = new uint256[](1);
        _allocations[0] = 1 ether;

        vm.expectRevert(BackersManagerRootstockCollective.CycleEnded.selector);
        vm.prank(alice);
        backersManager.allocateBatch(_gauges, _allocations);
    }

    /**
     * @notice At the exact endDistributionWindow timestamp, both allocation entrypoints are enabled.
     */
    function test_boundary_endDistributionWindow_allowsAllocateAndAllocateBatch() public {
        // GIVEN the first timestamp after blocked window
        _skipToStartDistributionWindow();
        uint256 _windowEnd = backersManager.endDistributionWindow(block.timestamp);
        vm.warp(_windowEnd);
        assertEq(block.timestamp, _windowEnd);

        // WHEN allocate is called
        vm.prank(alice);
        backersManager.allocate(gauge, 2 ether);
        assertEq(gauge.allocationOf(alice), 2 ether);

        // WHEN allocateBatch is called
        GaugeRootstockCollective[] memory _gauges = new GaugeRootstockCollective[](2);
        _gauges[0] = gauge;
        _gauges[1] = gauge2;
        uint256[] memory _allocations = new uint256[](2);
        _allocations[0] = 3 ether;
        _allocations[1] = 4 ether;

        vm.prank(alice);
        backersManager.allocateBatch(_gauges, _allocations);

        // THEN both allocations are updated
        assertEq(gauge.allocationOf(alice), 3 ether);
        assertEq(gauge2.allocationOf(alice), 4 ether);
    }
}
