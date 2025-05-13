// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { stdStorage, StdStorage } from "forge-std/src/Test.sol";
import { BaseTest, GaugeRootstockCollective } from "./BaseTest.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract GaugeRootstockCollectiveTest is BaseTest {
    using stdStorage for StdStorage;
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event BackerRewardsClaimed(address indexed backer_, uint256 amount_);
    event NewAllocation(address indexed backer_, uint256 allocation_, bool isOptedOut_);
    event NotifyReward(address indexed rewardToken_, uint256 builderAmount_, uint256 backersAmount_);

    function _setUp() internal override {
        // mint some rewardTokens and deal to incentivizer
        rewardToken.mint(address(incentivizer), 100_000 ether);
        vm.deal(address(incentivizer), 100_000 ether);
        vm.prank(address(incentivizer));
        rewardToken.approve(address(gauge), 100_000 ether);
        vm.prank(address(incentivizer));
        rewardToken.approve(address(gauge2), 100_000 ether);

        // mint some rewardTokens and deal to backersManager
        rewardToken.mint(address(backersManager), 100_000 ether);
        vm.deal(address(backersManager), 100_000 ether);
        vm.prank(address(backersManager));
        rewardToken.approve(address(gauge), 100_000 ether);
        vm.prank(address(backersManager));
        rewardToken.approve(address(gauge2), 100_000 ether);
    }

    /**
     * SCENARIO: functions protected by onlyBackersManager should revert when are not
     *  called by BackersManagerRootstockCollective contract
     */
    function test_onlyBackersManager() public {
        // GIVEN a backer alice
        vm.startPrank(alice);
        // WHEN alice calls allocate
        //  THEN tx reverts because caller is not the BackersManagerRootstockCollective contract
        uint256 _timeUntilNextCycle = backersManager.timeUntilNextCycle(block.timestamp);
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        gauge.allocate(alice, 1 ether, _timeUntilNextCycle, false);
        // WHEN alice calls notifyRewardAmountAndUpdateShares
        //  THEN tx reverts because caller is not the BackersManagerRootstockCollective contract
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        gauge.notifyRewardAmountAndUpdateShares(1 ether, 1 ether, block.timestamp, _cycleStart, _cycleDuration);
        // WHEN alice calls moveBuilderUnclaimedRewards
        //  THEN tx reverts because caller is not the BackersManagerRootstockCollective contract
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        gauge.moveBuilderUnclaimedRewards(alice);
    }

    /**
     * SCENARIO: functions should revert by NotAuthorized error when are not called by
     *  BackersManagerRootstockCollective or the actor involved
     */
    function test_NotAuthorized() public {
        // GIVEN a backer alice
        vm.startPrank(alice);
        // WHEN alice calls claimBackerReward using bob address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        gauge.claimBackerReward(address(rewardToken), bob);

        // WHEN alice calls claimBackerReward using bob address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        gauge.claimBackerReward(bob);

        // WHEN alice calls claimBuilderReward using builder address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        gauge.claimBuilderReward(address(rewardToken));

        // WHEN alice calls claimBuilderReward using builder address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        gauge.claimBuilderReward();
    }

    /**
     * SCENARIO: BackersManagerRootstockCollective allocates to alice with no rewards distributed
     */
    function test_Allocate() public {
        // GIVEN a new cycle
        _skipAndStartNewCycle();
        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // WHEN alice allocates 1 ether
        //  THEN Allocated event is emitted
        vm.startPrank(alice);
        vm.expectEmit();
        emit NewAllocation(alice, 1 ether, false);
        backersManager.allocate(gauge, 1 ether);

        // THEN alice allocation is 1 ether
        assertEq(gauge.allocationOf(alice), 1 ether);
        // THEN totalAllocation is 1 ether
        assertEq(gauge.totalAllocation(), 1 ether);
        // THEN rewardPerTokenStored is 0 because there are no rewards distributed
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardShares is 302400 ether = 1 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 302_400 ether);
        // THEN rewardPerToken is 0 because there are no rewards distributed
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardPerToken is 0 because there are no rewards distributed
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN alice reward is 0 because there are no rewards distributed
        assertEq(gauge.rewards(address(rewardToken), alice), 0);
        // THEN alice backerRewardPerTokenPaid is 0 because there are no rewards distributed
        assertEq(gauge.backerRewardPerTokenPaid(address(rewardToken), alice), 0);
        // THEN lastUpdateTime is cycle start since there are no rewards distributed
        assertEq(gauge.lastUpdateTime(address(rewardToken)), backersManager.cycleStart(block.timestamp));
    }

    /**
     * SCENARIO: BackersManagerRootstockCollective deallocates to alice with no rewards distributed
     */
    function test_Deallocate() public {
        // GIVEN a new cycle
        _skipAndStartNewCycle();
        // AND alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);

        // WHEN half cycle passes
        _skipRemainingCycleFraction(2);
        // AND alice deallocates all
        //  THEN Allocated event is emitted
        vm.expectEmit();
        emit NewAllocation(alice, 0 ether, false);
        backersManager.allocate(gauge, 0 ether);

        // THEN alice allocation is 0
        assertEq(gauge.allocationOf(alice), 0);
        // THEN totalAllocation is 0
        assertEq(gauge.totalAllocation(), 0);
        // THEN rewardShares is 302400 ether = 1 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 302_400 ether);
        // THEN rewardPerTokenStored is 0 because there are no rewards distributed
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardPerToken is 0 because there are no rewards distributed
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardPerToken is 0 because there are no rewards distributed
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN alice reward is 0 because there are no rewards distributed
        assertEq(gauge.rewards(address(rewardToken), alice), 0);
        // THEN alice backerRewardPerTokenPaid is 0 because there are no rewards distributed
        assertEq(gauge.backerRewardPerTokenPaid(address(rewardToken), alice), 0);
        // THEN lastUpdateTime is cycle start since there are no rewards distributed
        assertEq(gauge.lastUpdateTime(address(rewardToken)), backersManager.cycleStart(block.timestamp));
    }

    /**
     * SCENARIO: BackersManagerRootstockCollective makes a partial deallocation to alice with no rewards distributed
     */
    function test_DeallocatePartial() public {
        // GIVEN a new cycle
        _skipAndStartNewCycle();
        // AND alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);

        // WHEN half cycle passes
        _skipRemainingCycleFraction(2);
        // AND alice deallocates 0.25 ether
        backersManager.allocate(gauge, 0.75 ether);

        // THEN alice allocation is 0.75 ether
        assertEq(gauge.allocationOf(alice), 0.75 ether);
        // THEN totalAllocation is 0.75 ether
        assertEq(gauge.totalAllocation(), 0.75 ether);
        // THEN rewardShares is 529200 ether = 1 * 1/2 WEEK + 0.75 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 529_200 ether);
    }

    /**
     * SCENARIO: notifyRewardAmount with rewards split percentage different than 0
     * rewards variables are updated in the middle and at the end of the cycle
     */
    function test_NotifyRewardAmountWithStrategy() public {
        // GIVEN a builder with 70% of reward percentage for backers
        vm.startPrank(builder);
        builderRegistry.setBackerRewardPercentage(0.7 ether);
        skip(rewardPercentageCooldown);

        // AND 6 ether are allocated to alice
        vm.startPrank(alice);
        backersManager.allocate(gauge, 6 ether);

        // AND 100 rewardToken are distributed
        //  THEN notifyRewardAmount event is emitted
        _skipToStartDistributionWindow();
        rewardToken.mint(address(rewardDistributor), 100 ether);
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 30 ether, 70 ether);
        vm.startPrank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(100 ether, 0);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN periodFinish is updated with the timestamp when the cycle finish
        assertEq(backersManager.periodFinish(), backersManager.cycleNext(block.timestamp));
        // THEN time until next cycle is 1 week
        assertEq(backersManager.periodFinish() - block.timestamp, 1 weeks);
        // THEN rewardRate is 0.000115740740740740 = 70 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 115_740_740_740_740);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN rewardPerToken is 5.833333333333333333 = 604800 / 2 * 0.000115740740740740 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 5_833_333_333_333_333_333);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is 11.666666666666666666 = 604800 * 0.000115740740740740 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 11_666_666_666_666_666_666);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);
    }

    /**
     * SCENARIO: rewards variables for rewardToken are updated in the middle and at the end of the cycle
     */
    function test_IncentivizeWithRewardToken() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 1 days pass
        skip(1 days);

        // WHEN 100 ether are distributed
        //  THEN NotifyReward event is emitted
        vm.startPrank(address(incentivizer));
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0, /*builderAmount_*/ 100 ether);
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN periodFinish is updated with the timestamp when the cycle finish
        assertEq(backersManager.periodFinish(), backersManager.cycleNext(block.timestamp));
        // THEN time until next cycle is 518400
        assertEq(backersManager.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: rewards variables for rewardToken are updated by incentivizer that is not the
     * BackersManagerRootstockCollective
     */
    function test_IncentivizeWithRewardTokenNotFromBackersManagerRootstockCollective() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether);
        rewardToken.approve(address(gauge), 100 ether);

        // AND 1 day passes
        skip(1 days);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: incentivizer tries to send 0 amount and fails with min amount required
     */
    function test_IncentivizeWithZeroAmount() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN 0 ether are distributed by Incentivizer in rewardToken
        // THEN it fails with min amount error
        vm.startPrank(incentivizer);
        vm.expectRevert(GaugeRootstockCollective.NotEnoughAmount.selector);
        gauge.incentivizeWithRewardToken(0 ether);

        // WHEN 10 wei are distributed by Incentivizer
        // THEN it fails with min amount error
        vm.startPrank(incentivizer);
        vm.expectRevert(GaugeRootstockCollective.NotEnoughAmount.selector);
        gauge.incentivizeWithCoinbase{ value: 10 }();

        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0);
    }

    /**
     * SCENARIO: incentivizer does not have enough balance
     */
    // With the latest version of foundry we are getting the error
    // [FAIL: call didn't revert at a lower depth than cheatcode call depth]
    // It is recommended to review these failing tests and either enable revert on
    // internal calls or rewrite tests to avoid this.
    /// forge-config: default.allow_internal_expect_revert = true
    function test_incentivizeWithNotEnoughBalance() public {
        // GIVEN an incentivizer with limited balance
        address _incentivizer2 = makeAddr("incentivizer2");
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(_incentivizer2);
        rewardToken.mint(address(_incentivizer2), 100 ether);
        rewardToken.approve(address(gauge), 50 ether);

        // WHEN 100 ether are distributed by Incentivizer in rewardToken
        //  THEN tx reverts because of insufficient allowance
        vm.expectRevert(GaugeRootstockCollective.NotEnoughAmount.selector);
        gauge.incentivizeWithRewardToken(100 ether);

        // Adjust allowance to be sufficient but reduce balance
        rewardToken.approve(address(gauge), 100 ether);
        rewardToken.burn(address(_incentivizer2), 50 ether);

        // WHEN 100 ether are distributed by Incentivizer in rewardToken
        //  THEN tx reverts because of insufficient balance
        vm.expectRevert(GaugeRootstockCollective.NotEnoughAmount.selector);
        gauge.incentivizeWithRewardToken(100 ether);

        // WHEN 100 ether are distributed by Incentivizer
        //  THEN tx reverts because of insufficient balance
        vm.expectRevert();
        gauge.incentivizeWithCoinbase{ value: 100 ether }();
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer twice in same cycle
     */
    function test_IncentivizeTwiceInSameCycle() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 200 ether);
        rewardToken.approve(address(gauge), 200 ether);

        // AND 1 day passes
        skip(1 days);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // WHEN 100 ether are distributed again by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000578703703703703 = 100 ether / 518400 sec + 100 / (518400 sec/2)
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 578_703_703_703_703);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is
        // 33.333333333333333332 = rewardPerTokenStored +  (604800 * rewardRate / 6 ether)
        // 33.333333333333333332 = 16.666666666666666666 +  (604800 * 0.000165343915343915 / 6 ether)
        assertEq(gauge.rewardPerToken(address(rewardToken)), 33_333_333_333_333_333_332);

        // THEN alice has rewards to claim:
        // 33.333333333333333332 = 1 * rewardPerToken = 1 * 33.333333333333333332
        assertEq(gauge.earned(address(rewardToken), alice), 33_333_333_333_333_333_332);

        // THEN bob has rewards to claim:
        // 166.66666666666666666 = 5 * rewardPerToken = 5 * 33.333333333333333332
        assertEq(gauge.earned(address(rewardToken), bob), 166_666_666_666_666_666_660);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the BackersManagerRootstockCollective using
     * coinbase
     */
    function test_IncentivizeWithCoinbaseNotFromBackersManagerRootstockCollective() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 1 day passes
        skip(1 days);

        // AND an Incentivizer has coinbase
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithCoinbase{ value: 100 ether }();

        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 192_901_234_567_901);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 8_333_333_333_333_333_333);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: there are no initial allocations, incentivizer updates rewards variables and allocations
     * happen after in same first cycle
     */
    function test_IncentivizeBeforeAllocation() public {
        // GIVEN an Incentivizer with rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether);
        rewardToken.approve(address(gauge), 100 ether);

        // AND 1 day passes
        skip(1 days);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);
        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // AND alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // THEN rewardMissing is 49999999999999999999 = 518400 / 2 *  0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 49_999_999_999_999_999_999);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is
        // 8.333333333333333333 = (518400 sec / 2) * rewardRate
        // 8.333333333333333333 = 259200 sec * 0.000192901234567901
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);
        // THEN alice has 1 * rewardPerToken to claim: 8.333333333333333333 = 1 * 8.333333333333333333
        assertEq(gauge.earned(address(rewardToken), alice), 8_333_333_333_333_333_333);
        // THEN bob has 5 * rewardPerToken to claim: 41.666666666666666665 = 5 * 8.333333333333333333
        assertEq(gauge.earned(address(rewardToken), bob), 41_666_666_666_666_666_665);

        // THEN rewardMissing is 49.999999999999999999 = 518400 / 2 *  0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 49_999_999_999_999_999_999);

        // AND 0 rewardToken are distributed
        _distribute(0, 0);

        // THEN rewardRate is 0.000082671957671957 = 50 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 82_671_957_671_957);

        // THEN rewardPerTokenStored is
        // 8.333333333333333333 = rewardMissing / 6 ether
        // 8.333333333333333333 = 49.999999999999999999 / 6 ether
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 8_333_333_333_333_333_333);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 0);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is
        // 16.666666666666666666 = rewardPerTokenStored + 604800 * rewardRate / 6 ether
        // 16.666666666666666666 = 8.333333333333333333 + 604800 * 0.000082671957671957 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // THEN alice has 1 * rewardPerToken to claim: 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), alice), 16_666_666_666_666_666_666);
        // THEN bob has 5 * rewardPerToken to claim: 83.333333333333333333 = 5 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the BackersManagerRootstockCollective when
     * there
     * are no initial allocations in previous cycle, allocations happen in following cycle and all
     * rewards are distributed and claimed by backers with no rewards lost
     */
    function test_IncentivizeWithNoAllocationsInPreviousCycle() public {
        // GIVEN no allocations to gauge
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 200 ether);
        rewardToken.approve(address(gauge), 200 ether);

        // AND 1 day passes
        skip(1 days);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND cycle finishes
        _skipAndStartNewCycle();
        // THEN rewardMissing is 0 since there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for backers
        vm.startPrank(address(backersManager));
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // rewardMissing are updated with all the existing rewards (since there were no allocations), included in the
        // rewardRate for new cycle and set back to 0 in this method
        gauge.notifyRewardAmountAndUpdateShares(
            0 ether, 1 ether, backersManager.periodFinish(), _cycleStart, _cycleDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardMissing is 0 since they were already included in the rewardRate during the distribution
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);

        // AND alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is
        // 16.666666666666666666 = rewardPerTokenStored + 604800 * rewardRate / 6 ether
        // 16.666666666666666666 = 0 + 604800 * 0.000165343915343915 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // THEN alice has 1 * rewardPerToken to claim: 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), alice), 16_666_666_666_666_666_666);
        // THEN bob has 5 * rewardPerToken to claim: 83.333333333333333333 = 5 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), bob), 83_333_333_333_333_333_330);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 1 * rewardPerToken
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);
        // THEN alice has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 5 * rewardPerToken
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
        // THEN bob has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), bob), 0);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the BackersManagerRootstockCollective when
     * there
     * are no initial allocations in first cycle, allocations happen in third cycle, rewards are not locked
     */
    function test_IncentivizeWithNoAllocationsInTwoCycles() public {
        // GIVEN no allocations to gauge
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 200 ether);
        rewardToken.approve(address(gauge), 200 ether);

        // AND 1 day passes
        skip(1 days);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND cycle finishes with no allocations
        _skipAndStartNewCycle();

        // THEN rewardMissing is 0 - there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for backers
        vm.startPrank(address(backersManager));
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            0 ether, 1 ether, backersManager.periodFinish(), _cycleStart, _cycleDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);

        // AND cycle finishes again with no allocations
        _skipAndStartNewCycle();
        // THEN rewardMissing is 0 - there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for backers
        vm.startPrank(address(backersManager));
        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            0 ether, 1 ether, backersManager.periodFinish(), _cycleStart, _cycleDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND half cycle passes
        _skipAndStartNewCycle();

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is 16.666666666666666666 = 604800 * 0.000165343915343915 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 1 * rewardPerToken
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);
        // THEN alice has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 5 * rewardPerToken
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
        // THEN bob has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), bob), 0);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the BackersManagerRootstockCollective and
     * during distribution
     */
    function test_IncentivizeWithIncentivizerAndBackersManagerRootstockCollective() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 1 day passes
        skip(1 days);

        // WHEN 100 ether are distributed by Incentivizer
        vm.prank(incentivizer);
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND cycle finishes
        _skipAndStartNewCycle();
        // AND 100 ether are distributed for backers
        vm.startPrank(address(backersManager));
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            100 ether, 1 ether, backersManager.periodFinish(), _cycleStart, _cycleDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is 16.666666666666666666 = 604800 * 0.000165343915343915 / 6 ether//
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);
        // THEN rewardPerTokenStored is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 16_666_666_666_666_666_666);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is
        // 33.333333333333333332 = rewardPerTokenStored +  (604800 * rewardRate / 6 ether)
        // 33.333333333333333332 = 16.666666666666666666 +  (604800 * 0.000165343915343915 / 6 ether)
        assertEq(gauge.rewardPerToken(address(rewardToken)), 33_333_333_333_333_333_332);

        // THEN alice has rewards to claim:
        // 33.333333333333333332 = 1 * rewardPerToken = 1 * 33.333333333333333332
        assertEq(gauge.earned(address(rewardToken), alice), 33_333_333_333_333_333_332);

        // THEN bob has rewards to claim:
        // 166.66666666666666666 = 5 * rewardPerToken = 5 * 33.333333333333333332
        assertEq(gauge.earned(address(rewardToken), bob), 166_666_666_666_666_666_660);
    }

    /**
     * SCENARIO: trying to incentivize on cycle before distribution finishes should fail
     */
    function test_NotifyRewardAmountIncentivizeInDistributionWindow() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN an Incentivizer has rewardToken and coinbase
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);
        rewardToken.mint(address(incentivizer), 200 ether);
        rewardToken.approve(address(gauge), 200 ether);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // AND cycle finishes
        _skipToStartDistributionWindow();

        // WHEN there is an attempt to distribute 100 ether in rewardToken by Incentivizer
        //  THEN it reverts since distribution has not finished yet
        vm.expectRevert(GaugeRootstockCollective.BeforeDistribution.selector);
        gauge.incentivizeWithRewardToken(100 ether);

        // WHEN there is an attempt to distribute 100 ether in coinbase by Incentivizer
        //  THEN it reverts since distribution has not finished yet
        vm.expectRevert(GaugeRootstockCollective.BeforeDistribution.selector);
        gauge.incentivizeWithCoinbase{ value: 100 ether }();

        // AND distribution finishes with 100 ether being distributed
        vm.startPrank(address(backersManager));
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            100 ether, 1 ether, backersManager.periodFinish(), _cycleStart, _cycleDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardPerToken is
        // 33.333333333333333332 = 604800 * rewardRate / 6 ether
        // 33.333333333333333332 = 604800 * 0.000330687830687830 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 33_333_333_333_333_333_332);

        // THEN alice has rewards to claim:
        // 33.333333333333333332 = 1 * rewardPerToken = 1 * 33.333333333333333332
        assertEq(gauge.earned(address(rewardToken), alice), 33_333_333_333_333_333_332);

        // THEN bob has rewards to claim:
        // 166.66666666666666660 = 5 * rewardPerToken = 5 * 33.333333333333333332
        assertEq(gauge.earned(address(rewardToken), bob), 166_666_666_666_666_666_660);
    }

    /**
     * SCENARIO: builder claim his rewards in another gauge
     */
    function test_ClaimBuilderWrongGauge() public {
        // GIVEN a builder with 30% of reward percentage for backers
        vm.startPrank(builder);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        // GIVEN a builder2 with 15% of reward percentage for backers
        vm.startPrank(builder2);
        builderRegistry.setBackerRewardPercentage(0.15 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge and gauge2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 4 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 300 rewardToken are distributed
        _distribute(300 ether, 0 ether);

        // WHEN builder claims rewards on gauge
        vm.startPrank(builder);
        gauge.claimBuilderReward();
        // THEN builder rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder), 70 ether);
        // WHEN builder claims rewards on gauge2
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        vm.startPrank(builder);
        gauge2.claimBuilderReward();
        // THEN builder rewardToken balance is still 70 ether
        assertEq(rewardToken.balanceOf(builder), 70 ether);

        // WHEN builder2 claims rewards on gauge2
        vm.startPrank(builder2);
        gauge2.claimBuilderReward();
        // THEN builder2Receiver rewardToken balance is 170 ether
        assertEq(rewardToken.balanceOf(builder2Receiver), 170 ether);
    }

    /**
     * SCENARIO: builder claims his rewards at any time during the cycle receiving the total amount of rewards.
     */
    function test_ClaimBuilderRewardsBuilder() public {
        // GIVEN a builder with 30% of reward percentage for backers
        vm.startPrank(builder);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN builderRewards is 70 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 70 ether);

        // AND another cycle finish without a new distribution
        _skipAndStartNewCycle();

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();
        // THEN builder rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder), 70 ether);
        // THEN builder coinbase balance is 70 ether
        assertEq(builder.balance, 70 ether);
    }

    /**
     * SCENARIO: builder claims his rewards at any time during the cycle by asset receiving the total rewards of the
     * asset claimed.
     */
    function test_ClaimBuilderRewardsRewardToken() public {
        // GIVEN a builder with 30% of reward percentage for backers
        vm.startPrank(builder);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // THEN builderRewards is 70 ether in rewardToken and 70 ether in coinbase
        assertEq(gauge.builderRewards(address(rewardToken)), 70 ether);
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 70 ether);

        // AND another cycle finishes without a new distribution
        _skipAndStartNewCycle();

        // WHEN builder claims rewards by rewardToken
        vm.startPrank(builder);
        gauge.claimBuilderReward(address(rewardToken));
        // THEN builder rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder), 70 ether);
        // THEN builderRewards in rewardToken is 0
        assertEq(gauge.builderRewards(address(rewardToken)), 0 ether);
        // THEN builder coinbase balance is 0 ether
        assertEq(builder.balance, 0 ether);
        // THEN builderRewards in coinbase is 70 ether
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 70 ether);
    }

    /**
     * SCENARIO: builder claims his rewards at any time during the cycle by asset receiving the total rewards of the
     * asset claimed.
     */
    function test_ClaimBuilderRewardsCoinbase() public {
        // GIVEN a builder with 30% of reward percentage for backers
        vm.startPrank(builder);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // THEN builderRewards is 70 ether in rewardToken and 70 ether in coinbase
        assertEq(gauge.builderRewards(address(rewardToken)), 70 ether);
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 70 ether);

        // AND another cycle finishes without a new distribution
        _skipAndStartNewCycle();

        // WHEN builder claims rewards by Coinbase
        vm.startPrank(builder);
        gauge.claimBuilderReward(UtilsLib._COINBASE_ADDRESS);
        // THEN builder rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder), 0 ether);
        // THEN builderRewards in rewardToken is 70 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 70 ether);
        // THEN builder coinbase balance is 70 ether
        assertEq(builder.balance, 70 ether);
        // THEN builderRewards in coinbase is 0 ether
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 0 ether);
    }

    /**
     * SCENARIO: reward receiver claims his rewards at any time during the cycle receiving the total amount of rewards.
     */
    function test_ClaimBuilderRewardsRewardReceiver() public {
        // GIVEN a builder2 with 30% of reward percentage for backers
        vm.startPrank(builder2);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge2, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN builderRewards is 70 ether
        assertEq(gauge2.builderRewards(address(rewardToken)), 70 ether);

        // AND another cycle finishes without a new distribution
        _skipAndStartNewCycle();

        // WHEN builder2Receiver claims rewards
        vm.startPrank(builder2Receiver);
        gauge2.claimBuilderReward();
        // THEN builder2Receiver rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder2Receiver), 70 ether);
        // THEN builder2Receiver coinbase balance is 70 ether
        assertEq(builder2Receiver.balance, 70 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // WHEN builder2 claims rewards
        vm.startPrank(builder2);
        gauge2.claimBuilderReward();
        // THEN builder2Receiver rewardToken balance is 140 ether
        assertEq(rewardToken.balanceOf(builder2Receiver), 140 ether);
        // THEN builder2Receiver coinbase balance is 140 ether
        assertEq(builder2Receiver.balance, 140 ether);
    }

    /**
     * SCENARIO: reward receiver tries to claim his rewards with a pending reward receiver address request.
     *           After KYC approval, he can complete the claim.
     */
    function test_ClaimBuilderRewardsRewardReceiverWithUpdate() public {
        // GIVEN a builder2 with 30% of reward percentage
        vm.prank(builder2);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge2, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // THEN builderRewards is 70 ether
        assertEq(gauge2.builderRewards(address(rewardToken)), 70 ether);

        // AND another cycle finishes without a new distribution
        _skipAndStartNewCycle();

        // AND Builder submits a Reward Receiver Request update
        vm.prank(builder2);
        address _newRewardReceiver = makeAddr("newRewardReceiver");
        builderRegistry.requestRewardReceiverUpdate(_newRewardReceiver);

        // WHEN newRewardReceiver tries to claim rewards
        // THEN it fails as there is an active reward receiver update request
        vm.expectRevert(GaugeRootstockCollective.NotAuthorized.selector);
        vm.prank(builder2Receiver);
        gauge2.claimBuilderReward();

        // WHEN builder claims rewards using the builder account
        vm.prank(builder2);
        gauge2.claimBuilderReward();
        // THEN he receives the reward in the original receiver address
        assertEq(rewardToken.balanceOf(builder2Receiver), 70 ether);

        // WHEN KYCApprover approved his Reward Receiver update Request
        vm.prank(kycApprover);
        builderRegistry.approveNewRewardReceiver(builder2, _newRewardReceiver);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // WHEN newRewardReceiver claims his rewards
        vm.prank(_newRewardReceiver);
        gauge2.claimBuilderReward();
        // THEN he receives the reward in the new reward receiver address
        assertEq(rewardToken.balanceOf(_newRewardReceiver), 70 ether);
    }

    /**
     * SCENARIO: there are 2 distributions in the same distribution window, builder claimS the rewards
     */
    function test_ClaimBuilderRewards2Distributions() public {
        // GIVEN a builder with 30% of reward percentage for backers
        vm.startPrank(builder);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND 100 rewardToken and 100 coinbase are distributed in the same distribution window
        vm.warp(backersManager.endDistributionWindow(block.timestamp) - 1);
        rewardToken.mint(address(rewardDistributor), 100 ether);
        vm.deal(address(rewardDistributor), 100 ether);
        vm.startPrank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(100 ether, 100 ether);

        // THEN builderRewards rewardToken is 140 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);
        // THEN builderRewards coinbase is 140 ether
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 140 ether);

        // AND another cycle finish without a new distribution
        _skipAndStartNewCycle();

        // THEN rewardPerToken for rewardToken is 30 = 60 / 2 ether
        assertApproxEqAbs(gauge.rewardPerToken(address(rewardToken)), 30 ether, 100);
        // THEN rewardPerToken for coinbase is 30 = 60 / 2 ether
        assertApproxEqAbs(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 30 ether, 100);

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 140 ether
        assertEq(rewardToken.balanceOf(builder), 140 ether);
        // THEN builder coinbase balance is 140 ether
        assertEq(builder.balance, 140 ether);
    }

    /**
     * SCENARIO: there are 2 cycles, builder claims the rewards
     */
    function test_ClaimBuilderRewards2Cycles() public {
        // GIVEN a builder with 30% of reward percentage for backers
        vm.startPrank(builder);
        builderRegistry.setBackerRewardPercentage(0.3 ether);
        skip(rewardPercentageCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // THEN builderRewards rewardToken is 140 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);
        // THEN builderRewards coinbase is 140 ether
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 140 ether);

        // AND another cycle finishes without a new distribution
        _skipAndStartNewCycle();

        // THEN rewardPerToken for rewardToken is 30 = 60 / 2 ether
        assertApproxEqAbs(gauge.rewardPerToken(address(rewardToken)), 30 ether, 100);
        // THEN rewardPerToken for coinbase is 30 = 60 / 2 ether
        assertApproxEqAbs(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 30 ether, 100);

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 140 ether
        assertEq(rewardToken.balanceOf(builder), 140 ether);
        // THEN builder coinbase balance is 140 ether
        assertEq(builder.balance, 140 ether);
    }

    /**
     * SCENARIO: alice and bob claim their rewards at the end of the cycle receiving the total amount of rewards.
     */
    function test_ClaimBackerRewards() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 100 ether distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND there is a distribution
        _distribute(0, 0);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // time until next cycle is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: alice claims backers rewards on a wrong gauge
     */
    function test_ClaimBackerRewardsWrongGauge() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge2, 5 ether);

        // AND 100 ether distributed for backers on both gauges
        vm.startPrank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);
        gauge2.incentivizeWithRewardToken(100 ether);
        vm.stopPrank();

        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND cycle finishes
        _skipAndStartNewCycle();

        // WHEN alice claims rewards on gauge2
        vm.prank(alice);
        gauge2.claimBackerReward(alice);
        // THEN alice rewardToken balance is 0
        assertEq(rewardToken.balanceOf(alice), 0);

        // WHEN alice claims rewards on gauge
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 100
        assertApproxEqAbs(rewardToken.balanceOf(alice), 100 ether, 10);

        // WHEN bob claims rewards on gauge
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 0
        assertEq(rewardToken.balanceOf(bob), 0);

        // WHEN bob claims rewards on gauge2
        vm.prank(bob);
        gauge2.claimBackerReward(bob);
        // THEN bob rewardToken balance is 100
        assertApproxEqAbs(rewardToken.balanceOf(bob), 100 ether, 10);
    }

    /**
     * SCENARIO: alice and bob claim their rewards in the middle of the cycle receiving partial rewards.
     */
    function test_ClaimBackerRewardsPartial() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND 1/3 cycle passes
        _skipRemainingCycleFraction(3);

        // time until next cycle is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 5.555555555555555555 = 518400 / 3 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 5_555_555_555_555_555_555);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 5.555555555555555555 = 1 * 5.555555555555555555
        assertEq(rewardToken.balanceOf(alice), 5_555_555_555_555_555_555);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 27.777777777777777775 = 5 * 5.555555555555555555
        assertEq(rewardToken.balanceOf(bob), 27_777_777_777_777_777_775);
    }

    /**
     * SCENARIO: alice and bob don't claim on cycle 1 but claim on cycle 2
     *  receiving the 2 reward distributions accumulated
     */
    function test_ClaimBackerRewardsAccumulative() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 100 ether distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // AND 0 rewardToken are distributed
        _distribute(0, 0);

        // AND 200 ether more are distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(200 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN rewardRate is 0.000330687830687830 = 200 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 330_687_830_687_830);

        // AND 0 rewardToken are distributed
        _distribute(0, 0);

        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);

        // THEN rewardPerTokenStored is
        //  49.999999999999999999 = 16.666666666666666666 + 604800 * 0.000330687830687830 / 6 ether
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 49_999_999_999_999_999_999);

        // THEN rewardPerToken is
        //  49.999999999999999999 = 49.999999999999999999 + (604800 * 0 / 6 ether)
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_999);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: there are 2 distributions on the same cycle, alice and bob claim them
     */
    function test_ClaimBackerRewards2DistributionOnSameCycle() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 1 days pass
        skip(1 days);

        // AND 100 ether distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();
        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // AND 200 ether more are distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(200 ether);
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();
        // AND cycle finish
        _skipAndStartNewCycle();

        // time until next cycle is 259200
        // rewardRate = 0.000192901234567901
        // leftover = 259200 * 0.000192901234567901 = 49.9999999999999392
        // THEN rewardRate is 0.000964506172839506 = (200 + 49.9999999999999392) / 259200 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 964_506_172_839_506);

        // AND cycle finishes
        _skipAndStartNewCycle();
        // AND 0 ether are distributed for backers
        _distribute(0, 0);

        // THEN rewardPerToken is
        // rewardPerTokenStored = 8.333333333333333333
        //  49.999999999999999999 = 8.333333333333333333 + 259200 * 0.000964506172839506 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_999);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: alice quits before the cycle finishes, so she receives less rewards and bob more
     */
    function test_ClaimBackerRewardsAliceQuit() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for backers
        vm.prank(address(incentivizer));
        // AND 100 ether distributed for backers
        gauge.incentivizeWithRewardToken(100 ether);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // WHEN alice deallocates all
        vm.prank(alice);
        backersManager.allocate(gauge, 0 ether);

        // time until next cycle is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND 0 ether are distributed for backers
        _distribute(0, 0);

        // THEN rewardPerToken is
        //  18.333333333333333332 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 5 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 18_333_333_333_333_333_332);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 8.333333333333333333 = 1 * 8.333333333333333333
        assertEq(rewardToken.balanceOf(alice), 8_333_333_333_333_333_333);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 91.666666666666666660 = 5 * 18.333333333333333332
        assertEq(rewardToken.balanceOf(bob), 91_666_666_666_666_666_660);
    }

    /**
     * SCENARIO: alice allocates more before the cycle finishes, so she receives more rewards and bob less
     */
    function test_ClaimBackerRewardsAliceAllocatesAgain() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for backers
        vm.prank(address(incentivizer));
        // AND 100 ether distributed for backers
        gauge.incentivizeWithRewardToken(100 ether);

        // AND half cycle passes
        _skipRemainingCycleFraction(2);

        // WHEN alice allocates 1 ether more
        vm.prank(alice);
        backersManager.allocate(gauge, 2 ether);

        // time until next cycle is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND 0 ether are distributed for backers
        _distribute(0, 0);

        // THEN rewardPerToken is
        //  15.476190476190476190 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 7 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 15_476_190_476_190_476_190);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is
        //  22.619047619047619047 = 1 * 8.333333333333333333 + 2 * (15.476190476190476190 - 8.333333333333333333)
        assertEq(rewardToken.balanceOf(alice), 22_619_047_619_047_619_047);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 91.666666666666666660 = 5 * 15.476190476190476190
        assertEq(rewardToken.balanceOf(bob), 77_380_952_380_952_380_950);
    }

    /**
     * SCENARIO: there are remaining rewards after a full deallocation.
     * alice and bob allocate again on the next cycle and receive the missing
     * rewards from the previous one
     */
    function test_ClaimMissingBackerRewardsOnNextCycle() public {
        // GIVEN alice allocates 2 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 2 ether);

        // AND 1 days pass
        skip(1 days);

        // AND 100 ether are distributed for backers
        vm.prank(address(incentivizer));
        // AND 100 ether distributed for backers
        gauge.incentivizeWithRewardToken(100 ether);

        // AND half cycle pass
        _skipRemainingCycleFraction(2);

        // AND alice deallocates all
        vm.prank(alice);
        backersManager.allocate(gauge, 0 ether);

        // time until next cycle is 518400
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);
        // THEN rewardPerTokenStored is 24.999999999999999999 = 518400 / 2 * 0.000192901234567901 / 2 ether
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 24_999_999_999_999_999_999);
        // THEN rewardPerToken is 24.999999999999999999 = 24999999999999999999 + 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 24_999_999_999_999_999_999);

        // AND 0 ether are distributed for backers
        _distribute(0, 0);

        // AND alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // THEN lastUpdateTime is cycle start
        assertEq(gauge.lastUpdateTime(address(rewardToken)), backersManager.cycleStart(block.timestamp));
        // THEN rewardRate is 0.000082671957671957 = (100 ether / 2) / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 82_671_957_671_957);
        // THEN rewardMissing is 49.999999999999999999 = 518400 / 2 * 0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 0);

        // AND 100 ether are distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND 0 ether are distributed for backers
        _distribute(0, 0);

        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);
        // THEN rewardPerToken is
        //  49.999999999999999999 = 24.999999999999999999 + 604800 * 0.000248015873015873 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_998);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is
        //  74.999999999999999997 = 2 * 24.999999999999999999 + 1 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(alice), 74_999_999_999_999_999_997);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 124.999999999999999995 = 5 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(bob), 124_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: alice and bob receive rewards on ERC20
     */
    function test_ClaimERC20Rewards() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // time until next cycle is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(address(rewardToken), alice);
        // THEN alice rewardToken balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(address(rewardToken), bob);
        // THEN bob rewardToken balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: alice and bob receive rewards on Coinbase
     */
    function test_ClaimCoinbaseRewards() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for backers
        vm.prank(address(incentivizer));
        gauge.incentivizeWithCoinbase{ value: 100 ether }();

        // AND cycle finishes
        _skipAndStartNewCycle();

        // time until next cycle is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimBackerReward(UtilsLib._COINBASE_ADDRESS, alice);
        // THEN alice coinbase balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(alice.balance, 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimBackerReward(UtilsLib._COINBASE_ADDRESS, bob);
        // THEN bob coinbase balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(bob.balance, 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: alice and bob claim their rewards at the end of the cycle receiving the total amount of rewards.
     *  alice and bob quit at the end of the cycle, the gauge does not receive any rewards.
     *  alice allocates in the middle of the cycle with no rewards.
     *  If they claim again without a new reward distribution they don't receive rewardTokens again and rewardRate
     *  should be 0.
     */
    function test_ClaimBackerRewardsAfterNoRewards() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        backersManager.allocate(gauge, 5 ether);

        // AND 200 ether with 50% reward percentage are distributed for backers
        _distribute(200 ether, 0);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // time until next cycle is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimBackerReward(bob);
        // THEN bob rewardToken balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);

        // AND alice and bob deallocate all
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0 ether);
        vm.startPrank(bob);
        backersManager.allocate(gauge, 0 ether);

        // AND 0 ether distributed for backers
        vm.startPrank(address(backersManager));
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(0, 1 ether, backersManager.periodFinish(), _cycleStart, _cycleDuration);
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();
        // AND half cycle pass
        _skipRemainingCycleFraction(2);

        // AND 1 ether allocated to alice
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);

        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice rewardToken balance did not change
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)), 0);
    }

    /**
     * SCENARIO: estimated backer rewards with a gauge with no rewards
     */
    function test_EstimatedBackerRewardsWithNoRewards() public {
        // GIVEN there are no allocations in gauge
        //  THEN estimated backer rewards for alice and bob is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 0);

        // WHEN alice allocates 1 ether and bob 5 ether to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // THEN alice and bob estimated rewards are 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 0);

        // AND new cycle starts without a distribution
        _skipAndStartNewCycle();

        // THEN alice and bob estimated rewards are 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 0);
    }

    /**
     * SCENARIO: estimated backer rewards with an incentivized gauge
     */
    function test_EstimatedBackerRewardsIncentivized() public {
        // GIVEN alice allocates 1 ether and bob 5 ether to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN gauge is incentivized
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN alice estimated rewards left to earn is
        // 16.666666666666666666 = allocation * rewardPerToken = 1 * 16.666666666666666666
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 16_666_666_666_666_666_666);
        // AND alice earned rewards is 0
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // THEN bob estimated rewards left to earn is
        //  83.333333333333333332 = allocation * rewardPerToken = 5 * 16.666666666666666666
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 83_333_333_333_333_333_332);
        // AND bob earned rewards is 0
        assertEq(gauge.earned(address(rewardToken), bob), 0);

        // AND 1 / 3 of and epoch passes
        _skipRemainingCycleFraction(3);

        // THEN alice estimated rewards left to earn is
        // 11.111111111111111111 = allocation * rewardPerToken * (2 / 3) = 1 * 16.666666666666666666 * (2 / 3)
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 11_111_111_111_111_111_111);
        // AND alice earned rewards is
        // 5.555555555555555555 = allocation * rewardPerToken * (1 / 3) = 1 * 16.666666666666666666 * (1 / 3) 2
        assertEq(gauge.earned(address(rewardToken), alice), 5_555_555_555_555_555_555);

        // THEN bob estimated rewards left to earn is
        // 55.555555555555555555 = allocation * rewardPerToken * (2 / 3) = 15 * 16.666666666666666666 * (2 / 3)
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 55_555_555_555_555_555_555);
        // THEN bob earned rewards is
        // 27.777777777777777775 = allocation * rewardPerToken * (1 / 3) = 5 * 16.666666666666666666 * (1 / 3)
        assertEq(gauge.earned(address(rewardToken), bob), 27_777_777_777_777_777_775);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN alice estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        // AND alice earned rewards is
        // 16.666666666666666666 = allocation * rewardPerToken = 1 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), alice), 16_666_666_666_666_666_666);

        // THEN bob estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 0);
        // THEN bob earned rewards is
        // 83.333333333333333330 = allocation * rewardPerToken = 5 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: estimated backer rewards after a distribution
     */
    function test_EstimatedBackerRewardsWithDistribution() public {
        // GIVEN alice allocates 1 ether and bob 5 ether to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN there is a distribution of 200 reward token with 50% reward percentage
        _distribute(200 ether, 0 ether);

        // THEN alice estimated rewards left to earn is
        // 16.666666666666666666 = allocation * rewardPerToken = 1 * 16.666666666666666666
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 16_666_666_666_666_666_666);
        // AND alice earned rewards is 0
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // THEN bob estimated rewards left to earn is
        //  83.333333333333333332 = allocation * rewardPerToken = 5 * 16.666666666666666666
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 83_333_333_333_333_333_332);
        // AND bob earned rewards is 0
        assertEq(gauge.earned(address(rewardToken), bob), 0);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN alice estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        // AND alice earned rewards is
        // 16.666666666666666666 = allocation * rewardPerToken = 1 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), alice), 16_666_666_666_666_666_666);

        // THEN bob estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 0);
        // THEN bob earned rewards is
        // 83.333333333333333330 = allocation * rewardPerToken = 5 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: estimated backer rewards with an incentivized gauge after a distribution
     */
    function test_EstimatedBackerRewardsWithDistributionAndIncentivized() public {
        // GIVEN alice allocates 1 ether and bob 5 ether to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN there is a distribution of 100 reward token with 50% reward percentage
        _distribute(100 ether, 0 ether);

        // AND gauge is incentivized
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(50 ether);

        // THEN alice estimated rewards left to earn is
        // 16.666666666666666666 = allocation * rewardPerToken = 1 * 16.666666666666666666
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 16_666_666_666_666_666_666);
        // AND alice earned rewards is 0
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // THEN bob estimated rewards left to earn is
        //  83.333333333333333332 = allocation * rewardPerToken = 5 * 16.666666666666666666
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 83_333_333_333_333_333_332);
        // AND bob earned rewards is 0
        assertEq(gauge.earned(address(rewardToken), bob), 0);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN alice estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        // AND alice earned rewards is
        // 16.666666666666666666 = allocation * rewardPerToken = 1 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), alice), 16_666_666_666_666_666_666);

        // THEN bob estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 0);
        // THEN bob earned rewards is
        // 83.333333333333333330 = allocation * rewardPerToken = 5 * 16.666666666666666666
        assertEq(gauge.earned(address(rewardToken), bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: estimated backer rewards with an incentivized gauge and change in allocations in the middle of the
     * cycle
     */
    function test_EstimatedBackerRewardsAllocationsChange() public {
        // GIVEN alice allocates 1 ether and bob 5 ether to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);
        vm.prank(bob);
        backersManager.allocate(gauge, 5 ether);

        // WHEN gauge is incentivized
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND half an epoch passes
        _skipRemainingCycleFraction(2);

        // AND alice removes all her votes
        vm.prank(alice);
        backersManager.allocate(gauge, 0 ether);

        // THEN alice estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        // AND alice earned rewards is
        // 8.333333333333333333 = allocation * old rewardPerToken * 1 / 2 = 1 * 16.666666666666666666 * 1 / 2
        assertEq(gauge.earned(address(rewardToken), alice), 8_333_333_333_333_333_333);

        // THEN bob estimated rewards left to earn is
        //  50 ether = allocation * new rewardPerToken * 1 / 2 = 5 * 20 ether * 1 / 2
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 49_999_999_999_999_999_999);
        // AND bob earned rewards is
        // 41.666666666666666665 = allocation * old rewardPerToken * 1 / 2  = 5 * 16.666666666666666666 * 1 / 2
        assertEq(gauge.earned(address(rewardToken), bob), 41_666_666_666_666_666_665);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN alice estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), alice), 0);
        // AND alice earned rewards did not change
        assertEq(gauge.earned(address(rewardToken), alice), 8_333_333_333_333_333_333);

        // THEN bob estimated rewards left to earn is 0
        assertEq(gauge.estimatedBackerRewards(address(rewardToken), bob), 0);
        // THEN bob earned rewards is
        // 91.666666666666666660 = (allocation * old rewardPerToken * 1 / 2) + (allocation * new rewardPerToken * 1 / 2)
        // 91.666666666666666660 = (5 * 16.666666666666666666  * 1 / 2) + (5 * 20 * 1 / 2)
        assertEq(gauge.earned(address(rewardToken), bob), 91_666_666_666_666_666_660);
    }

    /**
     * @notice sets periodFinish on BackersManagerRootstockCollective
     *  Since we are impersonating BackersManagerRootstockCollective instead of allocating and distributing from real
     * use cases,
     *  we need to update the periodFinish var every time gauge.notifyRewardAmountAndUpdateShares is called
     *  at the beginning of an cycle to simulate a distribution
     */
    function _setPeriodFinish() internal {
        stdstore.target(address(backersManager)).sig("periodFinish()").checked_write(
            backersManager.cycleNext(block.timestamp)
        );
    }
}
