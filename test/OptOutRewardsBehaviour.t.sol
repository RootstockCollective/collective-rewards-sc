// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, BackersManagerRootstockCollective } from "./BaseTest.sol";

contract OptOutRewardsBehaviour is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event BackerRewardsOptedOut(address indexed backer_);
    event BackerRewardsOptedIn(address indexed backer_);

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
     * SCENARIO: OptOut Backer cannot claim
     */
    function test_OptOutClaimRevert() public {
        // GIVEN alice OptOut of rewards
        vm.startPrank(alice);
        backersManager.optOutRewards(alice);
        // AND it allocates
        backersManager.allocate(gauge, 0.1 ether);

        //  WHEN alice tries to claim
        //   THEN tx reverts because OptedOut
        vm.expectRevert(BackersManagerRootstockCollective.BackerOptedOutRewards.selector);
        gauge.claimBackerReward(alice);
    }

    /**
     * SCENARIO: OptedOut backer can allocate but does not receive rewards and does not affect other backers rewards
     */
    function test_OptOutAllocationsNotImpactBackersRewards() public {
        // GIVEN alice is OptOut
        vm.prank(alice);
        backersManager.optOutRewards(alice);
        //  AND alice allocates
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        //  AND bob allocates
        vm.prank(bob);
        backersManager.allocate(gauge, 0.1 ether);

        // WHEN the cycle ends and the rewards are distributed
        uint256 _distributedAmountRif = 10 ether;
        uint256 _distributedAmountCoinbase = 10 ether;
        _distribute(_distributedAmountRif, _distributedAmountCoinbase);
        _skipAndStartNewCycle();

        // THEN bob receives half the rewards (gauge backers percentage is 50%)
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        assertApproxEqAbs(rewardToken.balanceOf(bob), _distributedAmountRif / 2, 1);
        assertApproxEqAbs(bob.balance, _distributedAmountCoinbase / 2, 1);
    }

    /**
     * SCENARIO: OptedOut backer allocattions affects builders rewards
     */
    function test_OptOutAllocationsImpactBuilderRewards() public {
        // GIVEN alice is OptOut
        vm.prank(alice);
        backersManager.optOutRewards(alice);
        //  AND alice allocates to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        //  AND bob allocates to 2 gauges
        vm.prank(bob);
        backersManager.allocate(gauge, 0.1 ether);
        vm.prank(bob);
        backersManager.allocate(gauge2, 0.1 ether);

        // WHEN the cycle ends and the rewards are distributed
        uint256 _distributedAmountRif = 10 ether;
        uint256 _distributedAmountCoinbase = 10 ether;
        _distribute(_distributedAmountRif, _distributedAmountCoinbase);
        _skipAndStartNewCycle();

        // AND the builders claims the rewards
        uint256 _buildersRifReward = _distributedAmountRif / 2; // 50% of the rewards
        uint256 _buildersCoinbaseReward = _distributedAmountCoinbase / 2;
        vm.prank(builder);
        gauge.claimBuilderReward();
        vm.prank(builder2);
        gauge2.claimBuilderReward();

        // THEN builder should receive 2/3 of all builder rewards, proportional to the total allocations
        assertApproxEqAbs(rewardToken.balanceOf(builder), (_buildersRifReward * 2) / 3, 1);
        assertApproxEqAbs(rewardToken.balanceOf(builder2Receiver), (_buildersCoinbaseReward * 1) / 3, 1);
    }
}
