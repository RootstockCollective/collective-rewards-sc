// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, BackersManagerRootstockCollective, GaugeRootstockCollective } from "./BaseTest.sol";

contract OptOutRewardsBehaviour is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event BackerRewardsOptedOut(address indexed backer_);
    event BackerRewardsOptedIn(address indexed backer_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event OptedOutBackerRewardsCollected(address indexed rewardToken_, address indexed backer_, uint256 amount_);

    GaugeRootstockCollective[] public gauges;

    /**
     * SCENARIO: Can only OptOut if not already opted out
     */
    function test_OptOutAlreadyOptedOut() public {
        // GIVEN alice OptOut
        vm.startPrank(alice);
        backersManager.optOutRewards(alice);
        //  WHEN alice tries to OptOut again
        //   THEN tx reverts because AlreadyOptedOut
        vm.expectRevert(BackersManagerRootstockCollective.BackerOptedOutRewards.selector);
        backersManager.optOutRewards(alice);
    }

    /**
     * SCENARIO: Can only OptIn if already opted out
     */
    function test_OptInWhileNotOptedOutRevert() public {
        // GIVEN alice tries to OptIn
        vm.startPrank(alice);
        //   THEN tx reverts because is not opted out
        vm.expectRevert(BackersManagerRootstockCollective.AlreadyOptedInRewards.selector);
        backersManager.optInRewards(alice);
    }

    /**
     * SCENARIO: Only KYC approver or the backer itself can OptOut
     */
    function test_OptOutAuthorization() public {
        //  GIVEN alice tries to OptOut Bob
        vm.prank(alice);
        //   THEN tx reverts because NotAuthorized
        vm.expectRevert(BackersManagerRootstockCollective.NotAuthorized.selector);
        backersManager.optOutRewards(bob);

        //  GIVEN KYC approver tries to OptOut Bob
        vm.prank(kycApprover);
        //   THEN tx is successful
        vm.expectEmit();
        emit BackerRewardsOptedOut(bob);
        backersManager.optOutRewards(bob);

        // GIVEN alice tries to OptOut
        vm.prank(alice);
        //   THEN tx is successful
        vm.expectEmit();
        emit BackerRewardsOptedOut(alice);
        backersManager.optOutRewards(alice);
    }

    /**
     * SCENARIO: Backer can only OptOut if has no allocations
     */
    function test_OptOutWithAllocation() public {
        // GIVEN alice allocates 0.1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        //  WHEN alice tries to OptOut
        //   THEN tx reverts because BackerHasAllocations
        vm.expectRevert(BackersManagerRootstockCollective.BackerHasAllocations.selector);
        backersManager.optOutRewards(alice);
        //  WHEN alice removes the allocation
        backersManager.allocate(gauge, 0 ether);
        //  THEN alice can OptOut
        vm.expectEmit();
        emit BackerRewardsOptedOut(alice);
        backersManager.optOutRewards(alice);
    }

    /**
     * SCENARIO: OptOut Backer can allocate but not claim
     */
    function test_OptOutAndClaimReverts() public {
        gauges.push(gauge);
        // GIVEN alice OptOut
        vm.prank(alice);
        backersManager.optOutRewards(alice);
        //  AND alice allocates
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        _distribute(100 ether, 10 ether);
        _skipAndStartNewCycle();

        // THEN alice should not be able to claim
        vm.expectRevert(BackersManagerRootstockCollective.BackerOptedOutRewards.selector);
        vm.prank(alice);
        backersManager.claimBackerRewards(gauges);
    }

    /**
     * SCENARIO: OptOut Backer rewards can be reused by the backers manager in the next distribution
     */
    function test_OptOutRewardsReused() public {
        // uint256 _aliceRewards = gauge.rewards(address(rewardToken), alice);
        gauges.push(gauge);
        // GIVEN alice OptOut
        vm.prank(alice);
        backersManager.optOutRewards(alice);
        //  AND alice allocates
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        _distribute(100 ether, 10 ether);
        _skipAndStartNewCycle();

        // THEN alice rewards should be sent to the backers manager
        // TODO: improve testing, for POC is ok.
        vm.assertEq(address(backersManager).balance, 0);
        vm.assertEq(rewardToken.balanceOf(address(backersManager)), 0);

        backersManager.collectOptedOutRewards(alice, gauges);

        vm.assertGt(address(backersManager).balance, 0);
        vm.assertGt(rewardToken.balanceOf(address(backersManager)), 0);
    }
}
