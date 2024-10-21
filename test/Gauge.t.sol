// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { stdStorage, StdStorage } from "forge-std/src/Test.sol";
import { BaseTest, Gauge } from "./BaseTest.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract GaugeTest is BaseTest {
    using stdStorage for StdStorage;
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event SponsorRewardsClaimed(address indexed sponsor_, uint256 amount_);
    event NewAllocation(address indexed sponsor_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, uint256 builderAmount_, uint256 sponsorsAmount_);

    function _setUp() internal override {
        // mint some rewardTokens and deal to incentivizer
        rewardToken.mint(address(incentivizer), 100_000 ether);
        vm.deal(address(incentivizer), 100_000 ether);
        vm.prank(address(incentivizer));
        rewardToken.approve(address(gauge), 100_000 ether);
        vm.prank(address(incentivizer));
        rewardToken.approve(address(gauge2), 100_000 ether);

        // mint some rewardTokens and deal to sponsorsManager
        rewardToken.mint(address(sponsorsManager), 100_000 ether);
        vm.deal(address(sponsorsManager), 100_000 ether);
        vm.prank(address(sponsorsManager));
        rewardToken.approve(address(gauge), 100_000 ether);
        vm.prank(address(sponsorsManager));
        rewardToken.approve(address(gauge2), 100_000 ether);
    }

    /**
     * SCENARIO: functions protected by OnlySponsorsManager should revert when are not
     *  called by SponsorsManager contract
     */
    function test_OnlySponsorsManager() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);
        // WHEN alice calls allocate
        //  THEN tx reverts because caller is not the SponsorsManager contract
        uint256 _timeUntilNextEpoch = sponsorsManager.timeUntilNextEpoch(block.timestamp);
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.allocate(alice, 1 ether, _timeUntilNextEpoch);
        // WHEN alice calls notifyRewardAmountAndUpdateShares
        //  THEN tx reverts because caller is not the SponsorsManager contract
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.notifyRewardAmountAndUpdateShares(1 ether, 1 ether, block.timestamp, _epochStart, _epochDuration);
        // WHEN alice calls moveBuilderUnclaimedRewards
        //  THEN tx reverts because caller is not the SponsorsManager contract
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.moveBuilderUnclaimedRewards(alice);
    }

    /**
     * SCENARIO: functions should revert by NotAuthorized error when are not called by
     *  SponsorsManager or the actor involved
     */
    function test_NotAuthorized() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);
        // WHEN alice calls claimSponsorReward using bob address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
        gauge.claimSponsorReward(address(rewardToken), bob);

        // WHEN alice calls claimSponsorReward using bob address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
        gauge.claimSponsorReward(bob);

        // WHEN alice calls claimBuilderReward using builder address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
        gauge.claimBuilderReward(address(rewardToken));

        // WHEN alice calls claimBuilderReward using builder address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
        gauge.claimBuilderReward();
    }

    /**
     * SCENARIO: SponsorsManager allocates to alice with no rewards distributed
     */
    function test_Allocate() public {
        // GIVEN a new epoch
        _skipAndStartNewEpoch();
        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // WHEN alice allocates 1 ether
        //  THEN Allocated event is emitted
        vm.startPrank(alice);
        vm.expectEmit();
        emit NewAllocation(alice, 1 ether);
        sponsorsManager.allocate(gauge, 1 ether);

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
        // THEN alice sponsorRewardPerTokenPaid is 0 because there are no rewards distributed
        assertEq(gauge.sponsorRewardPerTokenPaid(address(rewardToken), alice), 0);
        // THEN lastUpdateTime is epoch start since there are no rewards distributed
        assertEq(gauge.lastUpdateTime(address(rewardToken)), sponsorsManager.epochStart(block.timestamp));
    }

    /**
     * SCENARIO: SponsorsManager deallocates to alice with no rewards distributed
     */
    function test_Deallocate() public {
        // GIVEN a new epoch
        _skipAndStartNewEpoch();
        // AND alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // WHEN half epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice deallocates all
        //  THEN Allocated event is emitted
        vm.expectEmit();
        emit NewAllocation(alice, 0 ether);
        sponsorsManager.allocate(gauge, 0 ether);

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
        // THEN alice sponsorRewardPerTokenPaid is 0 because there are no rewards distributed
        assertEq(gauge.sponsorRewardPerTokenPaid(address(rewardToken), alice), 0);
        // THEN lastUpdateTime is epoch start since there are no rewards distributed
        assertEq(gauge.lastUpdateTime(address(rewardToken)), sponsorsManager.epochStart(block.timestamp));
    }

    /**
     * SCENARIO: SponsorsManager makes a partial deallocation to alice with no rewards distributed
     */
    function test_DeallocatePartial() public {
        // GIVEN a new epoch
        _skipAndStartNewEpoch();
        // AND alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // WHEN half epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice deallocates 0.25 ether
        sponsorsManager.allocate(gauge, 0.75 ether);

        // THEN alice allocation is 0.75 ether
        assertEq(gauge.allocationOf(alice), 0.75 ether);
        // THEN totalAllocation is 0.75 ether
        assertEq(gauge.totalAllocation(), 0.75 ether);
        // THEN rewardShares is 529200 ether = 1 * 1/2 WEEK + 0.75 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 529_200 ether);
    }

    /**
     * SCENARIO: notifyRewardAmount with rewards split percentage different than 0
     * rewards variables are updated in the middle and at the end of the epoch
     */
    function test_NotifyRewardAmountWithStrategy() public {
        // GIVEN a builder with 70% of kickback
        vm.startPrank(builder);
        sponsorsManager.setBuilderKickback(0.7 ether);
        skip(kickbackCooldown);

        // AND 6 ether are allocated to alice
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 6 ether);

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
        // THEN periodFinish is updated with the timestamp when the epoch finish
        assertEq(sponsorsManager.periodFinish(), sponsorsManager.epochNext(block.timestamp));
        // THEN time until next epoch is 1 week
        assertEq(sponsorsManager.periodFinish() - block.timestamp, 1 weeks);
        // THEN rewardRate is 0.000115740740740740 = 70 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 115_740_740_740_740);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 5.833333333333333333 = 604800 / 2 * 0.000115740740740740 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 5_833_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 11.666666666666666666 = 604800 * 0.000115740740740740 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 11_666_666_666_666_666_666);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);
    }

    /**
     * SCENARIO: rewards variables for rewardToken are updated in the middle and at the end of the epoch
     */
    function test_IncentivizeWithRewardToken() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

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
        // THEN periodFinish is updated with the timestamp when the epoch finish
        assertEq(sponsorsManager.periodFinish(), sponsorsManager.epochNext(block.timestamp));
        // THEN time until next epoch is 518400
        assertEq(sponsorsManager.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: rewards variables for rewardToken are updated by incentivizer that is not the SponsorsManager
     */
    function test_IncentivizeWithRewardTokenNotFromSponsorsManager() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

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

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: incentivizer tries to send 0 amount
     */
    function test_IncentivizeWithZeroAmount() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // WHEN 0 ether are distributed by Incentivizer in rewardToken
        vm.startPrank(incentivizer);
        gauge.incentivizeWithRewardToken(0 ether);

        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);

        // WHEN 0 ether are distributed by Incentivizer
        vm.startPrank(incentivizer);
        gauge.incentivizeWithCoinbase{ value: 0 ether }();

        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0);
    }

    /**
     * SCENARIO: incentivizer does not have enough balance
     */
    function test_incentivizeWithNotEnoughBalance() public {
        // GIVEN an incentivizer with limited balance
        address _incentivizer2 = makeAddr("incentivizer2");
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(_incentivizer2);
        rewardToken.mint(address(_incentivizer2), 50 ether);
        rewardToken.approve(address(gauge), 50 ether);

        // WHEN 100 ether are distributed by Incentivizer in rewardToken
        //  THEN tx reverts because of insufficient allowance
        vm.expectRevert();
        gauge.incentivizeWithRewardToken(100 ether);

        // WHEN 100 ether are distributed by Incentivizer
        //  THEN tx reverts because of insufficient balance
        vm.expectRevert();
        gauge.incentivizeWithCoinbase{ value: 100 ether }();
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer twice in same epoch
     */
    function test_IncentivizeTwiceInSameEpoch() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

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

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // WHEN 100 ether are distributed again by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000578703703703703 = 100 ether / 518400 sec + 100 / (518400 sec/2)
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 578_703_703_703_703);

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager using coinbase
     */
    function test_IncentivizeWithCoinbaseNotFromSponsorsManager() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

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

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: there are no initial allocations, incentivizer updates rewards variables and allocations
     * happen after in same first epoch
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

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // AND alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // THEN rewardMissing is 49999999999999999999 = 518400 / 2 *  0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 49_999_999_999_999_999_999);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND epoch finishes
        _skipAndStartNewEpoch();

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

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager when there
     * are no initial allocations in previous epoch, allocations happen in following epoch and all
     * rewards are distributed and claimed by sponsors with no rewards lost
     */
    function test_IncentivizeWithNoAllocationsInPreviousEpoch() public {
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

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN rewardMissing is 0 since there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // rewardMissing are updated with all the existing rewards (since there were no allocations), included in the
        // rewardRate for new epoch and set back to 0 in this method
        gauge.notifyRewardAmountAndUpdateShares(
            0 ether, 1 ether, sponsorsManager.periodFinish(), _epochStart, _epochDuration
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
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 1 * rewardPerToken
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);
        // THEN alice has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 5 * rewardPerToken
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
        // THEN bob has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), bob), 0);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager when there
     * are no initial allocations in first epoch, allocations happen in third epoch, rewards are not locked
     */
    function test_IncentivizeWithNoAllocationsInTwoEpochs() public {
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

        // AND epoch finishes with no allocations
        _skipAndStartNewEpoch();

        // THEN rewardMissing is 0 - there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            0 ether, 1 ether, sponsorsManager.periodFinish(), _epochStart, _epochDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);

        // AND epoch finishes again with no allocations
        _skipAndStartNewEpoch();
        // THEN rewardMissing is 0 - there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            0 ether, 1 ether, sponsorsManager.periodFinish(), _epochStart, _epochDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND half epoch passes
        _skipAndStartNewEpoch();

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is 16.666666666666666666 = 604800 * 0.000165343915343915 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 1 * rewardPerToken
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);
        // THEN alice has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 5 * rewardPerToken
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
        // THEN bob has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), bob), 0);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager and
     * during distribution
     */
    function test_IncentivizeWithIncentivizerAndSponsorsManager() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 1 day passes
        skip(1 days);

        // WHEN 100 ether are distributed by Incentivizer
        vm.prank(incentivizer);
        gauge.incentivizeWithRewardToken(100 ether);

        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 100 ether are distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            100 ether, 1 ether, sponsorsManager.periodFinish(), _epochStart, _epochDuration
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

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
     * SCENARIO: trying to incentivize on epoch before distribution finishes should fail
     */
    function test_NotifyRewardAmountIncentivizeInDistributionWindow() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // WHEN an Incentivizer has rewardToken and coinbase
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);
        rewardToken.mint(address(incentivizer), 200 ether);
        rewardToken.approve(address(gauge), 200 ether);

        // WHEN 100 ether are distributed by Incentivizer
        gauge.incentivizeWithRewardToken(100 ether);

        // AND epoch finishes
        _skipToStartDistributionWindow();

        // WHEN there is an attempt to distribute 100 ether in rewardToken by Incentivizer
        //  THEN it reverts since distribution has not finished yet
        vm.expectRevert(Gauge.BeforeDistribution.selector);
        gauge.incentivizeWithRewardToken(100 ether);

        // WHEN there is an attempt to distribute 100 ether in coinbase by Incentivizer
        //  THEN it reverts since distribution has not finished yet
        vm.expectRevert(Gauge.BeforeDistribution.selector);
        gauge.incentivizeWithCoinbase{ value: 100 ether }();

        // AND distribution finishes with 100 ether being distributed
        vm.startPrank(address(sponsorsManager));
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(
            100 ether, 1 ether, sponsorsManager.periodFinish(), _epochStart, _epochDuration
        );
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
        // GIVEN a builder with 30% of kickback
        vm.startPrank(builder);
        sponsorsManager.setBuilderKickback(0.3 ether);
        // GIVEN a builder2 with 15% of kickback
        vm.startPrank(builder2);
        sponsorsManager.setBuilderKickback(0.15 ether);
        skip(kickbackCooldown);
        // AND alice allocates to gauge and gauge2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 4 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 300 rewardToken are distributed
        _distribute(300 ether, 0 ether);

        // WHEN builder claims rewards on gauge
        vm.startPrank(builder);
        gauge.claimBuilderReward();
        // THEN builder rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder), 70 ether);
        // WHEN builder claims rewards on gauge2
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
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
     * SCENARIO: builder claims his rewards at any time during the epoch receiving the total amount of rewards.
     */
    function test_ClaimBuilderRewardsBuilder() public {
        // GIVEN a builder with 30% of kickback
        vm.startPrank(builder);
        sponsorsManager.setBuilderKickback(0.3 ether);
        skip(kickbackCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN builderRewards is 70 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 70 ether);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();
        // THEN builder rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder), 70 ether);
        // THEN builder coinbase balance is 70 ether
        assertEq(builder.balance, 70 ether);
    }

    /**
     * SCENARIO: reward receiver claims his rewards at any time during the epoch receiving the total amount of rewards.
     */
    function test_ClaimBuilderRewardsRewardReceiver() public {
        // GIVEN a builder2 with 30% of kickback
        vm.startPrank(builder2);
        sponsorsManager.setBuilderKickback(0.3 ether);
        skip(kickbackCooldown);
        // AND alice allocates to gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge2, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN builderRewards is 70 ether
        assertEq(gauge2.builderRewards(address(rewardToken)), 70 ether);

        // AND another epoch finishes without a new distribution
        _skipAndStartNewEpoch();

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
     * SCENARIO: there are 2 distributions in the same distribution window, builder claimS the rewards
     */
    function test_ClaimBuilderRewards2Distributions() public {
        // GIVEN a builder with 30% of kickback
        vm.startPrank(builder);
        sponsorsManager.setBuilderKickback(0.3 ether);
        skip(kickbackCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND 100 rewardToken and 100 coinbase are distributed in the same distribution window
        vm.warp(sponsorsManager.endDistributionWindow(block.timestamp) - 1);
        rewardToken.mint(address(rewardDistributor), 100 ether);
        vm.deal(address(rewardDistributor), 100 ether);
        vm.startPrank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(100 ether, 100 ether);

        // THEN builderRewards rewardToken is 140 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);
        // THEN builderRewards coinbase is 140 ether
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 140 ether);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

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
     * SCENARIO: there are 2 epochs, builder claims the rewards
     */
    function test_ClaimBuilderRewards2Epochs() public {
        // GIVEN a builder with 30% of kickback
        vm.startPrank(builder);
        sponsorsManager.setBuilderKickback(0.3 ether);
        skip(kickbackCooldown);
        // AND alice allocates to gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // AND 100 rewardToken and 100 coinbase are distributed
        _distribute(100 ether, 100 ether);

        // THEN builderRewards rewardToken is 140 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);
        // THEN builderRewards coinbase is 140 ether
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 140 ether);

        // AND another epoch finishes without a new distribution
        _skipAndStartNewEpoch();

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
     * SCENARIO: alice and bob claim their rewards at the end of the epoch receiving the total amount of rewards.
     */
    function test_ClaimSponsorRewards() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 100 ether distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND there is a distribution
        _distribute(0, 0);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: alice claims sponsors rewards on a wrong gauge
     */
    function test_ClaimSponsorRewardsWrongGauge() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 5 ether);

        // AND 100 ether distributed for sponsors on both gauges
        vm.startPrank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);
        gauge2.incentivizeWithRewardToken(100 ether);
        vm.stopPrank();

        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // WHEN alice claims rewards on gauge2
        vm.prank(alice);
        gauge2.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 0
        assertEq(rewardToken.balanceOf(alice), 0);

        // WHEN alice claims rewards on gauge
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 100
        assertApproxEqAbs(rewardToken.balanceOf(alice), 100 ether, 10);

        // WHEN bob claims rewards on gauge
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 0
        assertEq(rewardToken.balanceOf(bob), 0);

        // WHEN bob claims rewards on gauge2
        vm.prank(bob);
        gauge2.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 100
        assertApproxEqAbs(rewardToken.balanceOf(bob), 100 ether, 10);
    }

    /**
     * SCENARIO: alice and bob claim their rewards in the middle of the epoch receiving partial rewards.
     */
    function test_ClaimSponsorRewardsPartial() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND 1/3 epoch passes
        _skipRemainingEpochFraction(3);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 5.555555555555555555 = 518400 / 3 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 5_555_555_555_555_555_555);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 5.555555555555555555 = 1 * 5.555555555555555555
        assertEq(rewardToken.balanceOf(alice), 5_555_555_555_555_555_555);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 27.777777777777777775 = 5 * 5.555555555555555555
        assertEq(rewardToken.balanceOf(bob), 27_777_777_777_777_777_775);
    }

    /**
     * SCENARIO: alice and bob don't claim on epoch 1 but claim on epoch 2
     *  receiving the 2 reward distributions accumulated
     */
    function test_ClaimSponsorRewardsAccumulative() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 100 ether distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // AND 0 rewardToken are distributed
        _distribute(0, 0);

        // AND 200 ether more are distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(200 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: there are 2 distributions on the same epoch, alice and bob claim them
     */
    function test_ClaimSponsorRewards2DistributionOnSameEpoch() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 1 days pass
        skip(1 days);

        // AND 100 ether distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND 200 ether more are distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(200 ether);
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();
        // AND epoch finish
        _skipAndStartNewEpoch();

        // time until next epoch is 259200
        // rewardRate = 0.000192901234567901
        // leftover = 259200 * 0.000192901234567901 = 49.9999999999999392
        // THEN rewardRate is 0.000964506172839506 = (200 + 49.9999999999999392) / 259200 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 964_506_172_839_506);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        _distribute(0, 0);

        // THEN rewardPerToken is
        // rewardPerTokenStored = 8.333333333333333333
        //  49.999999999999999999 = 8.333333333333333333 + 259200 * 0.000964506172839506 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_999);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: alice quits before the epoch finishes, so she receives less rewards and bob more
     */
    function test_ClaimSponsorRewardsAliceQuit() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for sponsors
        vm.prank(address(incentivizer));
        // AND 100 ether distributed for sponsors
        gauge.incentivizeWithRewardToken(100 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // WHEN alice deallocates all
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0 ether);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND 0 ether are distributed for sponsors
        _distribute(0, 0);

        // THEN rewardPerToken is
        //  18.333333333333333332 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 5 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 18_333_333_333_333_333_332);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 8.333333333333333333 = 1 * 8.333333333333333333
        assertEq(rewardToken.balanceOf(alice), 8_333_333_333_333_333_333);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 91.666666666666666660 = 5 * 18.333333333333333332
        assertEq(rewardToken.balanceOf(bob), 91_666_666_666_666_666_660);
    }

    /**
     * SCENARIO: alice allocates more before the epoch finishes, so she receives more rewards and bob less
     */
    function test_ClaimSponsorRewardsAliceAllocatesAgain() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for sponsors
        vm.prank(address(incentivizer));
        // AND 100 ether distributed for sponsors
        gauge.incentivizeWithRewardToken(100 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // WHEN alice allocates 1 ether more
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND 0 ether are distributed for sponsors
        _distribute(0, 0);

        // THEN rewardPerToken is
        //  15.476190476190476190 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 7 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 15_476_190_476_190_476_190);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is
        //  22.619047619047619047 = 1 * 8.333333333333333333 + 2 * (15.476190476190476190 - 8.333333333333333333)
        assertEq(rewardToken.balanceOf(alice), 22_619_047_619_047_619_047);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 91.666666666666666660 = 5 * 15.476190476190476190
        assertEq(rewardToken.balanceOf(bob), 77_380_952_380_952_380_950);
    }

    /**
     * SCENARIO: there are remaining rewards after a full deallocation.
     * alice and bob allocate again on the next epoch and receive the missing
     * rewards from the previous one
     */
    function test_ClaimMissingSponsorRewardsOnNextEpoch() public {
        // GIVEN alice allocates 2 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 1 days pass
        skip(1 days);

        // AND 100 ether are distributed for sponsors
        vm.prank(address(incentivizer));
        // AND 100 ether distributed for sponsors
        gauge.incentivizeWithRewardToken(100 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // AND alice deallocates all
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0 ether);

        // time until next epoch is 518400
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);
        // THEN rewardPerTokenStored is 24.999999999999999999 = 518400 / 2 * 0.000192901234567901 / 2 ether
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 24_999_999_999_999_999_999);
        // THEN rewardPerToken is 24.999999999999999999 = 24999999999999999999 + 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 24_999_999_999_999_999_999);

        // AND 0 ether are distributed for sponsors
        _distribute(0, 0);

        // AND alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // THEN lastUpdateTime is epoch start
        assertEq(gauge.lastUpdateTime(address(rewardToken)), sponsorsManager.epochStart(block.timestamp));
        // THEN rewardRate is 0.000082671957671957 = (100 ether / 2) / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 82_671_957_671_957);
        // THEN rewardMissing is 49.999999999999999999 = 518400 / 2 * 0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 0);

        // AND 100 ether are distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND 0 ether are distributed for sponsors
        _distribute(0, 0);

        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);
        // THEN rewardPerToken is
        //  49.999999999999999999 = 24.999999999999999999 + 604800 * 0.000248015873015873 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_998);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is
        //  74.999999999999999997 = 2 * 24.999999999999999999 + 1 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(alice), 74_999_999_999_999_999_997);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 124.999999999999999995 = 5 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(bob), 124_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: alice and bob receive rewards on ERC20
     */
    function test_ClaimERC20Rewards() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithRewardToken(100 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(address(rewardToken), alice);
        // THEN alice rewardToken balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(address(rewardToken), bob);
        // THEN bob rewardToken balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: alice and bob receive rewards on Coinbase
     */
    function test_ClaimCoinbaseRewards() public {
        // GIVEN alice allocates 1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 100 ether are distributed for sponsors
        vm.prank(address(incentivizer));
        gauge.incentivizeWithCoinbase{ value: 100 ether }();

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.prank(alice);
        gauge.claimSponsorReward(UtilsLib._COINBASE_ADDRESS, alice);
        // THEN alice coinbase balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(alice.balance, 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.prank(bob);
        gauge.claimSponsorReward(UtilsLib._COINBASE_ADDRESS, bob);
        // THEN bob coinbase balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(bob.balance, 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: alice and bob claim their rewards at the end of the epoch receiving the total amount of rewards.
     *  alice and bob quit at the end of the epoch, the gauge does not receive any rewards.
     *  alice allocates in the middle of the epoch with no rewards.
     *  If they claim again without a new reward distribution they don't receive rewardTokens again and rewardRate
     *  should be 0.
     */
    function test_ClaimSponsorRewardsAfterNoRewards() public {
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        // AND bob allocates 5 ether
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 5 ether);

        // AND 200 ether with 50% kickback are distributed for sponsors
        _distribute(200 ether, 0);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);

        // AND alice and bob deallocate all
        // GIVEN alice allocates 1 ether
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0 ether);
        vm.startPrank(bob);
        sponsorsManager.allocate(gauge, 0 ether);

        // AND 0 ether distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        gauge.notifyRewardAmountAndUpdateShares(0, 1 ether, sponsorsManager.periodFinish(), _epochStart, _epochDuration);
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();
        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // AND 1 ether allocated to alice
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance did not change
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)), 0);
    }

    /**
     * @notice sets periodFinish on SponsorsManager
     *  Since we are impersonating SponsorsManager instead of allocating and distributing from real use cases,
     *  we need to update the periodFinish var every time gauge.notifyRewardAmountAndUpdateShares is called
     *  at the beginning of an epoch to simulate a distribution
     */
    function _setPeriodFinish() internal {
        stdstore.target(address(sponsorsManager)).sig("periodFinish()").checked_write(
            sponsorsManager.epochNext(block.timestamp)
        );
    }
}
