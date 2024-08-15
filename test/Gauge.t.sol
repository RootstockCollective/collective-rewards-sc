// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "./BaseTest.sol";
import { EpochLib } from "../src/libraries/EpochLib.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract GaugeTest is BaseTest {
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
        // WHEN alice calls notifyRewardAmount
        //  THEN tx reverts because caller is not the SponsorsManager contract
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.notifyRewardAmountERC20(1 ether, 0);
    }

    /**
     * SCENARIO: claimSponsorReward should revert if is not called by the sponsor or the SponsorsManager contract
     */
    function test_NotAuthorized() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);
        // WHEN alice calls claimSponsorReward using bob address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
        gauge.claimSponsorRewardERC20(bob);

        // WHEN alice calls claimBuilderReward using builder address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
        gauge.claimSponsorRewardERC20(builder);
    }

    /**
     * SCENARIO: SponsorsManager allocates to alice without no rewards distributed
     */
    function test_Allocate() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN allocates 1 ether to alice
        //  THEN Allocated event is emitted
        vm.expectEmit();
        emit NewAllocation(alice, 1 ether);
        gauge.allocate(alice, 1 ether);

        // THEN alice allocation is 1 ether
        assertEq(gauge.allocationOf(alice), 1 ether);
        // THEN totalAllocation is 1 ether
        assertEq(gauge.totalAllocation(), 1 ether);
        // THEN rewardPerTokenStored is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenStored(), 0);
        // THEN rewardPerToken is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenERC20(), 0);
        // THEN rewardPerToken is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenCoinbase(), 0);
        // THEN alice reward is 0 because there is not rewards distributed
        assertEq(gauge.rewards(alice), 0);
        // THEN alice sponsorRewardPerTokenPaid is 0 because there is not rewards distributed
        assertEq(gauge.sponsorRewardPerTokenPaid(alice), 0);
        // THEN alice lastUpdateTime is 0 because there is not rewards distributed
        assertEq(gauge.lastUpdateTime(), 0);
    }

    /**
     * SCENARIO: SponsorsManager deallocates to alice without no rewards distributed
     */
    function test_Deallocate() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice
        gauge.allocate(alice, 1 ether);

        // WHEN deallocates all
        //  THEN Allocated event is emitted
        vm.expectEmit();
        emit NewAllocation(alice, 0 ether);
        gauge.allocate(alice, 0 ether);

        // THEN alice allocation is 0
        assertEq(gauge.allocationOf(alice), 0);
        // THEN totalAllocation is 0
        assertEq(gauge.totalAllocation(), 0);
        // THEN rewardPerTokenStored is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenStored(), 0);
        // THEN rewardPerToken is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenERC20(), 0);
        // THEN rewardPerToken is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenCoinbase(), 0);
        // THEN alice reward is 0 because there is not rewards distributed
        assertEq(gauge.rewards(alice), 0);
        // THEN alice sponsorRewardPerTokenPaid is 0 because there is not rewards distributed
        assertEq(gauge.sponsorRewardPerTokenPaid(alice), 0);
        // THEN alice lastUpdateTime is 0 because there is not rewards distributed
        assertEq(gauge.lastUpdateTime(), 0);
    }

    /**
     * SCENARIO: SponsorsManager makes a partial deallocation to alice without no rewards distributed
     */
    function test_DeallocatePartial() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice
        gauge.allocate(alice, 1 ether);

        // WHEN deallocates 0.25 ether
        gauge.allocate(alice, 0.75 ether);

        // THEN alice allocation is 0.75 ether
        assertEq(gauge.allocationOf(alice), 0.75 ether);
        // THEN totalAllocation is 0.75 ether
        assertEq(gauge.totalAllocation(), 0.75 ether);
    }

    /**
     * SCENARIO: notifyRewardAmount with rewards split percentage different than 0
     * rewards variables are updated in the middle and at the end of the epoch
     */
    function test_NotifyRewardAmountWithStrategy() public {
        // GIVEN builder kickback percentage is 70%
        vm.startPrank(kycApprover);
        uint256 _kickback = 700_000_000_000_000_000;
        builderRegistry.activateBuilder(builder, builder, _kickback);

        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // WHEN 100 ether distributed
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 30 ether, 70 ether);
        gauge.notifyRewardAmountERC20(30 ether, 70 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerTokenERC20(), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(), block.timestamp);
        // THEN periodFinish is updated with the timestamp when the epoch finish
        assertEq(gauge.periodFinish(), EpochLib._epochNext(block.timestamp));
        // THEN time until next epoch is 518400
        assertEq(gauge.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000135030864197530 = 70 ether / 518400 sec
        assertEq(gauge.rewardRate() / 10 ** 18, 135_030_864_197_530);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 5.833333333333333333 = 518400 / 2 * 0.000135030864197530 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 5_833_333_333_333_333_333);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 11.666666666666666666 = 518400 * 0.000135030864197530 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 11_666_666_666_666_666_666);
        // THEN builderRewards is 30% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 30 ether);
    }

    /**
     * SCENARIO: rewards variables are updated in the middle and at the end of the epoch
     */
    function test_NotifyRewardAmount() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // WHEN 100 ether distributed
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 0 ether, 100 ether);
        gauge.notifyRewardAmountERC20(0, 100 ether);

        // THEN rewardPerTokenStored is 0
        assertEq(gauge.rewardPerTokenStored(), 0);
        // THEN rewardMissing is 0
        assertEq(gauge.rewardMissing(), 0);
        // THEN rewardPerToken is 0
        assertEq(gauge.rewardPerTokenERC20(), 0);
        // THEN lastUpdateTime is the current one
        assertEq(gauge.lastUpdateTime(), block.timestamp);
        // THEN periodFinish is updated with the timestamp when the epoch finish
        assertEq(gauge.periodFinish(), EpochLib._epochNext(block.timestamp));
        // THEN time until next epoch is 518400
        assertEq(gauge.periodFinish() - block.timestamp, 518_400);
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate() / 10 ** 18, 192_901_234_567_901);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 8_333_333_333_333_333_333);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: builder claim his rewards at any time during the epoch receiving the total amount of rewards.
     */
    function test_ClaimBuilderRewardsBuilder() public {
        // GIVEN builder kickback percentage is 30% and reward receiver is alice
        vm.startPrank(kycApprover);
        uint256 _kickback = 300_000_000_000_000_000;
        builderRegistry.activateBuilder(builder, alice, _kickback);

        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN 70 ether are for builder and 30 ether for sponsors
        gauge.notifyRewardAmountERC20(70 ether, 30 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // THEN builderRewards is 70% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 70 ether);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderRewardERC20(builder);
        // THEN alice rewardToken balance is 70% of 100 ether
        assertEq(rewardToken.balanceOf(alice), 70 ether);
    }

    /**
     * SCENARIO: reward receiver claim his rewards at any time during the epoch receiving the total amount of rewards.
     */
    function test_ClaimBuilderRewardsRewardReceiver() public {
        // GIVEN builder kickback percentage is 30% and reward receiver is alice
        vm.startPrank(kycApprover);
        uint256 _kickback = 300_000_000_000_000_000;
        builderRegistry.activateBuilder(builder, alice, _kickback);

        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN 70 ether are for builder and 30 ether for sponsors
        gauge.notifyRewardAmountERC20(70 ether, 30 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // THEN builderRewards is 70% of 100 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 70 ether);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

        // WHEN builder claims rewards
        vm.startPrank(alice);
        gauge.claimBuilderRewardERC20(builder);
        // THEN alice rewardToken balance is 70% of 100 ether
        assertEq(rewardToken.balanceOf(alice), 70 ether);
    }

    /**
     * SCENARIO: there are 2 distributions on the same epoch, builder claim the rewards
     */
    function test_ClaimBuilderRewards2Distributions() public {
        // GIVEN builder kickback percentage is 30% and reward receiver is alice
        vm.startPrank(kycApprover);
        uint256 _kickback = 300_000_000_000_000_000;
        builderRegistry.activateBuilder(builder, alice, _kickback);

        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN 70 ether are for builder and 30 ether for sponsors
        gauge.notifyRewardAmountERC20(70 ether, 30 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // AND 70 ether are for builder and 30 ether for sponsors
        gauge.notifyRewardAmountERC20(70 ether, 30 ether);

        // THEN builderRewards is 70% of 200 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderRewardERC20(builder);

        // THEN alice rewardToken balance is 70% of 200 ether
        assertEq(rewardToken.balanceOf(alice), 140 ether);
    }

    /**
     * SCENARIO: there are 2 epochs, builder claim the rewards
     */
    function test_ClaimBuilderRewards2Epochs() public {
        // GIVEN builder kickback percentage is 30% and reward receiver is alice
        vm.startPrank(kycApprover);
        uint256 _kickback = 300_000_000_000_000_000;
        builderRegistry.activateBuilder(builder, alice, _kickback);

        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // AND 70 ether are for builder and 30 ether for sponsors
        gauge.notifyRewardAmountERC20(70 ether, 30 ether);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

        // AND 70 ether are for builder and 30 ether for sponsors
        gauge.notifyRewardAmountERC20(70 ether, 30 ether);

        // THEN builderRewards is 70% of 200 ether
        assertEq(gauge.builderRewards(address(rewardToken)), 140 ether);

        // WHEN builder claims rewards
        vm.startPrank(builder);
        gauge.claimBuilderRewardERC20(builder);

        // THEN alice rewardToken balance is 70% of 200 ether
        assertEq(rewardToken.balanceOf(alice), 140 ether);
    }

    /**
     * SCENARIO: alice and bob claim his rewards at the end of the epoch receiving the total amount of rewards.
     *  If they claim again without a new reward distribution they don't receive rewardTokens again.
     */
    function test_ClaimSponsorRewards() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 100 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 16.666666666666666666 = 518400 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 16_666_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is 16.666666666666666666 = 1 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorRewardERC20(bob);
        // THEN bob rewardToken balance is 83.333333333333333330 = 5 * 16.666666666666666666
        assertEq(rewardToken.balanceOf(bob), 83_333_333_333_333_333_330);

        // AND another epoch finish without a new distribution
        _skipAndStartNewEpoch();

        // WHEN alice claims rewards again
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance didn't change
        assertEq(rewardToken.balanceOf(alice), 16_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: alice and bob claim his rewards in the middle of the epoch receiving partial rewards.
     */
    function test_ClaimSponsorRewardsPartial() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 100 ether);

        // AND 1/3 epoch pass
        _skipRemainingEpochFraction(3);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 5.555555555555555555 = 518400 / 3 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 5_555_555_555_555_555_555);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is 5.555555555555555555 = 1 * 5.555555555555555555
        assertEq(rewardToken.balanceOf(alice), 5_555_555_555_555_555_555);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorRewardERC20(bob);
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
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 100 ether);
        // AND epoch finish
        _skipAndStartNewEpoch();
        // AND 200 ether more are distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 200 ether);
        // AND epoch finish
        _skipAndStartNewEpoch();

        // THEN rewardPerTokenStored is 16.666666666666666666 = 100 ether / 518400 sec from epoch 1
        assertEq(gauge.rewardPerTokenStored(), 16_666_666_666_666_666_666);
        // time until next epoch is 604800
        // THEN rewardRate is 0.000330687830687830 = 200 ether / 604800 sec
        assertEq(gauge.rewardRate() / 10 ** 18, 330_687_830_687_830);
        // THEN rewardPerToken is
        //  49.999999999999999999 = 16.666666666666666666 + 604800 * 0.000330687830687830 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 49_999_999_999_999_999_999);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorRewardERC20(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: there are 2 distributions on the same epoch, alice and bob claim them
     */
    function test_ClaimSponsorRewards2DistributionOnSameEpoch() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 100 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND 200 ether more are distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 200 ether);
        // AND epoch finish
        _skipAndStartNewEpoch();

        // time until next epoch is 259200
        // rewardRate = 0.000192901234567901
        // leftover = 259200 * 0.000192901234567901 = 49.9999999999999392
        // THEN rewardRate is 0.000964506172839506 = (200 + 49.9999999999999392) / 259200 sec
        assertEq(gauge.rewardRate() / 10 ** 18, 964_506_172_839_506);
        // THEN rewardPerToken is
        // rewardPerTokenStored = 8.333333333333333333
        //  49.999999999999999999 = 8.333333333333333333 + 259200 * 0.000964506172839506 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 49_999_999_999_999_999_999);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is 49.999999999999999999 = 1 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_999);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorRewardERC20(bob);
        // THEN bob rewardToken balance is 249.999999999999999995 = 5 * 49.999999999999999999
        assertEq(rewardToken.balanceOf(bob), 249_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: alice quit before the epoch finish, so receives less rewards and bob more
     */
    function test_ClaimSponsorRewardsAliceQuit() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 100 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN alice deallocates all
        gauge.allocate(alice, 0 ether);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 8_333_333_333_333_333_333);

        // AND epoch finish
        _skipAndStartNewEpoch();
        // THEN rewardPerToken is
        //  18.333333333333333332 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 5 ether
        assertEq(gauge.rewardPerTokenERC20(), 18_333_333_333_333_333_332);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is 8.333333333333333333 = 1 * 8.333333333333333333
        assertEq(rewardToken.balanceOf(alice), 8_333_333_333_333_333_333);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorRewardERC20(bob);
        // THEN bob rewardToken balance is 91.666666666666666660 = 5 * 18.333333333333333332
        assertEq(rewardToken.balanceOf(bob), 91_666_666_666_666_666_660);
    }

    /**
     * SCENARIO: alice allocates more before the epoch finish, so receives more rewards and bob less
     */
    function test_ClaimSponsorRewardsAliceAllocatesAgain() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 100 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN alice allocates 1 ether more
        gauge.allocate(alice, 2 ether);

        // time until next epoch is 518400
        // rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        // THEN rewardPerToken is 8.333333333333333333 = 518400 / 2 * 0.000192901234567901 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 8_333_333_333_333_333_333);

        // AND epoch finish
        _skipAndStartNewEpoch();
        // THEN rewardPerToken is
        //  15.476190476190476190 = 8.333333333333333333 + 518400 / 2 * 0.000192901234567901 / 7 ether
        assertEq(gauge.rewardPerTokenERC20(), 15_476_190_476_190_476_190);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is
        //  22.619047619047619047 = 1 * 8.333333333333333333 + 2 * (15.476190476190476190 - 8.333333333333333333)
        assertEq(rewardToken.balanceOf(alice), 22_619_047_619_047_619_047);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorRewardERC20(bob);
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
        gauge.notifyRewardAmountERC20(0, 100 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND alice deallocates all
        gauge.allocate(alice, 0 ether);
        // time until next epoch is 518400
        // THEN rewardRate is 0.000192901234567901 = 100 ether / 518400 sec
        assertEq(gauge.rewardRate() / 10 ** 18, 192_901_234_567_901);
        // THEN rewardPerTokenStored is 24.999999999999999999 = 518400 / 2 * 0.000192901234567901 / 2 ether
        assertEq(gauge.rewardPerTokenStored(), 24_999_999_999_999_999_999);
        // THEN rewardPerToken is 24.999999999999999999 = 24999999999999999999 + 0
        assertEq(gauge.rewardPerTokenERC20(), 24_999_999_999_999_999_999);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN 2 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);
        // THEN rewardMissing is 49.999999999999999999 = 518400 / 2 * 0.000192901234567901
        assertEq(gauge.rewardMissing() / 10 ** 18, 49_999_999_999_999_999_999);

        // AND 100 ether distributed for sponsors
        gauge.notifyRewardAmountERC20(0, 100 ether);
        // AND epoch finish
        _skipAndStartNewEpoch();

        // THEN rewardRate is 0.000248015873015873 = 100 + 49.999999999999999999 ether / 604800 sec
        assertEq(gauge.rewardRate() / 10 ** 18, 248_015_873_015_873);
        // THEN rewardPerToken is
        //  49.999999999999999999 = 24.999999999999999999 + 604800 * 0.000248015873015873 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 49_999_999_999_999_999_998);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is
        //  74.999999999999999997 = 2 * 24.999999999999999999 + 1 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(alice), 74_999_999_999_999_999_997);

        // WHEN bob claims rewards
        vm.startPrank(bob);
        gauge.claimSponsorRewardERC20(bob);
        // THEN bob rewardToken balance is 124.999999999999999995 = 5 * (49.999999999999999998 - 24.999999999999999999)
        assertEq(rewardToken.balanceOf(bob), 124_999_999_999_999_999_995);
    }

    /**
     * SCENARIO: notifyRewardAmount with rewards split percentage different than 0
     * rewards variables are updated in the middle and at the end of the epoch
     */
    function test_NotifyRewardAmountUsingCoinbase() public {
        // GIVEN builder kickback percentage is 70%
        vm.startPrank(kycApprover);
        uint256 _kickback = 700_000_000_000_000_000;
        builderRegistry.activateBuilder(builder, builder, _kickback);

        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice and 5 ether to bob
        gauge.allocate(alice, 1 ether);
        gauge.allocate(bob, 5 ether);

        // WHEN 100 ether for ERC20 and 10 ether for coinbase are distributed
        //  THEN notifyRewardAmount event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), 30 ether, 70 ether);
        gauge.notifyRewardAmountERC20(30 ether, 70 ether);
        vm.expectEmit();
        emit NotifyReward(UtilsLib._COINBASE_ADDRESS, 3 ether, 7 ether);
        gauge.notifyRewardAmountCoinbase{ value: 10 ether }(3 ether, 7 ether);

        // THEN builderRewards is 30% of 10 ether
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 3 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // THEN rewardPerToken is 5.833333333333333333 = 518400 / 2 * 0.000135030864197530 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 5_833_333_333_333_333_333);
        // THEN rewardPerToken in coinbase is 0.583333333333333333
        assertEq(gauge.rewardPerTokenCoinbase(), 583_333_333_333_333_333);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // THEN rewardPerToken is 11.666666666666666666 = 518400 * 0.000135030864197530 / 6 ether
        assertEq(gauge.rewardPerTokenERC20(), 11_666_666_666_666_666_666);
        // THEN rewardPerToken in coinbase is 1.166666666666666666
        assertEq(gauge.rewardPerTokenCoinbase(), 1_166_666_666_666_666_666);

        // WHEN alice claims rewards
        vm.startPrank(alice);
        gauge.claimSponsorRewardERC20(alice);
        // THEN alice rewardToken balance is
        //  11.666666666666666666 = 1 * 11.666666666666666666
        assertEq(rewardToken.balanceOf(alice), 11_666_666_666_666_666_666);
        //  1.66666666666666666 = 1 * 1.66666666666666666
        assertEq(alice.balance, 1_166_666_666_666_666_666);
    }
}
