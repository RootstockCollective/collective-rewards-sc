// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "../BaseTest.sol";

/**
 * @title Different Reward Percentages Tests
 * @notice This test cases cover realistic scenarios, where there a are a few Builders, with
 * different reward distributions percentages and some backers distribute allocations along them
 */
contract DifferentRewardPercentages is BaseTest {
    function _setUp() internal override {
        // start a new cycle with an empty distribution
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        _distribute(0, 0);

        // There are 5 builders
        // builder - builder2 with 50% backer reward percentage
        // builder3 has 30% backer reward percentage
        address _builder3 = makeAddr("builder3");
        _whitelistBuilder(_builder3, _builder3, 0.3 ether);
        // builder4 has 70% backer reward percentage
        address _builder4 = makeAddr("builder4");
        _whitelistBuilder(_builder4, _builder4, 0.7 ether);
        // builder5 has 100% backer reward percentage
        address _builder5 = makeAddr("builder5");
        _whitelistBuilder(_builder5, _builder5, 1 ether);
    }

    /* 
     * SCENARIO: there are several builders with different backer rewards percentage. They all receive the correct
     *  amount of rewards
     */
    function test_integration_DifferentBackerRewardPercentage() public {
        // GIVEN alice gives 1 eth vote to every gauge
        allocationsArray = [1 ether, 1 ether, 1 ether, 1 ether, 1 ether];
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob gives 2 eth votes to gauge 1, 3 and 5 each
        vm.startPrank(bob);
        backersManager.allocate(gauge, 2 ether);
        backersManager.allocate(gaugesArray[2], 1 ether);
        backersManager.allocate(gaugesArray[4], 2 ether);
        vm.stopPrank();

        // THEN totalPotentialReward is 10 ether (votes) * 604800 (cycle duration)
        assertEq(backersManager.totalPotentialReward(), 6_048_000 ether);
        // AND gauge and gauge 2 are incetivized with 100 ether in rewardToken and 100 coinbase
        _incentivize(gauge, 100 ether, 100 ether);
        _incentivize(gauge2, 100 ether, 100 ether);
        // AND there is a distribution of 100 rewardToken and 100 coinbase
        _distribute(100 ether, 100 ether);

        // Total votes: 10
        // Total rewards from distribution: 100 ether in rewardToken - 100 ether in coinbase
        // Rewards:
        //    gauge1 (3 votes):
        //        100/10 * 3 rewardToken = 30 eth
        //        100/10 * 3 coinbase = 30 eth
        //    gauge2 (1 vote):
        //        100/10 * 1 rewardToken = 10 eth
        //        100/10 * 1 coinbase = 10 eth
        //    gauge3 (2 votes):
        //        100/10 * 2 rewardToken = 20 eth
        //        100/10 * 2 coinbase = 20 eth
        //    gauge4 (1 vote):
        //        100/10 * 1 rewardToken = 10 eth
        //        100/10 * 1 coinbase = 10 eth
        //    gauge5 (3 votes):
        //        100/10 * 3 rewardToken = 30 eth
        //        100/10 * 3 coinbase = 30 eth

        // AND cycle finishes
        _skipAndStartNewCycle();
        // AND alice claims rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // gauge 1 (1/3 votes - 50% br%) = 1/3 * (30 eth * 50% + 100 eth) = 38.33 eth
        // gauge 2 (1/1 votes - 50% br%) = 1/1 * (10 eth * 50% + 100 eth) = 105 eth
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (1/1 votes - 70% br%) = 1/1 * (10 eth * 70%) = 7 eth
        // gauge 5 (1/3 votes - 100% br%) = 1/3 * (30 eth * 100%) = 10 eth
        // total = 163.33
        assertEq(_clearERC20Balance(alice), 163_333_333_333_333_333_327);
        // THEN alice receives coinbase
        // gauge 1 (1/3 votes - 50% br%) = 1/3 * (30 eth * 50% + 100 eth) = 38.33 eth
        // gauge 2 (1/1 votes - 50% br%) = 1/1 * (10 eth * 50% + 100 eth) = 105 eth
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (1/1 votes - 70% br%) = 1/1 * (10 eth * 70%) = 7 eth
        // gauge 5 (1/3 votes - 100% br%) = 1/3 * (30 eth * 100%) = 10 eth
        // total = 163.33 eth
        assertEq(_clearCoinbaseBalance(alice), 163_333_333_333_333_333_327);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives rewardToken
        // gauge 1 (2/3 votes - 50% br%) = 2/3 * (30 eth * 50% + 100 eth) = 76.66 eth
        // gauge 2 (0 votes - 50% br%) = 0
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (0 votes - 70% br%) = 0
        // gauge 5 (2/3 votes - 100% br%) = 2/3 * (30 eth * 100%) = 20 eth
        // total = 96.66 eth
        assertEq(_clearERC20Balance(bob), 99_666_666_666_666_666_661);
        // THEN bob receives coinbase
        // gauge 1 (2/3 votes - 50% br%) = 2/3 * (30 eth * 50% + 100 eth) = 76.66 eth
        // gauge 2 (0 votes - 50% br%) = 0
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (0 votes - 70% br%) = 0
        // gauge 5 (2/3 votes - 100% br%) = 2/3 * (30 eth * 100%) = 20 eth
        // total = 96.66 eth
        assertEq(_clearCoinbaseBalance(bob), 99_666_666_666_666_666_661);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN builder receives rewardToken: 30 eth * 50% = 15 eth
        assertEq(_clearERC20Balance(builder), 15 ether);
        // THEN builder receives coinbase: 30 eth * 50% = 15 eth
        assertEq(_clearCoinbaseBalance(builder), 15 ether);

        // THEN builder2 receives rewardToken: 10 eth * 50% = 5 eth
        assertEq(_clearERC20Balance(builder2Receiver), 5 ether);
        // THEN builder receives coinbase: 10 eth * 50% = 5 eth
        assertEq(_clearCoinbaseBalance(builder2Receiver), 5 ether);

        // THEN builder 3 receives rewardToken: 20 eth * 70% = 14 eth
        assertEq(_clearERC20Balance(builders[2]), 14 ether);
        // THEN builder 3 receives coinbase: 20 eth * 70% = 14 eth
        assertEq(_clearCoinbaseBalance(builders[2]), 14 ether);

        // THEN builder 4 receives rewardToken: 10 eth * 30% = 3 eth
        assertEq(_clearERC20Balance(builders[3]), 3 ether);
        // THEN builder 4 receives coinbase: 10 eth * 30% = 3 eth
        assertEq(_clearCoinbaseBalance(builders[3]), 3 ether);

        // THEN builder 5 receives 0 rewardToken: 30 * 0%
        assertEq(_clearERC20Balance(builders[4]), 0 ether);
        // THEN builder 5 receives 0 coinbase: 30 * 0%
        assertEq(_clearCoinbaseBalance(builders[4]), 0 ether);
    }

    /* 
    * SCENARIO: there are several builders with different backer rewards percentage and voters remove votes during the
     *  cycle. They all receive the correct amount of rewards
     */
    function test_integration_DifferentBackerRewardPercentageAndChangeInAllocations() public {
        // GIVEN alice gives 1 eth vote to every gauge
        allocationsArray = [1 ether, 1 ether, 1 ether, 1 ether, 1 ether];
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob gives 2 eth votes to gauge 1, 3 and 5 each
        vm.startPrank(bob);
        backersManager.allocate(gauge, 2 ether);
        backersManager.allocate(gaugesArray[2], 1 ether);
        backersManager.allocate(gaugesArray[4], 2 ether);
        vm.stopPrank();

        // THEN totalPotentialReward is 10 ether (votes) * 604800 (cycle duration)
        assertEq(backersManager.totalPotentialReward(), 6_048_000 ether);
        // AND gauge and gauge 2 are incetivized with 100 ether in rewardToken and 100 coinbase
        _incentivize(gauge, 100 ether, 100 ether);
        _incentivize(gauge2, 100 ether, 100 ether);

        // AND half a cycle pases
        _skipRemainingCycleFraction(2);
        // AND alice moves 1 vote from gauge2 to gauge 1 and 1 vote from gauge 4 to gauge 5
        vm.startPrank(alice);
        backersManager.allocate(gauge2, 0 ether);
        backersManager.allocate(gauge, 2 ether);
        backersManager.allocate(gaugesArray[3], 0 ether);
        backersManager.allocate(gaugesArray[4], 2 ether);
        vm.stopPrank();

        // THEN totalPotentialReward did not change
        assertEq(backersManager.totalPotentialReward(), 6_048_000 ether);

        // AND there is a distribution of 100 rewardToken and 100 coinbase
        _distribute(100 ether, 100 ether);

        // Total votes: 10
        // Total rewards from distribution: 100 ether in rewardToken - 100 ether in coinbase
        // Rewards:
        //    gauge1 (3 votes 1/2 cycle - 4 votes 1/2 cycle):
        //        (100/10 * 3 rewardToken * 1/2 cycle) + (100/10 * 4 rewardToken * 1/2 cycle) = 35 eth
        //        (100/10 * 3 coinbase * 1/2 cycle) + (100/10 * 4 coinbase * 1/2 cycle) = 35 eth
        //    gauge2 (1 votes 1/2 cycle):
        //        100/10 * 1 rewardToken * 1/2 cycle  = 5 eth
        //        100/10 * 1 coinbase * 1/2 cycle  = 5 eth
        //    gauge3 (2 votes):
        //        100/10 * 2 rewardToken = 20 eth
        //        100/10 * 2 coinbase = 20 eth
        //    gauge4 (1 vote 1/2 cycle):
        //        100/10 * 1 rewardToken * 1/2 cycle = 5 eth
        //        100/10 * 1 coinbase * 1/2 cycle = 5 eth
        //    gauge5 (3 votes 1/2 cycle - 4 votes 1/2 cycle):
        //        (100/10 * 3 rewardToken * 1/2 cycle) + (100/10 * 4 rewardToken * 1/2 cycle) = 35 eth
        //        (100/10 * 3 coinbase * 1/2 cycle) + (100/10 * 4 coinbase * 1/2 cycle) = 35 eth

        // AND cycle finishes
        _skipAndStartNewCycle();
        // AND alice claims rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // gauge 1 (2/4 votes - 50% br%) = 1/3 * 50 ether (incentive for half cycle) + 2/4 * (35 eth * 50% + 50 eth) =
        // 50.41 eth
        // gauge 2 (1 vote 1/2 cycle for incentive) = 100 eth * 1/2 cycle = 50 eth
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (0 votes - 70% br%) = 0
        // gauge 5 (2/4 votes - 100% br%) = 2/4 * (35 eth * 100%) = 17.5 eth
        // total = 120.91 eth
        assertEq(_clearERC20Balance(alice), 120_916_666_666_666_666_658);
        // THEN alice receives coinbase
        // gauge 1 (2/4 votes - 50% br%) = 1/3 * 50 ether (incentive for half cycle) + 2/4 * (35 eth * 50% + 50 eth) =
        // 50.41 eth
        // gauge 2 (1 vote 1/2 cycle for incentive) = 100 eth * 1/2 cycle = 50 eth
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (0 votes - 70% br%) = 0
        // gauge 5 (2/4 votes - 100% br%) = 2/4 * (35 eth * 100%) = 17.5 eth
        // total = 120.91 eth
        assertEq(_clearCoinbaseBalance(alice), 120_916_666_666_666_666_658);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives rewardToken
        // gauge 1 (2/4 votes - 50% br%) = 2/3 * 50 ether (incentive for half cycle) + 2/4 * (35 eth * 50% + 50 eth) =
        // 67.08 eth
        // gauge 2 (0 votes - 50% br%) = 0
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (0 votes - 50% br%) = 0
        // gauge 5 (2/4 votes - 100% br%) = 2/4 * (35 eth * 100%) = 17.5 eth
        // total = 87.58 eth
        assertEq(_clearERC20Balance(bob), 87_583_333_333_333_333_325);
        // THEN bob receives coinbase
        // gauge 1 (2/4 votes - 50% br%) = 2/3 * 50 ether (incentive for half cycle) + 2/4 * (35 eth * 50% + 50 eth) =
        // 67.08 eth
        // gauge 2 (0 votes - 50% br%) = 0
        // gauge 3 (1/2 votes - 30% br%) = 1/2 * (20 eth * 30%) = 3 eth
        // gauge 4 (0 votes - 50% br%) = 0
        // gauge 5 (2/4 votes - 100% br%) = 2/4 * (35 eth * 100%) = 17.5 eth
        // total = 87.58 eth
        assertEq(_clearCoinbaseBalance(bob), 87_583_333_333_333_333_325);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN builder receives rewardToken: 35 eth * 50% = 17.5 eth
        assertEq(_clearERC20Balance(builder), 17.5 ether);
        // THEN builder receives coinbase: 35 eth * 50% = 17.5 eth
        assertEq(_clearCoinbaseBalance(builder), 17.5 ether);

        // THEN builder2 receives rewardToken: 5 eth * 50% = 2.5 eth
        assertEq(_clearERC20Balance(builder2Receiver), 2.5 ether);
        // THEN builder receives coinbase: 5 eth * 50% = 2.5 eth
        assertEq(_clearCoinbaseBalance(builder2Receiver), 2.5 ether);

        // THEN builder 3 receives rewardToken: 20 eth * 70% = 14 eth
        assertEq(_clearERC20Balance(builders[2]), 14 ether);
        // THEN builder 3 receives coinbase: 20 eth * 70% = 14 eth
        assertEq(_clearCoinbaseBalance(builders[2]), 14 ether);

        // THEN builder 4 receives rewardToken: 5 eth * 30% = 1.5 eth
        assertEq(_clearERC20Balance(builders[3]), 1.5 ether);
        // THEN builder 4 receives coinbase: 5 eth * 30% = 1.5 eth
        assertEq(_clearCoinbaseBalance(builders[3]), 1.5 ether);

        // THEN builder 5 receives 0 rewardToken: 35 * 0%
        assertEq(_clearERC20Balance(builders[4]), 0 ether);
        // THEN builder 5 receives 0 coinbase: 35 * 0%
        assertEq(_clearCoinbaseBalance(builders[4]), 0 ether);
    }
}
