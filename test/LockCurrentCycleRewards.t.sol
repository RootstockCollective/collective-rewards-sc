// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";

contract LockCurrentCycleRewards is BaseTest {
    /**
     * SCENARIO: allocate should revert if it is called with arrays with different lengths
     */
    function test_NoAllocationChangeOneCycle() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND alice allocates 1 ether to builder
        backersManager.allocate(gauge, 1 ether);
        vm.stopPrank();

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        backersManager.startDistribution();

        // WHEN half cycle pass
        _skipRemainingCycleFraction(2);

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 0);

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        backersManager.startDistribution();

        _skipRemainingCycleFraction(2);

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 49_999_999_999_999_999_999);

        vm.startPrank(alice);
        gauge.claimBackerReward(alice);
        vm.stopPrank();

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 0);
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);
    }

    /**
     * SCENARIO: allocate should revert if it is called with arrays with different lengths
     */
    function test_AllocationChangeOneCycle() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND alice allocates 1 ether to builder
        backersManager.allocate(gauge, 1 ether);
        vm.stopPrank();

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        backersManager.startDistribution();

        // WHEN half cycle pass
        _skipRemainingCycleFraction(2);

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 0);

        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND alice allocates 0 ether to builder
        backersManager.allocate(gauge, 0);
        vm.stopPrank();

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        backersManager.startDistribution();

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 24_999_999_999_999_999_999);
        assertEq(gauge.earned(address(rewardToken), alice), 24_999_999_999_999_999_999);

        vm.startPrank(alice);
        gauge.claimBackerReward(alice);
        vm.stopPrank();

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 0);
        assertEq(rewardToken.balanceOf(alice), 24_999_999_999_999_999_999);
    }

    /**
     * SCENARIO: allocate should revert if it is called with arrays with different lengths
     */
    function test_MultipleAllocationChangeOneCycle() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND alice allocates 1 ether to builder
        backersManager.allocate(gauge, 4 ether);
        vm.stopPrank();

        // GIVEN a BackerManager contract
        vm.startPrank(bob);
        // AND alice allocates 1 ether to builder
        backersManager.allocate(gauge, 4 ether);
        vm.stopPrank();

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        backersManager.startDistribution();

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        backersManager.startDistribution();

        // WHEN half cycle pass
        skip(3 days);

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 24_999_999_999_999_999_996);

        vm.startPrank(alice);
        backersManager.allocate(gauge, 0);
        skip(1 days);
        backersManager.allocate(gauge, 4 ether);
        skip(1 days);
        backersManager.allocate(gauge, 0);
        skip(1 days);
        backersManager.allocate(gauge, 4 ether);
        vm.stopPrank();

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 24_999_999_999_999_999_996);

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        backersManager.startDistribution();

        // WHEN half cycle pass
        _skipRemainingCycleFraction(2);

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 42_857_142_857_142_857_136);
        assertEq(gauge.earned(address(rewardToken), alice), 55_357_142_857_142_857_132);

        vm.startPrank(alice);
        gauge.claimBackerReward(alice);
        vm.stopPrank();

        assertEq(gauge.claimableBackerRewards(address(rewardToken), alice), 0);
        assertEq(rewardToken.balanceOf(alice), 42_857_142_857_142_857_136);
    }
}
