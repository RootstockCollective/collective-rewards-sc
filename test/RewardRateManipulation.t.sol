pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { console } from "forge-std/src/console.sol";
// solhint-disable no-console

contract RewardRateManipulationTest is BaseTest {
    /**
     * SCENARIO: The reward rate is not affected
     */
    function test_RewardRateNoChangesWithIncentivizationRifToken() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has rifToken
        // AND the Incentivizer has minted some rifToken to itself
        // AND the Incentivizer has approved the gauge to spend the rifToken
        vm.startPrank(incentivizer);
        rifToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount);
        rifToken.approve(address(gauge), 100 ether + _minIncentiveAmount);
        // WHEN 1 day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRifToken(100 ether);
        console.log("Incentivizing 100 Eth");
        console.log("RewardRate 1: %d", gauge.rewardRate(address(rifToken)));
        console.log(
            "In this test case, we wait one day, showing that the rate cannot be manipulated depending on the time of the call"
        );
        // AND 1 additional day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND almost-0-ether are distributed by Incentivizer
        gauge.incentivizeWithRifToken(_minIncentiveAmount);
        console.log("Incentivizing 100 wei");
        console.log("RewardRate 2: %d", gauge.rewardRate(address(rifToken)));
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
        console.log("Reward missing before distribution", gauge.rewardMissing(address(rifToken)));
        backersManager.startDistribution();
        console.log("Reward missing after distribution", gauge.rewardMissing(address(rifToken)));
        // AND 2nd cycle is started
        console.log("Skip a new cycle so the rewards missing is distributed");
        _skipAndStartNewCycle();
        // THEN alice and bob has rewards to claim: (100 eth + 100 wei) / 2 = 50.000000000000000049 each
        console.log("Then alice and bob both earned the correct amount of incentives: (100 eth + 100 wei) / 2");
        assertEq(gauge.earned(address(rifToken), alice), 50_000_000_000_000_000_049);
        assertEq(gauge.earned(address(rifToken), bob), 50_000_000_000_000_000_049);
    }

    /**
     * SCENARIO: The reward rate is not affected with USDRIF token
     */
    function test_RewardRateNoIssueWithIncentivizationUsdrif() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has usdrifToken
        // AND the Incentivizer has minted some usdrifToken to itself
        // AND the Incentivizer has approved the gauge to spend the usdrifToken
        vm.startPrank(incentivizer);
        usdrifToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount);
        usdrifToken.approve(address(gauge), 100 ether + _minIncentiveAmount);
        // WHEN 1 day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithUsdrifToken(100 ether);
        console.log("Incentivizing 100 Eth");
        console.log("RewardRate 1: %d", gauge.rewardRate(address(usdrifToken)));
        console.log(
            "In this test case, we wait one day, showing that the rate cannot be manipulated depending on the time of the call"
        );
        // AND 1 additional day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND almost-0-ether are distributed by Incentivizer
        gauge.incentivizeWithUsdrifToken(_minIncentiveAmount);
        console.log("Incentivizing 100 wei");
        console.log("RewardRate 2: %d", gauge.rewardRate(address(usdrifToken)));
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
        console.log("Reward missing before distribution", gauge.rewardMissing(address(usdrifToken)));
        backersManager.startDistribution();
        console.log("Reward missing after distribution", gauge.rewardMissing(address(usdrifToken)));
        // AND 2nd cycle is started
        console.log("Skip a new cycle so the rewards missing is distributed");
        _skipAndStartNewCycle();
        // THEN alice and bob has rewards to claim: (100 eth + 100 wei) / 2 = 50.000000000000000049 each
        console.log("Then alice and bob both earned the correct amount of incentives: (100 eth + 100 wei) / 2");
        assertEq(gauge.earned(address(usdrifToken), alice), 50_000_000_000_000_000_049);
        assertEq(gauge.earned(address(usdrifToken), bob), 50_000_000_000_000_000_049);
    }

    /**
     * SCENARIO: The reward missing is distributed to backers on the next cycle with RIF token
     */
    function test_RewardRateNoChangesWithIncentivizationRif() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has rifToken
        // AND the Incentivizer has minted some rifToken to itself
        // AND the Incentivizer has approved the gauge to spend the rifToken
        vm.startPrank(incentivizer);
        rifToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount);
        rifToken.approve(address(gauge), 100 ether + _minIncentiveAmount);
        // WHEN 1 day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRifToken(100 ether);
        console.log("Incentivizing 100 Eth");
        uint256 _rewardRateBefore = gauge.rewardRate(address(rifToken));
        console.log("RewardRate before: %d", _rewardRateBefore);
        // AND 1 additional day passes
        console.log("Waiting a day.");
        skip(1 days);
        // We skip the almost-0-eth that should have no effect
        console.log("We skip Incentivizing 100 wei, should have almost no effect.");
        uint256 _rewardRateAfter = gauge.rewardRate(address(rifToken));
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
        console.log("Reward missing before distribution", gauge.rewardMissing(address(rifToken)));
        backersManager.startDistribution();
        console.log("Reward missing after distribution", gauge.rewardMissing(address(rifToken)));
        // AND 2nd cycle is started
        console.log("Skip a new cycle so the rewards missing is distributed");
        _skipAndStartNewCycle();

        // THEN alice and bob has rewards to claim: 100 eth / 2 = 49.999999999999999999 each
        console.log("Then alice and bob both earned the correct amount of incentives: 100 eth / 2");
        assertEq(gauge.earned(address(rifToken), alice), 49_999_999_999_999_999_999);
        assertEq(gauge.earned(address(rifToken), bob), 49_999_999_999_999_999_999);
    }

    /**
     * SCENARIO: The reward missing is distributed to backers on the next cycle with USDRIF token
     */
    function test_RewardRateNoChangesWithIncentivizationUsdrif() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has usdrifToken
        // AND the Incentivizer has minted some usdrifToken to itself
        // AND the Incentivizer has approved the gauge to spend the usdrifToken
        vm.startPrank(incentivizer);
        usdrifToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount);
        usdrifToken.approve(address(gauge), 100 ether + _minIncentiveAmount);
        // WHEN 1 day passes
        console.log("Waiting a day.");
        skip(1 days);
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithUsdrifToken(100 ether);
        console.log("Incentivizing 100 Eth");
        uint256 _rewardRateBefore = gauge.rewardRate(address(usdrifToken));
        console.log("RewardRate before: %d", _rewardRateBefore);
        // AND 1 additional day passes
        console.log("Waiting a day.");
        skip(1 days);
        // We skip the almost-0-eth that should have no effect
        console.log("We skip Incentivizing 100 wei, should have almost no effect.");
        uint256 _rewardRateAfter = gauge.rewardRate(address(usdrifToken));
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
        console.log("Reward missing before distribution", gauge.rewardMissing(address(usdrifToken)));
        backersManager.startDistribution();
        console.log("Reward missing after distribution", gauge.rewardMissing(address(usdrifToken)));
        // AND 2nd cycle is started
        console.log("Skip a new cycle so the rewards missing is distributed");
        _skipAndStartNewCycle();

        // THEN alice and bob has rewards to claim: 100 eth / 2 = 49.999999999999999999 each
        console.log("Then alice and bob both earned the correct amount of incentives: 100 eth / 2");
        assertEq(gauge.earned(address(usdrifToken), alice), 49_999_999_999_999_999_999);
        assertEq(gauge.earned(address(usdrifToken), bob), 49_999_999_999_999_999_999);
    }

    /**
     * SCENARIO: The reward missing is not distributed to backer on the same cycle with RIF token
     */
    function test_RewardMissingNoDistributedToBackerOnSameCycleRif() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has rifToken
        // AND the Incentivizer has minted some rifToken to itself
        // AND the Incentivizer has approved the gauge to spend the rifToken
        vm.startPrank(incentivizer);
        rifToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount + _minIncentiveAmount);
        rifToken.approve(address(gauge), 100 ether + _minIncentiveAmount + _minIncentiveAmount);
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rifToken)));
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRifToken(100 ether);
        console.log("Incentivizing 100 Eth");
        console.log("RewardRate 1: %d", gauge.rewardRate(address(rifToken)));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rifToken)));
        // WHEN 5.5 days passes
        skip(5.5 days);
        // AND almost-0-ether are distributed by Incentivizer
        gauge.incentivizeWithRifToken(_minIncentiveAmount);
        console.log("Incentivizing 100 wei");
        console.log("RewardRate 2: %d", gauge.rewardRate(address(rifToken)));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rifToken)));
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        // AND additional half day passes
        skip(0.5 days);
        // AND almost-0-ether are distributed by Incentivizer by 2nd time
        console.log("Incentivizing 100 wei");
        gauge.incentivizeWithRifToken(_minIncentiveAmount);
        vm.stopPrank();
        // AND Alice allocate 1 ether
        vm.startPrank(alice);
        console.log("Alice allocate 1");
        backersManager.allocate(gauge, 1 ether);
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rifToken)));
        // AND 1st cycle is started
        _skipAndStartNewCycle();
        console.log("Earned: %d", gauge.earned(address(rifToken), alice));
        uint256 _rewardMissingBeforeClaim = gauge.rewardMissing(address(rifToken));
        console.log("Reward Missing Before Claim: %d", _rewardMissingBeforeClaim);
        // AND alice claims rewards
        console.log("Claiming rewards.");
        gauge.claimBackerReward(alice);
        uint256 _rewardMissingAfterClaim = gauge.rewardMissing(address(rifToken));
        console.log("Reward Missing After Claim: %d", _rewardMissingAfterClaim);
        // The next 2 lines shows the issue
        console.log("Backer Balance: %d", rifToken.balanceOf(alice));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(rifToken)));

        // THEN rewardMissing should not be decreased by the amount of the reward claimed
        assertEq(_rewardMissingBeforeClaim, _rewardMissingAfterClaim);
    }

    /**
     * SCENARIO: The reward missing is not distributed to backer on the same cycle with USDRIF token
     */
    function test_RewardMissingNoDistributedToBackerOnSameCycleUsdrif() public {
        uint256 _minIncentiveAmount = 100 wei;
        // GIVEN an Incentivizer has usdrifToken
        // AND the Incentivizer has minted some usdrifToken to itself
        // AND the Incentivizer has approved the gauge to spend the usdrifToken
        vm.startPrank(incentivizer);
        usdrifToken.mint(address(incentivizer), 100 ether + _minIncentiveAmount + _minIncentiveAmount);
        usdrifToken.approve(address(gauge), 100 ether + _minIncentiveAmount + _minIncentiveAmount);
        console.log("Reward Missing: %d", gauge.rewardMissing(address(usdrifToken)));
        // AND 100 ether are distributed by Incentivizer
        gauge.incentivizeWithUsdrifToken(100 ether);
        console.log("Incentivizing 100 Eth");
        console.log("RewardRate 1: %d", gauge.rewardRate(address(usdrifToken)));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(usdrifToken)));
        // WHEN 5.5 days passes
        skip(5.5 days);
        // AND almost-0-ether are distributed by Incentivizer
        gauge.incentivizeWithUsdrifToken(_minIncentiveAmount);
        console.log("Incentivizing 100 wei");
        console.log("RewardRate 2: %d", gauge.rewardRate(address(usdrifToken)));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(usdrifToken)));
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        // AND additional half day passes
        skip(0.5 days);
        // AND almost-0-ether are distributed by Incentivizer by 2nd time
        console.log("Incentivizing 100 wei");
        gauge.incentivizeWithUsdrifToken(_minIncentiveAmount);
        vm.stopPrank();
        // AND Alice allocate 1 ether
        vm.startPrank(alice);
        console.log("Alice allocate 1");
        backersManager.allocate(gauge, 1 ether);
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        console.log("Reward Missing: %d", gauge.rewardMissing(address(usdrifToken)));
        // AND 1st cycle is started
        _skipAndStartNewCycle();
        console.log("Earned: %d", gauge.earned(address(usdrifToken), alice));
        uint256 _rewardMissingBeforeClaim = gauge.rewardMissing(address(usdrifToken));
        console.log("Reward Missing Before Claim: %d", _rewardMissingBeforeClaim);
        // AND alice claims rewards
        console.log("Claiming rewards.");
        gauge.claimBackerReward(alice);
        uint256 _rewardMissingAfterClaim = gauge.rewardMissing(address(usdrifToken));
        console.log("Reward Missing After Claim: %d", _rewardMissingAfterClaim);
        // The next 2 lines shows the issue
        console.log("Backer Balance: %d", usdrifToken.balanceOf(alice));
        console.log("Reward Missing: %d", gauge.rewardMissing(address(usdrifToken)));

        // THEN rewardMissing should not be decreased by the amount of the reward claimed
        assertEq(_rewardMissingBeforeClaim, _rewardMissingAfterClaim);
    }
}
