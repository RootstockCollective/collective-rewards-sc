// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdStorage, StdStorage } from "forge-std/src/Test.sol";
import { BaseTest, Gauge } from "./BaseTest.sol";
import { EpochLib } from "../src/libraries/EpochLib.sol";
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
        // mint some rewardTokens to sponsorsManager simulating a distribution
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
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.allocate(alice, 1 ether);
        // WHEN alice calls notifyRewardAmountAndUpdateShares
        //  THEN tx reverts because caller is not the SponsorsManager contract
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.notifyRewardAmountAndUpdateShares(1 ether, 1 ether, block.timestamp);
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
     * SCENARIO: notifyRewardAmount reverts if msg.value is wrong
     */
    function test_RevertInvalidRewardAmount() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // WHEN trying to distribute coinbase sending invalid value
        //  THEN tx reverts because value sent is wrong
        vm.expectRevert(Gauge.InvalidRewardAmount.selector);
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 1 ether, 100 ether);
        vm.expectRevert(Gauge.InvalidRewardAmount.selector);
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 1 ether, 98 ether);
    }

    /**
     * SCENARIO: SponsorsManager allocates to alice with no rewards distributed
     */
    function test_Allocate() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND a new epoch
        _skipAndStartNewEpoch();
        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // WHEN 1 ether is allocated to alice
        //  THEN Allocated event is emitted
        vm.expectEmit();
        emit NewAllocation(alice, 1 ether);
        gauge.allocate(alice, 1 ether);

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
        assertEq(gauge.lastUpdateTime(address(rewardToken)), EpochLib._epochStart(block.timestamp));
    }

    /**
     * SCENARIO: SponsorsManager deallocates to alice with no rewards distributed
     */
    function test_Deallocate() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND a new epoch
        _skipAndStartNewEpoch();
        // AND 1 ether is allocated to alice
        gauge.allocate(alice, 1 ether);

        // WHEN half epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice gets everything deallocated
        //  THEN Allocated event is emitted
        vm.expectEmit();
        emit NewAllocation(alice, 0 ether);
        gauge.allocate(alice, 0 ether);

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
        assertEq(gauge.lastUpdateTime(address(rewardToken)), EpochLib._epochStart(block.timestamp));
    }

    /**
     * SCENARIO: SponsorsManager makes a partial deallocation to alice with no rewards distributed
     */
    function test_DeallocatePartial() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND a new epoch
        _skipAndStartNewEpoch();
        // AND 1 ether is allocated to alice
        gauge.allocate(alice, 1 ether);

        // WHEN half epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice gets 0.25 ether deallocated
        gauge.allocate(alice, 0.75 ether);

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
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // WHEN 100 ether are distributed
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 30 ether, 70 ether);
        gauge.notifyRewardAmount(address(rewardToken), 30 ether, 70 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN time until next epoch is 518400
        assertEq(sponsorsManager.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000135030864197530 = 70 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 135_030_864_197_530);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 5.833333333333333333 = 518400 / 2 * 0.000135030864197530 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 5_833_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 11.666666666666666666 = 518400 * 0.000135030864197530 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 11_666_666_666_666_666_666);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);
    }

    /**
     * SCENARIO: rewards variables are updated in the middle and at the end of the epoch
     */
    function test_NotifyRewardAmount() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // WHEN 100 ether are distributed
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0 ether, 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
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
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager
     */
    function test_NotifyRewardAmountNotFromSponsorsManager() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether);
        rewardToken.approve(address(gauge), 100 ether);

        // WHEN 100 ether are distributed by Incentivizer
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0 ether, 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one for rewardToken
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN lastUpdateTime is the current one for coinbase
        assertEq(gauge.lastUpdateTime(UtilsLib._COINBASE_ADDRESS), block.timestamp);
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
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager using coinbase
     */
    function test_NotifyRewardAmountWithCoinbaseNotFromSponsorsManager() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND an Incentivizer has coinbase
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);

        // WHEN 100 ether are distributed by Incentivizer
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(UtilsLib._COINBASE_ADDRESS, 0 ether, 100 ether);
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 0, 100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN lastUpdateTime is the current one for coinbase
        assertEq(gauge.lastUpdateTime(UtilsLib._COINBASE_ADDRESS), block.timestamp);
        // THEN lastUpdateTime is the current one for rewardToken
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN time until next epoch is 518400
        assertEq(sponsorsManager.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 192_901_234_567_901);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);
        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS), 0);
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: there are no initial allocations, incentivizer updates rewards variables and allocations
     * happen after in same first epoch
     */
    function test_NotifyRewardAmountBeforeAllocation() public {
        // GIVEN an Incentivizer with rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether);
        rewardToken.approve(address(gauge), 100 ether);

        // WHEN 100 ether are distributed by Incentivizer
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0 ether, 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // AND 1 ether is allocated to alice and 5 ether to bob
        vm.startPrank(address(sponsorsManager));
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 49999999999999999999 = 518400 / 2 *  0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 49_999_999_999_999_999_999);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(sponsorsManager.periodFinish(), EpochLib._epochNext(block.timestamp));
        // THEN time until next epoch is 259_200 = 518400 / 2
        assertEq(sponsorsManager.periodFinish() - block.timestamp, 259_200);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // THEN rewardMissing is 49999999999999999999 = 518400 / 2 *  0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 49_999_999_999_999_999_999);

        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 0);
        // THEN alice has 1 * rewardPerToken to claim: 8.333333333333333333 = 1 * 8.333333333333333333
        assertEq(gauge.earned(address(rewardToken), alice), 8_333_333_333_333_333_333);
        // THEN bob has 5 * rewardPerToken to claim: 41.666666666666666665 = 5 * 8.333333333333333333
        assertEq(gauge.earned(address(rewardToken), bob), 41_666_666_666_666_666_665);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager when there
     * are no initial allocations in previous epoch, allocations happen in following epoch
     */
    function test_NotifyRewardAmountNoAllocationsInPreviousEpoch() public {
        // GIVEN no allocations to gauge
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 200 ether);
        rewardToken.approve(address(gauge), 200 ether);

        // WHEN 100 ether are distributed by Incentivizer
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0 ether, 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN time until next epoch is 518400
        assertEq(sponsorsManager.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN rewardMissing is 0 - there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);

        // AND 1 ether is allocated to alice and 5 ether to bob by sponsorsManager
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is 8.333333333333333333 = 604800 / 2 * 0.000165343915343915 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 1 * rewardPerToken
        assertEq(rewardToken.balanceOf(alice), 8_333_333_333_333_333_333);
        // THEN alice has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 5 * rewardPerToken
        assertEq(rewardToken.balanceOf(bob), 41_666_666_666_666_666_665);
        // THEN bob has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), bob), 0);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager when there
     * are no initial allocations in first epoch, allocations happen in third epoch, rewards are not locked
     */
    function test_NotifyRewardAmountNoAllocationsInTwoEpochs() public {
        // GIVEN no allocations to gauge
        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 200 ether);
        rewardToken.approve(address(gauge), 200 ether);

        // WHEN 100 ether distributed by Incentivizer
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0 ether, 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(address(rewardToken)), block.timestamp);
        // THEN time until next epoch is 518400
        assertEq(sponsorsManager.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);

        // AND epoch finishes with no allocations
        _skipAndStartNewEpoch();

        // THEN rewardMissing is 0 - there were no allocations
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);

        // AND 0 ether are distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(address(rewardToken)), 0);
        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 0);

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
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND 1 ether is allocated to alice and 5 ether to bob by sponsorsManager
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN rewardRate is 0.000165343915343915 = 100 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 165_343_915_343_915);
        // THEN rewardPerToken is 8.333333333333333333 = 604800 / 2 * 0.000165343915343915 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 1 * rewardPerToken
        assertEq(rewardToken.balanceOf(alice), 8_333_333_333_333_333_333);
        // THEN alice has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), alice), 0);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 5 * rewardPerToken
        assertEq(rewardToken.balanceOf(bob), 41_666_666_666_666_666_665);
        // THEN bob has 0 rewards to claim
        assertEq(gauge.earned(address(rewardToken), bob), 0);
    }

    /**
     * SCENARIO: rewards variables are updated by incentivizer that is not the SponsorsManager and
     * during distribution
     */
    function test_NotifyRewardAmountIncentivizerAndSponsorsManager() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // WHEN an Incentivizer has rewardToken
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether);
        rewardToken.approve(address(gauge), 100 ether);

        // WHEN 100 ether distributed by Incentivizer
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0 ether, 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

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

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 100 ether are distributed for sponsors
        vm.startPrank(address(sponsorsManager));
        gauge.notifyRewardAmountAndUpdateShares(100 ether, 1 ether, sponsorsManager.periodFinish());
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
     * SCENARIO: builder claim his rewards in another gauge
     */
    function test_ClaimBuilderWrongGauge() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN 70 ether are sent for builder and 30 ether for sponsors on gauge
        gauge.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);
        // AND 170 ether are sent for builder and 30 ether for sponsors on gauge2
        gauge2.notifyRewardAmount(address(rewardToken), 170 ether, 30 ether);

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
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN 70 ether are sent for builder and 30 ether for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 70 ether, 30 ether);

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
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN 70 ether are sent for builder and 30 ether for sponsors
        gauge2.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);
        gauge2.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 70 ether, 30 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // THEN builderRewards is 70 ether
        assertEq(gauge2.builderRewards(address(rewardToken)), 70 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors and builders
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // WHEN builder2Receiver claims rewards
        vm.startPrank(builder2Receiver);
        gauge2.claimBuilderReward();
        // THEN builder2Receiver rewardToken balance is 70 ether
        assertEq(rewardToken.balanceOf(builder2Receiver), 70 ether);
        // THEN builder2Receiver coinbase balance is 70 ether
        assertEq(builder2Receiver.balance, 70 ether);

        // AND 70 ether are set for builder and 30 ether for sponsors
        vm.startPrank(address(sponsorsManager));
        gauge2.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);
        gauge2.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 70 ether, 30 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // WHEN builder2 claims rewards
        vm.startPrank(builder2);
        gauge2.claimBuilderReward();
        // THEN builder2Receiver rewardToken balance is 140 ether
        assertEq(rewardToken.balanceOf(builder2Receiver), 140 ether);
        // THEN builder2Receiver coinbase balance is 140 ether
        assertEq(builder2Receiver.balance, 140 ether);
    }

    /**
     * SCENARIO: there are 2 distributions on the same epoch, builder claims the rewards
     */
    function test_ClaimBuilderRewards2Distributions() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN 70 ether are sent for builder and 30 ether for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // AND 70 ether are sent for builder and 30 ether for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);

        // THEN builderRewards is 140 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 140 ether
        assertEq(rewardToken.balanceOf(builder), 140 ether);
    }

    /**
     * SCENARIO: there are 2 epochs, builder claims the rewards
     */
    function test_ClaimBuilderRewards2Epochs() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // AND 70 ether are sent for builder and 30 ether for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // AND another epoch finishes without a new distribution
        _skipAndStartNewEpoch();

        // AND 70 ether are sent for builder and 30 ether for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 70 ether, 30 ether);

        // THEN builderRewards is 140 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 140 ether
        assertEq(rewardToken.balanceOf(builder), 140 ether);
    }

    /**
     * SCENARIO: alice and bob claim their rewards at the end of the epoch receiving the total amount of rewards.
     */
    function test_ClaimSponsorRewards() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

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
    }

    /**
     * SCENARIO: alice claims sponsors rewards on a wrong gauge
     */
    function test_ClaimSponsorRewardsWrongGauge() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice on gauge
        gauge.allocate(alice, 1 ether);
        // AND 5 ether to bob on gauge2
        gauge2.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors on both gauges
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);
        gauge2.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // WHEN alice claims rewards on gauge2
        vm.startPrank(alice);
        gauge2.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 0
        assertEq(rewardToken.balanceOf(alice), 0);

        // WHEN alice claims rewards on gauge
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 100
        assertApproxEqAbs(rewardToken.balanceOf(alice), 100 ether, 10);

        // WHEN bob claims rewards on gauge
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 0
        assertEq(rewardToken.balanceOf(bob), 0);

        // WHEN bob claims rewards on gauge2
        vm.startPrank(bob);
        gauge2.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 100
        assertApproxEqAbs(rewardToken.balanceOf(bob), 100 ether, 10);
    }

    /**
     * SCENARIO: alice and bob claim their rewards in the middle of the epoch receiving partial rewards.
     */
    function test_ClaimSponsorRewardsPartial() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether are distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // AND 1/3 epoch passes
        _skipRemainingEpochFraction(3);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 5.555555555555555555 = 518400 / 3 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 5_555_555_555_555_555_555);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 5.555555555555555555 = 1 * 5.555555555555555555
        assertEq(rewardToken.balanceOf(alice), 5_555_555_555_555_555_555);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 27.777777777777777775 = 5 * 5.555555555555555555
        assertEq(rewardToken.balanceOf(bob), 27_777_777_777_777_777_775);
    }

    /**
     * SCENARIO: alice and bob don't claim on epoch 1 but claim on epoch 2
     *  receiving the 2 reward distributions accumulated
     */
    function test_ClaimSponsorRewardsAccumulative() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 200 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(200 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerTokenStored is 16.666666666666666666 = 100 ether / 518400 sec from epoch 1
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 16_666_666_666_666_666_666);
        // time until next epoch is 604800
        // THEN rewardRate is 0.000330687830687830 = 200 ether / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 330_687_830_687_830);
        // THEN rewardPerToken is 16.666666666666666666 = 100 ether / 518400 sec from epoch 1
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN rewardPerToken is
        //  49.999999999999999999 = 16.666666666666666666 + 604800 * 0.000330687830687830 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_999);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: there are 2 distributions on the same epoch, alice and bob claim them
     */
    function test_ClaimSponsorRewards2DistributionOnSameEpoch() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether are distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);
        // AND half epoch passes
        _skipRemainingEpochFraction(2);
        // AND 200 ether more are distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 200 ether);

        // time until next epoch is 259200
        // rewardRate = 0.000192901234567901
        // leftover = 259200 * 0.000192901234567901 = 49.9999999999999392
        // THEN rewardRate is 0.000964506172839506 = (200 + 49.9999999999999392) / 259200 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 964_506_172_839_506);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerToken is
        // rewardPerTokenStored = 8.333333333333333333
        //  49.999999999999999999 = 8.333333333333333333 + 259200 * 0.000964506172839506 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_999);
        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: alice quits before the epoch finishes, so she receives less rewards and bob more
     */
    function test_ClaimSponsorRewardsAliceQuit() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether are distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // WHEN alice deallocates all
        vm.startPrank(address(sponsorsManager));
        gauge.allocate(alice, 0 ether);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerToken is
        //  18.333333333333333332 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 5 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 18_333_333_333_333_333_332);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is 8.333333333333333333 = 1 * 8.333333333333333333
        assertEq(rewardToken.balanceOf(alice), 8_333_333_333_333_333_333);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 91.666666666666666660 = 5 * 18.333333333333333332
        assertEq(rewardToken.balanceOf(bob), 91_666_666_666_666_666_660);
    }

    /**
     * SCENARIO: alice allocates more before the epoch finishes, so she receives more rewards and bob less
     */
    function test_ClaimSponsorRewardsAliceAllocatesAgain() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether are distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // WHEN alice allocates 1 ether more
        vm.startPrank(address(sponsorsManager));
        gauge.allocate(alice, 2 ether);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 8_333_333_333_333_333_333);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardPerToken is
        //  15.476190476190476190 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 7 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 15_476_190_476_190_476_190);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is
        //  22.619047619047619047 = 1 * 8.333333333333333333 + 2 * (15.476190476190476190 - 8.333333333333333333)
        assertEq(rewardToken.balanceOf(alice), 22_619_047_619_047_619_047);

        // WHEN bob claims rewards
        vm.startPrank(bob);
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
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // AND 2 ether allocated to alice
        gauge.allocate(alice, 2 ether);
        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // AND half epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice deallocates all
        gauge.allocate(alice, 0 ether);
        // time until next epoch is 518400
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 192_901_234_567_901);
        // THEN rewardPerTokenStored is 24.999999999999999999 = 518400 / 2 * 0.000192901234567901 / 2 ether
        assertEq(gauge.rewardPerTokenStored(address(rewardToken)), 24_999_999_999_999_999_999);
        // THEN rewardPerToken is 24.999999999999999999 = 24999999999999999999 + 0
        assertEq(gauge.rewardPerToken(address(rewardToken)), 24_999_999_999_999_999_999);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // WHEN 2 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // THEN lastUpdateTime is epoch start
        assertEq(gauge.lastUpdateTime(address(rewardToken)), EpochLib._epochStart(block.timestamp));
        // THEN rewardRate is 0.000082671957671957 = (100 ether / 2) / 604800 sec
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 82_671_957_671_957);
        // THEN rewardMissing is 49.999999999999999999 = 518400 / 2 * 0.000192901234567901
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 0);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);
        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

        // THEN rewardRate is 0
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 0);
        // THEN rewardPerToken is
        //  49.999999999999999999 = 24.999999999999999999 + 604800 * 0.000248015873015873 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 49_999_999_999_999_999_998);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice rewardToken balance is
        //  74.999999999999999997 = 2 * 24.999999999999999999 + 1 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(alice), 74_999_999_999_999_999_997);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(bob);
        // THEN bob rewardToken balance is 124.999999999999999995 = 5 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(bob), 124_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: alice and bob receive rewards on ERC20
     */
    function test_ClaimERC20Rewards() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND alice allocates 1 ether
        gauge.allocate(alice, 1 ether);
        // AND bob allocates 1 ether
        gauge.allocate(bob, 5 ether);

        // AND 100 ether are distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);
        // AND epoch finishes
        _skipAndStartNewEpoch();

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(address(rewardToken)), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(address(rewardToken), alice);
        // THEN alice coinbase balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorReward(address(rewardToken), bob);
        // THEN bob coinbase balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);
    }

    /**
     * SCENARIO: alice and bob receive rewards on Coinbase
     */
    function test_ClaimCoinbaseRewards() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND alice allocates 1 ether
        gauge.allocate(alice, 1 ether);
        // AND bob allocates 1 ether
        gauge.allocate(bob, 5 ether);

        // AND 100 ether are distributed for sponsors
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 0, 100 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorReward(UtilsLib._COINBASE_ADDRESS, alice);
        // THEN alice coinbase balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(alice.balance, 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.startPrank(bob);
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
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether is allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether are distributed for sponsors
        gauge.notifyRewardAmount(address(rewardToken), 0, 100 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();

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

        // AND alice and bob deallocates all
        vm.startPrank(address(sponsorsManager));
        gauge.allocate(alice, 0 ether);
        gauge.allocate(bob, 0 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // AND 0 ether are distributed for sponsors
        gauge.notifyRewardAmountAndUpdateShares(0 ether, 1 ether, sponsorsManager.periodFinish());
        // simulates a distribution setting the periodFinish
        _setPeriodFinish();
        // AND half epoch passes
        _skipRemainingEpochFraction(2);

        // AND 1 ether is allocated to alice
        vm.startPrank(address(sponsorsManager));
        gauge.allocate(alice, 1 ether);

        // AND epoch finishes
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
            EpochLib._epochNext(block.timestamp)
        );
    }
}
