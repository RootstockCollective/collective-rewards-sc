pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { console } from "forge-std/src/console.sol";
// solhint-disable no-console

contract RewardRateManipulationTest is BaseTest {
    /**
     * SCENARIO: The reward rate is not affected
     */
    function test_RewardRateNoIssue() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has rewardToken
        // AND the Incentivizer has minted some rewardToken to itself
        // AND the Incentivizer has approved the gauge to spend the rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount);
        rewardToken.approve(address(gauge), 100 ether + _minIncentiveAmount);
        // WHEN 1 day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether, address(rewardToken));
        console.log("Incentivizing 100 Eth");
        console.log("RewardRate 1: %d", gauge.rewardRate(address(rewardToken)));
        console.log(
            "In this test case, we wait one day, showing that the rate cannot be manipulated depending on the time of the call"
        );
        // AND 1 additional day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND almost-0-ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(_minIncentiveAmount, address(rewardToken));
        console.log("Incentivizing 100 wei");
        console.log("RewardRate 2: %d", gauge.rewardRate(address(rewardToken)));
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        vm.stopPrank();
        // AND Alice and Bob allocate 1 ether each
        console.log("Alice and bob allocate 1 ether each");
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.startPrank(bob);
        backersManager.allocate(gauge, 1 ether);
        // AND 1st cycle is started
        _skipAndStartNewCycle();
        console.log("Reward missing before distribution", gauge.rewardMissing(address(rewardToken)));
        backersManager.startDistribution();
        console.log("Reward missing after distribution", gauge.rewardMissing(address(rewardToken)));
        // AND 2nd cycle is started
        console.log("Skip a new cycle so the rewards missing is distributed");
        _skipAndStartNewCycle();
        // THEN alice and bob has rewards to claim: (100 eth + 100 wei) / 2 = 50.000000000000000049 each
        console.log("Then alice and bob both earned the correct amount of incentives: (100 eth + 100 wei) / 2");
        assertEq(gauge.earned(address(rewardToken), alice), 50_000_000_000_000_000_049);
        assertEq(gauge.earned(address(rewardToken), bob), 50_000_000_000_000_000_049);
    }

    /**
     * SCENARIO: The reward missing is distributed to backers on the next cycle
     */
    function test_RewardRateNoChangesWithIncentivization() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has rewardToken
        // AND the Incentivizer has minted some rewardToken to itself
        // AND the Incentivizer has approved the gauge to spend the rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount);
        rewardToken.approve(address(gauge), 100 ether + _minIncentiveAmount);
        // WHEN 1 day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether, address(rewardToken));
        console.log("Incentivizing 100 Eth");
        uint256 _rewardRateBefore = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate before: %d", _rewardRateBefore);
        // AND 1 additional day passes
        console.log("Waiting a day.");
        skip(1 days);
        // We skip the almost-0-eth that should have no effect
        console.log("We skip Incentivizing 100 wei, should have almost no effect.");
        uint256 _rewardRateAfter = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate after: %d", _rewardRateAfter);
        assertEq(_rewardRateBefore, _rewardRateAfter);
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        vm.stopPrank();
        // AND Alice and Bob allocate 1 ether each
        console.log("Alice and bob allocate 1 ether each");
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.startPrank(bob);
        backersManager.allocate(gauge, 1 ether);
        // AND 1st cycle is started
        _skipAndStartNewCycle();
        console.log("Reward missing before distribution", gauge.rewardMissing(address(rewardToken)));
        backersManager.startDistribution();
        console.log("Reward missing after distribution", gauge.rewardMissing(address(rewardToken)));
        // AND 2nd cycle is started
        console.log("Skip a new cycle so the rewards missing is distributed");
        _skipAndStartNewCycle();

        // THEN alice and bob has rewards to claim: 100 eth / 2 = 49.999999999999999999 each
        console.log("Then alice and bob both earned the correct amount of incentives: 100 eth / 2");
        assertEq(gauge.earned(address(rewardToken), alice), 49_999_999_999_999_999_999);
        assertEq(gauge.earned(address(rewardToken), bob), 49_999_999_999_999_999_999);
    }

    /**
     * SCENARIO: The reward missing is not distributed to backer on the same cycle
     */
    function test_RewardMissingNoDistributedToBackerOnSameCycle() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has rewardToken
        // AND the Incentivizer has minted some rewardToken to itself
        // AND the Incentivizer has approved the gauge to spend the rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount + _minIncentiveAmount);
        rewardToken.approve(address(gauge), 100 ether + _minIncentiveAmount + _minIncentiveAmount);
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rewardToken)));
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether, address(rewardToken));
        console.log("Incentivizing 100 Eth");
        console.log("RewardRate 1: %d", gauge.rewardRate(address(rewardToken)));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rewardToken)));
        // WHEN 5.5 days passes
        skip(5.5 days);
        // AND almost-0-ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(_minIncentiveAmount, address(rewardToken));
        console.log("Incentivizing 100 wei");
        console.log("RewardRate 2: %d", gauge.rewardRate(address(rewardToken)));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rewardToken)));
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        // AND additional half day passes
        skip(0.5 days);
        // AND almost-0-ether are distributed by Incentivizer by 2nd time
        console.log("Incentivizing 100 wei");
        gauge.incentivizeWithRewardToken(_minIncentiveAmount, address(rewardToken));
        vm.stopPrank();
        // AND Alice allocate 1 ether
        vm.startPrank(alice);
        console.log("Alice allocate 1");
        backersManager.allocate(gauge, 1 ether);
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rewardToken)));
        // AND 1st cycle is started
        _skipAndStartNewCycle();
        console.log("Earned: %d", gauge.earned(address(rewardToken), alice));
        uint256 _rewardMissingBeforeClaim = gauge.rewardMissing(address(rewardToken));
        console.log("Reward Missing Before Claim: %d", _rewardMissingBeforeClaim);
        // AND alice claims rewards
        console.log("Claiming rewards.");
        gauge.claimBackerReward(alice);
        uint256 _rewardMissingAfterClaim = gauge.rewardMissing(address(rewardToken));
        console.log("Reward Missing After Claim: %d", _rewardMissingAfterClaim);
        // The next 2 lines shows the issue
        console.log("Backer Balance: %d", rewardToken.balanceOf(alice));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rewardToken)));

        // THEN rewardMissing should not be decreased by the amount of the reward claimed
        assertEq(_rewardMissingBeforeClaim, _rewardMissingAfterClaim);
    }
}
