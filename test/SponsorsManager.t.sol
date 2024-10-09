// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdStorage, StdStorage, stdError } from "forge-std/src/Test.sol";
import { BaseTest, SponsorsManager, Gauge } from "./BaseTest.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract SponsorsManagerTest is BaseTest {
    using stdStorage for StdStorage;
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event NewAllocation(address indexed sponsor_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event RewardDistributionStarted(address indexed sender_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);

    /**
     * SCENARIO: allocate should revert if it is called with arrays with different lengths
     */
    function test_RevertAllocateBatchUnequalLengths() public {
        // GIVEN a SponsorManager contract
        //  WHEN alice calls allocateBatch with wrong array lengths
        vm.startPrank(alice);
        allocationsArray.push(0);
        //   THEN tx reverts because UnequalLengths
        vm.expectRevert(SponsorsManager.UnequalLengths.selector);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
    }

    /**
     * SCENARIO: allocate should revert if gauge does not exist
     */
    function test_RevertGaugeDoesNotExist() public {
        // GIVEN a SponsorManager contract
        // AND a new gauge created by the factor
        Gauge _wrongGauge = gaugeFactory.createGauge();
        //  WHEN alice calls allocateBatch using the wrong gauge
        //   THEN tx reverts because GaugeDoesNotExist
        gaugesArray.push(_wrongGauge);
        allocationsArray.push(100 ether);
        vm.startPrank(alice);
        vm.expectRevert(SponsorsManager.GaugeDoesNotExist.selector);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
    }

    /**
     * SCENARIO: alice and bob allocate for 2 builders and variables are updated
     */
    function test_AllocateBatch() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        // AND a new epoch
        _skipAndStartNewEpoch();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // WHEN alice allocates 2 ether to builder and 6 ether to builder2
        //  THEN 2 NewAllocation events are emitted
        vm.expectEmit();
        emit NewAllocation(alice, address(gaugesArray[0]), 2 ether);
        vm.expectEmit();
        emit NewAllocation(alice, address(gaugesArray[1]), 6 ether);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN total potential rewards is 13305600 ether = 22 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 13_305_600 ether);
        // THEN alice total allocation is 8 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 8 ether);
        // THEN bob total allocation is 14 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(bob), 14 ether);
    }

    /**
     * SCENARIO: alice allocates on a batch passing the same gauge twice
     */
    function test_AllocateBatchGaugeRepeated() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        // AND a new epoch
        _skipAndStartNewEpoch();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;

        gaugesArray.push(gauge);
        allocationsArray.push(10 ether);
        // WHEN alice allocates to [gauge, gauge2, gauge] = [2, 6, 10]
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN is considered the last allocation
        //  alice gauge allocation is 10 ether
        assertEq(gauge.allocationOf(alice), 10 ether);
        // THEN alice gauge2 allocation is 6 ether
        assertEq(gauge2.allocationOf(alice), 6 ether);
        // THEN total potential rewards is 9676800 ether = 16 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 9_676_800 ether);
        // THEN alice total allocation is 16 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 16 ether);
    }

    /**
     * SCENARIO: alice override her allocaition
     */
    function test_AllocateOverride() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        // AND a new epoch
        _skipAndStartNewEpoch();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // WHEN alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND alice override gauge allocation from 2 ether to 10 ether
        sponsorsManager.allocate(gauge, 10 ether);

        // THEN is considered the last allocation
        //  alice gauge allocation is 10 ether
        assertEq(gauge.allocationOf(alice), 10 ether);
        // THEN alice gauge2 allocation is 6 ether
        assertEq(gauge2.allocationOf(alice), 6 ether);
        // THEN total potential rewards is 9676800 ether = 16 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 9_676_800 ether);
        // THEN alice total allocation is 16 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 16 ether);
    }

    /**
     * SCENARIO: alice allocates on a batch to gauge and gauge2. After, allocates again
     *  adding allocation to gauge3. Previous allocation is not modified
     */
    function test_AllocateBatchOverride() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        // AND a new epoch
        _skipAndStartNewEpoch();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;

        // WHEN alice allocates to [gauge, gauge2] = [2, 6]
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        address _builder3 = makeAddr("_builder3");
        Gauge _gauge3 = _whitelistBuilder(_builder3, _builder3, 0.5 ether);
        gaugesArray.push(_gauge3);
        allocationsArray.push(10 ether);

        // AND alice allocates again to [gauge, gauge2, gauge3] = [2, 6, 10]
        vm.startPrank(alice);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN previous allocation didn't change
        //  alice gauge allocation is 2 ether
        assertEq(gauge.allocationOf(alice), 2 ether);
        // THEN alice gauge2 allocation is 6 ether
        assertEq(gauge2.allocationOf(alice), 6 ether);
        // THEN alice gauge3 allocation is 6 ether
        assertEq(_gauge3.allocationOf(alice), 10 ether);
        // THEN total potential rewards is 10886400 ether = 18 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 10_886_400 ether);
        // THEN alice total allocation is 18 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 18 ether);
    }

    /**
     * SCENARIO: alice modifies allocation for 2 builders and variables are updated
     */
    function test_ModifyAllocation() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        // AND a new epoch
        _skipAndStartNewEpoch();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // WHEN alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        // THEN total allocation is 4838400 ether = 8 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 4_838_400 ether);
        // THEN alice total allocation is 8 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 8 ether);

        // WHEN half epoch pass
        _skipRemainingEpochFraction(2);
        // AND alice modifies the allocation: 10 ether to builder and 0 ether to builder2
        allocationsArray[0] = 10 ether;
        allocationsArray[1] = 0 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN total allocation is 5443200 ether = 8 * 1 WEEK + 2 * 1/2 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 5_443_200 ether);
        // THEN alice total allocation is 10 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 10 ether);
    }

    /**
     * SCENARIO: allocate should revert when alice tries to allocate more than her staking token balance
     */
    function test_RevertNotEnoughStaking() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 99_000 ether;
        allocationsArray[1] = 1000 ether;
        // WHEN alice allocates all the staking to 2 builders
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // WHEN alice modifies the allocation: trying to add 1 ether more
        allocationsArray[0] = 100_001 ether;
        allocationsArray[1] = 0 ether;
        // THEN tx reverts because NotEnoughStaking
        vm.expectRevert(SponsorsManager.NotEnoughStaking.selector);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
    }

    /**
     * SCENARIO: notifyRewardAmount is called using ERC20 and values are updated
     */
    function test_NotifyRewardAmountERC20() public {
        // GIVEN a SponsorManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0.1 ether);
        //   WHEN 2 ether reward are added
        //    THEN NotifyReward event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), address(this), 2 ether);
        sponsorsManager.notifyRewardAmount(2 ether);
        // THEN rewards is 2 ether
        assertEq(sponsorsManager.rewardsERC20(), 2 ether);
        // THEN Coinbase rewards is 0
        assertEq(sponsorsManager.rewardsCoinbase(), 0);
        // THEN reward token balance of sponsorsManager is 2 ether
        assertEq(rewardToken.balanceOf(address(sponsorsManager)), 2 ether);
        // THEN Coinbase balance of sponsorsManager is 0
        assertEq(address(sponsorsManager).balance, 0);
    }

    /**
     * SCENARIO: notifyRewardAmount is called using Coinbase and values are updated
     */
    function test_NotifyRewardAmountCoinbase() public {
        // GIVEN a SponsorManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0.1 ether);
        //   WHEN 2 ether reward are added
        //    THEN NotifyReward event is emitted
        vm.expectEmit();
        emit NotifyReward(UtilsLib._COINBASE_ADDRESS, address(this), 2 ether);
        sponsorsManager.notifyRewardAmount{ value: 2 ether }(0);
        // THEN Coinbase rewards is 2 ether
        assertEq(sponsorsManager.rewardsCoinbase(), 2 ether);
        // THEN ERC20 rewards is 0
        assertEq(sponsorsManager.rewardsERC20(), 0);
        // THEN Coinbase balance of sponsorsManager is 2 ether
        assertEq(address(sponsorsManager).balance, 2 ether);
        // THEN reward token balance of sponsorsManager is 0
        assertEq(rewardToken.balanceOf(address(sponsorsManager)), 0);
    }

    /**
     * SCENARIO: notifyRewardAmount is called twice before distribution and values are updated
     */
    function test_NotifyRewardAmountTwice() public {
        // GIVEN a SponsorManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0.1 ether);
        // AND 2 ether reward are added
        sponsorsManager.notifyRewardAmount(2 ether);
        // WHEN 10 ether reward are more added
        sponsorsManager.notifyRewardAmount(10 ether);
        // THEN rewards is is 12 ether
        assertEq(sponsorsManager.rewardsERC20(), 12 ether);
        // THEN reward token balance of sponsorsManager is 12 ether
        assertEq(rewardToken.balanceOf(address(sponsorsManager)), 12 ether);
    }

    /**
     * SCENARIO: should revert is distribution period started
     */
    function test_RevertNotInDistributionPeriod() public {
        // GIVEN a SponsorManager contract
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 gauges created
        for (uint256 i = 0; i < 20; i++) {
            Gauge _newGauge = _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            gaugesArray.push(_newGauge);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        //  AND 2 ether reward are added
        sponsorsManager.notifyRewardAmount(2 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        //  AND distribution start
        sponsorsManager.startDistribution();

        // WHEN tries to allocate during the distribution period
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(SponsorsManager.NotInDistributionPeriod.selector);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        // WHEN tries to add more reward
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(SponsorsManager.NotInDistributionPeriod.selector);
        sponsorsManager.notifyRewardAmount(2 ether);
        // WHEN tries to start distribution again
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(SponsorsManager.NotInDistributionPeriod.selector);
        sponsorsManager.startDistribution();
    }

    /**
     * SCENARIO: should revert is distribution window did not start
     */
    function test_RevertOnlyInDistributionWindow() public {
        // GIVEN a SponsorManager contract
        // WHEN someone tries to distribute after the distribution window start
        _skipToEndDistributionWindow();
        //  THEN tx reverts because OnlyInDistributionWindow
        vm.expectRevert(SponsorsManager.OnlyInDistributionWindow.selector);
        sponsorsManager.startDistribution();
    }

    /**
     * SCENARIO: should revert is distribution period did not start
     */
    function test_RevertDistributionPeriodDidNotStart() public {
        // GIVEN a SponsorManager contract
        // WHEN someone tries to distribute before the distribution period start
        //  THEN tx reverts because DistributionPeriodDidNotStart
        vm.expectRevert(SponsorsManager.DistributionPeriodDidNotStart.selector);
        sponsorsManager.distribute();
    }

    /**
     * SCENARIO: alice and bob allocates to 2 gauges and distribute rewards to them
     */
    function test_Distribute() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        //  WHEN distribute is executed
        //   THEN RewardDistributionStarted event is emitted
        vm.expectEmit();
        emit RewardDistributionStarted(address(this));
        //   THEN RewardDistributed event is emitted
        vm.expectEmit();
        emit RewardDistributed(address(this));
        //   THEN RewardDistributionFinished event is emitted
        vm.expectEmit();
        emit RewardDistributionFinished(address(this));
        sponsorsManager.startDistribution();
        // THEN reward token balance of gauge is 27.272727272727272727 = 100 * 6 / 22
        assertEq(rewardToken.balanceOf(address(gauge)), 27_272_727_272_727_272_727);
        // THEN reward token balance of gauge2 is 72.727272727272727272 = 100 * 16 / 22
        assertEq(rewardToken.balanceOf(address(gauge2)), 72_727_272_727_272_727_272);
    }

    /**
     * SCENARIO: alice and bob allocates to 2 gauges and receive coinbase rewards
     */
    function test_DistributeCoinbase() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether rewardToken and 50 ether coinbase are added
        sponsorsManager.notifyRewardAmount{ value: 50 ether }(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        //  WHEN distribute is executed
        sponsorsManager.startDistribution();
        // THEN reward token balance of gauge is 27.272727272727272727 = 100 * 6 / 22
        assertEq(rewardToken.balanceOf(address(gauge)), 27_272_727_272_727_272_727);
        // THEN reward token balance of gauge2 is 72.727272727272727272 = 100 * 16 / 22
        assertEq(rewardToken.balanceOf(address(gauge2)), 72_727_272_727_272_727_272);
        // THEN coinbase balance of gauge is 13.636363636363636363 = 50 * 6 / 22
        assertEq(address(gauge).balance, 13_636_363_636_363_636_363);
        // THEN coinbase balance of gauge2 is 36.363636363636363636 = 50 * 16 / 22
        assertEq(address(gauge2).balance, 36_363_636_363_636_363_636);
    }

    /**
     * SCENARIO: distribute twice on the same epoch with different allocations.
     *  The second allocation occurs on the distribution window timestamp.
     */
    function test_DistributeTwiceSameEpoch() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added and distributed
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        sponsorsManager.startDistribution();

        // AND bob modifies his allocations 16 ether to builder and 4 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 16 ether;
        allocationsArray[1] = 4 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  WHEN 100 ether reward are added and distributed again
        sponsorsManager.notifyRewardAmount(100 ether);
        sponsorsManager.startDistribution();

        // THEN reward token balance of gauge is 91.558441558441558441 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(gauge)), 91_558_441_558_441_558_441);
        // THEN reward token balance of gauge2 is 108.441558441558441557 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(gauge2)), 108_441_558_441_558_441_557);
    }

    /**
     * SCENARIO: alice transfer part of her allocation in the middle of the epoch
     *  from builder to builder2, so the rewards accounted on that time are moved to builder2 too
     */
    function test_ModifyAllocationBeforeDistribution() public {
        // GIVEN a SponsorManager contract
        // AND a new epoch
        _skipAndStartNewEpoch();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 10 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND alice modifies his allocations 5 ether to builder2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 5 ether);
        sponsorsManager.allocate(gauge2, 5 ether);
        vm.stopPrank();

        // THEN rewardShares is 4536000 ether = 10 * 1/2 WEEK + 5 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 4_536_000 ether);
        // THEN rewardShares is 7560000 ether = 10 * 1/2 WEEK + 15 * 1/2 WEEK
        assertEq(gauge2.rewardShares(), 7_560_000 ether);
        // THEN total allocation is 12096000 ether = 4536000 + 7560000
        assertEq(sponsorsManager.totalPotentialReward(), 12_096_000 ether);

        //  AND 100 ether reward are added and distributed
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        sponsorsManager.startDistribution();

        // THEN rewardShares is 3024000 ether = 5 * 1 WEEK
        assertEq(gauge.rewardShares(), 3_024_000 ether);
        // THEN rewardShares is 9072000 ether = 15 * 1 WEEK
        assertEq(gauge2.rewardShares(), 9_072_000 ether);
        // THEN total allocation is 12096000 ether = 3024000 + 9072000
        assertEq(sponsorsManager.totalPotentialReward(), 12_096_000 ether);

        // THEN reward token balance of gauge is 37.5 ether = 100 * 4536000 / 12096000
        assertEq(rewardToken.balanceOf(address(gauge)), 37.5 ether);
        // THEN reward token balance of gauge2 is 62.5 ether = 100 * 7560000 / 12096000
        assertEq(rewardToken.balanceOf(address(gauge2)), 62.5 ether);
    }

    /**
     * SCENARIO: alice removes all her allocation in the middle of the epoch
     *  from builder, so the rewards accounted on that time decrease
     */
    function test_UnallocationBeforeDistribution() public {
        // GIVEN a SponsorManager contract
        // AND a new epoch
        _skipAndStartNewEpoch();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 10 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND alice unallocates all from builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);
        vm.stopPrank();

        // THEN rewardShares is 3024000 ether = 10 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 3_024_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 9072000 ether = 3024000 + 6048000
        assertEq(sponsorsManager.totalPotentialReward(), 9_072_000 ether);

        //  AND 100 ether reward are added and distributed
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        sponsorsManager.startDistribution();

        // THEN rewardShares is 0
        assertEq(gauge.rewardShares(), 0);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 6048000 ether = 0 + 6048000
        assertEq(sponsorsManager.totalPotentialReward(), 6_048_000 ether);

        // THEN reward token balance of gauge is 33.33 ether = 100 * 3024000 / 9072000
        assertEq(rewardToken.balanceOf(address(gauge)), 33_333_333_333_333_333_333);
        // THEN reward token balance of gauge2 is 66.66 ether = 100 * 6048000 / 9072000
        assertEq(rewardToken.balanceOf(address(gauge2)), 66_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: alice removes part of her allocation in the middle of the epoch
     *  from builder, so the rewards accounted on that time decrease
     */
    function test_RemoveAllocationBeforeDistribution() public {
        // GIVEN a SponsorManager contract
        // AND a new epoch
        _skipAndStartNewEpoch();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 10 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND alice removes 5 ether from builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 5 ether);
        vm.stopPrank();

        // THEN rewardShares is 4536000 ether = 10 * 1/2 WEEK + 5 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 4_536_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 10584000 ether = 4536000 + 6048000
        assertEq(sponsorsManager.totalPotentialReward(), 10_584_000 ether);

        //  AND 100 ether reward are added and distributed
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        sponsorsManager.startDistribution();

        // THEN rewardShares is 3024000 ether = 5 * 1 WEEK
        assertEq(gauge.rewardShares(), 3_024_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 9072000 ether = 3024000 + 6048000
        assertEq(sponsorsManager.totalPotentialReward(), 9_072_000 ether);

        // THEN reward token balance of gauge is 42.857 ether = 100 * 4536000 / 10584000
        assertEq(rewardToken.balanceOf(address(gauge)), 42_857_142_857_142_857_142);
        // THEN reward token balance of gauge2 is 57.142 ether = 100 * 6048000 / 10584000
        assertEq(rewardToken.balanceOf(address(gauge2)), 57_142_857_142_857_142_857);
    }

    /**
     * SCENARIO: alice adds allocation in the middle of the epoch
     *  to builder, so the rewards accounted on that time increase
     */
    function test_AddAllocationBeforeDistribution() public {
        // GIVEN a SponsorManager contract
        // AND a new epoch
        _skipAndStartNewEpoch();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 10 ether);

        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND alice adds 5 ether to builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 15 ether);
        vm.stopPrank();

        // THEN rewardShares is 7560000 ether = 10 * 1/2 WEEK + 15 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 7_560_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 13608000 ether = 7560000 + 6048000
        assertEq(sponsorsManager.totalPotentialReward(), 13_608_000 ether);

        //  AND 100 ether reward are added and distributed
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        sponsorsManager.startDistribution();

        // THEN rewardShares is 9072000 ether = 15 * 1 WEEK
        assertEq(gauge.rewardShares(), 9_072_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 15120000 ether = 9072000 + 6048000
        assertEq(sponsorsManager.totalPotentialReward(), 15_120_000 ether);

        // THEN reward token balance of gauge is 55.5 ether = 100 * 7560000 / 13608000
        assertEq(rewardToken.balanceOf(address(gauge)), 55_555_555_555_555_555_555);
        // THEN reward token balance of gauge2 is 44.4 ether = 100 * 6048000 / 13608000
        assertEq(rewardToken.balanceOf(address(gauge2)), 44_444_444_444_444_444_444);
    }

    /**
     * SCENARIO: distribute on 2 consecutive epoch with different allocations
     */
    function test_DistributeTwice() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added and distributed
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        sponsorsManager.startDistribution();
        // AND epoch finish
        _skipAndStartNewEpoch();

        // AND bob modifies his allocations 16 ether to builder and 4 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 16 ether;
        allocationsArray[1] = 4 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  WHEN 100 ether reward are added and distributed again
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        sponsorsManager.startDistribution();

        // THEN reward token balance of gauge is 91.558441558441558441 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(gauge)), 91_558_441_558_441_558_441);
        // THEN reward token balance of gauge2 is 108.441558441558441557 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(gauge2)), 108_441_558_441_558_441_557);
    }

    /**
     * SCENARIO: distribution occurs on different transactions using pagination
     */
    function test_DistributeUsingPagination() public {
        // GIVEN a sponsor alice
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 gauges created
        for (uint256 i = 0; i < 20; i++) {
            Gauge _newGauge = _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            gaugesArray.push(_newGauge);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 ether reward are added
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // WHEN distribute is executed
        sponsorsManager.startDistribution();
        // THEN temporal total potential rewards is 12096000 ether = 20 * 1 WEEK
        assertEq(sponsorsManager.tempTotalPotentialReward(), 12_096_000 ether);
        // THEN distribution period is still started
        assertEq(sponsorsManager.onDistributionPeriod(), true);
        // THEN last gauge distributed is gauge 20
        assertEq(sponsorsManager.indexLastGaugeDistributed(), 20);

        // AND distribute is executed again
        sponsorsManager.distribute();
        // THEN temporal total potential rewards is 0
        assertEq(sponsorsManager.tempTotalPotentialReward(), 0);
        // THEN total potential rewards is 13305600 ether = 22 * 1 WEEK
        assertEq(sponsorsManager.totalPotentialReward(), 13_305_600 ether);
        // THEN distribution period finished
        assertEq(sponsorsManager.onDistributionPeriod(), false);
        // THEN last gauge distributed is 0
        assertEq(sponsorsManager.indexLastGaugeDistributed(), 0);

        for (uint256 i = 0; i < 22; i++) {
            // THEN reward token balance of all the gauges is 4.545454545454545454 = 100 * 1 / 22
            assertEq(rewardToken.balanceOf(address(gaugesArray[i])), 4_545_454_545_454_545_454);
        }
    }

    /**
     * SCENARIO: distribution occurs on different transactions using pagination and
     * attempts to incentivize a gauge in new epoch before and during distribution should
     * fail
     */
    function test_DistributeAndIncentivizeGaugeDuringPagination() public {
        // GIVEN a sponsor alice
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 gauges created
        for (uint256 i = 0; i < 20; i++) {
            Gauge _newGauge = _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            gaugesArray.push(_newGauge);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 ether reward are added
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // WHEN there is an attempt to incentivize a gauge directly before distribution starts
        // with rewardToken
        //  THEN notifyRewardAmount reverts with BeforeDistribution error
        vm.startPrank(incentivizer);
        vm.expectRevert(Gauge.BeforeDistribution.selector);
        gauge.notifyRewardAmount(address(rewardToken), 100 ether);
        vm.stopPrank();

        // WHEN there is an attempt to incentivize a gauge directly before distribution starts
        // with coinbase
        //  THEN notifyRewardAmount reverts with BeforeDistribution error
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);
        vm.expectRevert(Gauge.BeforeDistribution.selector);
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 100 ether);
        vm.stopPrank();

        // WHEN distribute is executed
        sponsorsManager.startDistribution();

        // THEN last gauge distributed is gauge 20
        assertEq(sponsorsManager.indexLastGaugeDistributed(), 20);

        // AND some minutes pass
        skip(600);

        // WHEN there is an attempt to incentivize a gauge directly before distribution ends
        //  THEN notifyRewardAmount reverts
        vm.startPrank(incentivizer);
        vm.expectRevert(Gauge.BeforeDistribution.selector);
        gauge.notifyRewardAmount(address(rewardToken), 100 ether);
        vm.stopPrank();

        // WHEN there is an attempt to incentivize a gauge directly before distribution ends
        // with coinbase
        //  THEN notifyRewardAmount reverts
        vm.startPrank(incentivizer);
        vm.expectRevert(Gauge.BeforeDistribution.selector);
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 100 ether);
        vm.stopPrank();

        // AND distribute is executed again
        sponsorsManager.distribute();

        // THEN distribution period finished
        assertEq(sponsorsManager.onDistributionPeriod(), false);
        // THEN last gauge distributed is 0
        assertEq(sponsorsManager.indexLastGaugeDistributed(), 0);

        for (uint256 i = 0; i < 22; i++) {
            // THEN reward token balance of all the gauges is 4.545454545454545454 = 100 * 1 / 22
            assertEq(rewardToken.balanceOf(address(gaugesArray[i])), 4_545_454_545_454_545_454);
        }
    }

    /**
     * SCENARIO: distribution occurs on different transactions using pagination and attempts to incentivize
     * SponsorsManager between both transactions should fail
     */
    function test_DistributeAndIncentivizeSponsorsManagerDuringPagination() public {
        // GIVEN a sponsor alice
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 gauges created
        for (uint256 i = 0; i < 20; i++) {
            Gauge _newGauge = _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            gaugesArray.push(_newGauge);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 ether reward are added
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // WHEN distribute is executed
        sponsorsManager.startDistribution();
        // THEN distribution period started
        assertEq(sponsorsManager.onDistributionPeriod(), true);

        // WHEN there is an attempt to add 100 ether reward in the middle of the distribution
        //  THEN notifyRewardAmount reverts
        vm.expectRevert(SponsorsManager.NotInDistributionPeriod.selector);
        sponsorsManager.notifyRewardAmount(100 ether);

        // AND distribute is executed again
        sponsorsManager.distribute();

        // THEN distribution period finished
        assertEq(sponsorsManager.onDistributionPeriod(), false);

        for (uint256 i = 0; i < 22; i++) {
            // THEN reward token balance of all the gauges is 4.545454545454545454 = 100 * 1 / 22
            assertEq(rewardToken.balanceOf(address(gaugesArray[i])), 4_545_454_545_454_545_454);
        }
    }

    /**
     * SCENARIO: alice claims all the rewards in a single tx
     */
    function test_ClaimSponsorRewards() public {
        // GIVEN builder and builder2 which kickback percentage is 50%
        //  AND a sponsor alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether reward are added
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        sponsorsManager.startDistribution();

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 50% of the distributed amount
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_992);
    }

    /**
     * SCENARIO: alice claims all the rewards from a sponsorManager distribution and
     * incentivized gauge with rewardToken
     */
    function test_ClaimSponsorRewardsWithIncentivizerInRewardToken() public {
        // GIVEN builder and builder2 and kickback percentage of 50%
        //  AND a sponsor alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether reward are added
        sponsorsManager.notifyRewardAmount(100 ether);
        // AND 100 ether are added directly to first gauge by incentivizer
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether);
        rewardToken.approve(address(gaugesArray[0]), 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 100 ether);
        vm.stopPrank();

        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        sponsorsManager.startDistribution();

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 50% of the distributed amount from the sponsorsManager
        // and 100% of the rewards incentivized directly to the first gauge
        // 149.999999999999999990 = 100 ether * 0.5 + 100 ether
        assertEq(rewardToken.balanceOf(alice), 149_999_999_999_999_999_990);
    }

    /**
     * SCENARIO: alice claims all the rewards from a sponsorManager distribution and
     * incentivized gauge in coinbase
     */
    function test_ClaimSponsorRewardsWithIncentivizerInCoinbase() public {
        // GIVEN builder and builder2 and kickback percentage of 50%
        //  AND a sponsor alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether reward in coinbase are added
        sponsorsManager.notifyRewardAmount{ value: 100 ether }(0 ether);
        // AND 100 ether in coinbase are added directly to first gauge by incentivizer
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);
        gauge.notifyRewardAmount{ value: 100 ether }(UtilsLib._COINBASE_ADDRESS, 100 ether);
        vm.stopPrank();

        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        sponsorsManager.startDistribution();

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice balance is 50% of the distributed amount from the sponsorsManager
        // and 100% of the rewards incentivized directly to the first gauge
        // 149.999999999999999990 = 100 ether * 0.5 + 100 ether
        assertEq(address(alice).balance, 149_999_999_999_999_999_990);
    }

    /**
     * SCENARIO: after a distribution, in the middle of the epoch, gauge loses all allocations.
     *  One distribution later, alice allocates there again in the next epoch and earn the old remaining rewards
     */
    function test_GaugeLosesAllocationForOneEpoch() public {
        // GIVEN alice allocates to gauge and gauge2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to gauge2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN alice removes allocations from gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND alice adds allocations again
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.startPrank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is:
        //  epoch 1 = 21.875 = 3.125 + 18.75 = (100 * 2 / 16) * 0.5 * 0.5 WEEKS + (100 * 6 / 16) * 0.5
        //  epoch 2 = 23.33 = 3.333 + 20 = (100 * 1 / 15) * 0.5 + (100 * 6 / 15) * 0.5
        //  epoch 3 = 3.125 + 25 = 3.125(missingRewards) + (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(alice), 73_333_333_333_333_333_314);
        // THEN alice coinbase balance is:
        //  epoch 1 = 2.1875 = 0.3125 + 1.875 = (10 * 2 / 16) * 0.5 * 0.5 WEEKS + (10 * 6 / 16) * 0.5
        //  epoch 2 = 2.333 = 0.3333 + 2 = (10 * 1 / 15) * 0.5 + (10 * 6 / 15) * 0.5
        //  epoch 3 = 0.3125 + 2.5 = 0.3125(missingRewards) + (10 * 8 / 16) * 0.5
        assertEq(alice.balance, 7_333_333_333_333_333_314);

        // WHEN bob claim rewards
        vm.startPrank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is:
        //  epoch 1 = 25 = (100 * 8 / 16) * 0.5
        //  epoch 2 = 26.66 = (100 * 8 / 15) * 0.5
        //  epoch 3 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(bob), 76_666_666_666_666_666_648);
        // THEN bob coinbase balance is:
        //  epoch 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  epoch 2 = 2.66 = (10 * 8 / 15) * 0.5
        //  epoch 3 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(bob.balance, 7_666_666_666_666_666_648);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is:
        //  epoch 1 = 6.25 = (100 * 2 / 16) * 0.5
        //  epoch 2 = 3.333 = (100 * 1 / 15) * 0.5
        //  epoch 3 = 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 15_833_333_333_333_333_333);
        // THEN builder coinbase balance is:
        //  epoch 1 = 0.625 = (10 * 2 / 16) * 0.5
        //  epoch 2 = 0.3333 = (10 * 1 / 15) * 0.5
        //  epoch 3 = 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 1_583_333_333_333_333_333);

        // THEN builder2Receiver rewardToken balance is:
        //  epoch 1 = 43.75 = (100 * 14 / 16) * 0.5
        //  epoch 2 = 46.66 = (100 * 14 / 15) * 0.5
        //  epoch 3 = 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 134_166_666_666_666_666_667);
        // THEN builder2Receiver coinbase balance is:
        //  epoch 1 = 4.375 = (10 * 14 / 16) * 0.5
        //  epoch 2 = 4.66 = (10 * 14 / 15) * 0.5
        //  epoch 3 = 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 13_416_666_666_666_666_667);

        // THEN gauge rewardToken balance is 0, there is no remaining rewards
        assertApproxEqAbs(rewardToken.balanceOf(address(gauge)), 0, 100);
        // THEN gauge coinbase balance is 0, there is no remaining rewards
        assertApproxEqAbs(address(gauge).balance, 0, 100);
    }

    /**
     * SCENARIO: after a distribution, in the middle of the epoch, gauge loses all allocations.
     *  One distribution later, alice allocates there again in 2 epochs later and earn the old remaining rewards
     */
    function test_GaugeLosesAllocationForTwoEpochs() public {
        // GIVEN alice allocates to gauge and gauge2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to gauge2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);

        // WHEN alice removes allocations from gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND alice adds allocations again
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.startPrank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is:
        //  epoch 1 = 21.875 = 3.125 + 18.75 = (100 * 2 / 16) * 0.5 * 0.5 WEEKS + (100 * 6 / 16) * 0.5
        //  epoch 2 = 20 = (100 * 6 / 15) * 0.5
        //  epoch 3 = 6.455 + 21.42  = (3.33 + 3.125)(missingRewards) + (100 * 6 / 14) * 0.5
        //  epoch 4 = 6.25 + 18.75 = (100 * 2 / 16) * 0.5 + (100 * 6 / 16) * 0.5
        assertEq(rewardToken.balanceOf(alice), 94_761_904_761_904_761_882);
        // THEN alice coinbase balance is:
        //  epoch 1 = 2.1875 = 0.3125 + 1.875 = (10 * 2 / 16) * 0.5 * 0.5 WEEKS + (10 * 6 / 16) * 0.5
        //  epoch 2 = 2 = (10 * 6 / 15) * 0.5
        //  epoch 3 = 0.645 + 2.142  = (0.33 + 0.3125)(missingRewards) + (10 * 6 / 14) * 0.5
        //  epoch 4 = 0.625 + 1.875 = (10 * 2 / 16) * 0.5 + (10 * 6 / 16) * 0.5
        assertEq(alice.balance, 9_476_190_476_190_476_166);

        // WHEN bob claim rewards
        vm.startPrank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN bob rewardToken balance is:
        //  epoch 1 = 25 = (100 * 8 / 16) * 0.5
        //  epoch 2 = 26.66 = (100 * 8 / 15) * 0.5
        //  epoch 3 = 28.57 = (100 * 8 / 14) * 0.5
        //  epoch 4 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(bob), 105_238_095_238_095_238_072);
        // THEN bob coinbase balance is:
        //  epoch 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  epoch 2 = 2.66 = (10 * 8 / 15) * 0.5
        //  epoch 3 = 2.857 = (10 * 8 / 14) * 0.5
        //  epoch 4 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(bob.balance, 10_523_809_523_809_523_784);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is:
        //  epoch 1 = 6.25 = (100 * 2 / 16) * 0.5
        //  epoch 2 = 3.333 = (100 * 1 / 15) * 0.5
        //  epoch 3 = 0
        //  epoch 4 = 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 15_833_333_333_333_333_333);
        // THEN builder coinbase balance is:
        //  epoch 1 = 0.625 = (10 * 2 / 16) * 0.5
        //  epoch 2 = 0.3333 = (10 * 1 / 15) * 0.5
        //  epoch 3 = 0
        //  epoch 4 = 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 1_583_333_333_333_333_333);

        // THEN builder2Receiver rewardToken balance is:
        //  epoch 1 = 43.75 = (100 * 14 / 16) * 0.5
        //  epoch 2 = 46.66 = (100 * 14 / 15) * 0.5
        //  epoch 3 = 50 = (100 * 14 / 14) * 0.5
        //  epoch 4 = 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 184_166_666_666_666_666_667);
        // THEN builder2Receiver coinbase balance is:
        //  epoch 1 = 4.375 = (10 * 14 / 16) * 0.5
        //  epoch 2 = 4.66 = (10 * 14 / 15) * 0.5
        //  epoch 3 = 5 = (10 * 14 / 14) * 0.5
        //  epoch 4 = 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 18_416_666_666_666_666_667);

        // THEN gauge rewardToken balance is 0, there is no remaining rewards
        assertApproxEqAbs(rewardToken.balanceOf(address(gauge)), 0, 100);
        // THEN gauge coinbase balance is 0, there is no remaining rewards
        assertApproxEqAbs(address(gauge).balance, 0, 100);
    }

    /**
     * SCENARIO: after a distribution, alice deallocates and allocates twice on the same epoch
     *  Missing rewards are accumulated
     */
    function test_MissingRewardsAccumulation() public {
        // GIVEN alice allocates to gauge and gauge2
        _skipAndStartNewEpoch();
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to gauge2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN rewardToken's rewardRate is 0.0000103 = (50 * 2 / 16) / 604800
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 10_333_994_708_994);
        // THEN coinbase's rewardRate is 0.00000103 = (5 * 2 / 16) / 604800
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 1_033_399_470_899);

        // AND 1 day pass
        skip(1 days);
        // AND alice removes allocations from gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);
        // AND 1 day pass
        skip(1 days);
        // AND alice adds allocations from gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // THEN rewardToken's rewardMissing is 0.89 = 0.0000103 * 1 day
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 892_857_142_857_142_857);
        // THEN coinbase's rewardMissing is 0.089 = 0.00000103 * 1 day
        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 89_285_714_285_714_285);

        // AND 1 day pass
        skip(1 days);
        // AND alice removes allocations from gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0);
        // AND 1 day pass
        skip(1 days);
        // AND alice adds allocations from gauge
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);

        // THEN rewardToken's rewardMissing is 1.78 = 0.0000103 * 2 days
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 1_785_714_285_714_285_714);
        // THEN coinbase's rewardMissing is 0.178 = 0.00000103 * 2 days
        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 178_571_428_571_428_571);
    }

    /**
     * SCENARIO: SponsorsManager is initialized with an offset of 7 weeks. First distribution starts
     *  8 weeks after the deploy
     */
    function test_InitializedWithAnEpochStartOffset() public {
        // GIVEN a SponsorsManager contract initialized with 7 weeks of offset

        // all the tests are running with the SponsorsManager already initialized with epochStartOffset = 0
        // to simplify the calcs. since, we cannot change that value after the initialization we need this function
        // to test the scenario where the contract is initialized with a different value
        uint24 _newOffset = 7 weeks;

        stdstore.target(address(sponsorsManager)).sig("epochData()").depth(4).enable_packed_slots().checked_write(
            _newOffset
        );

        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart, uint24 _offset) =
            sponsorsManager.epochData();

        // THEN previous epoch duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next epoch duration is 1 week
        assertEq(_nextDuration, 1 weeks);
        // THEN previous epoch start is now
        assertEq(_previousStart, block.timestamp);
        // THEN previous epoch start is now
        assertEq(_nextStart, block.timestamp);
        // THEN epoch start offset is 7 weeks
        assertEq(_offset, 7 weeks);

        // THEN epoch starts now
        assertEq(sponsorsManager.epochStart(block.timestamp), block.timestamp);
        // THEN epoch ends in 8 weeks from now (1 weeks duration + 7 weeks offset)
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 8 weeks);

        // AND alice allocates 2 ether to builder and 6 ether to builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        uint256 _timestampBefore = block.timestamp;
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN epoch was of 8 weeks
        assertEq(block.timestamp - _timestampBefore, 8 weeks);
        _timestampBefore = block.timestamp;
        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN epoch was of 1 weeks
        assertEq(block.timestamp - _timestampBefore, 1 weeks);

        // THEN epoch starts now
        assertEq(sponsorsManager.epochStart(block.timestamp), block.timestamp);
        // THEN epoch ends in 1 weeks
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1 weeks);

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 50% of the distributed amount
        assertApproxEqAbs(rewardToken.balanceOf(alice), 50 ether, 100);
        // THEN alice coinbase balance is 50% of the distributed amount
        assertApproxEqAbs(alice.balance, 5 ether, 100);
    }

    /**
     * SCENARIO: SponsorsManager is initialized with an offset of 7 weeks.
     *  There is a notifyReward amount to incentive the gauge before the distribution
     */
    function test_IncentivizeWithEpochStartOffset() public {
        // GIVEN a SponsorsManager contract initialized with 7 weeks of offset

        // all the tests are running with the SponsorsManager already initialized with epochStartOffset = 0
        // to simplify the calcs. since, we cannot change that value after the initialization we need this function
        // to test the scenario where the contract is initialized with a different value
        uint24 _newOffset = 7 weeks;

        stdstore.target(address(sponsorsManager)).sig("epochData()").depth(4).enable_packed_slots().checked_write(
            _newOffset
        );

        // periodFinish is initialized using the epochStartOffset = 0 on initialization, we need to calculate it again
        // with the newEpochStartOffset = 7 weeks
        stdstore.target(address(sponsorsManager)).sig("periodFinish()").checked_write(
            sponsorsManager.epochNext(block.timestamp)
        );

        // AND gauge is incentive with 100 ether of rewardToken
        rewardToken.approve(address(gauge), 100 ether);
        gauge.notifyRewardAmount(address(rewardToken), 100 ether);

        // AND alice allocates 2 ether to builder
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 2 ether);
        vm.stopPrank();

        uint256 _timestampBefore = block.timestamp;
        // AND epoch finishes
        _distribute(0, 0);
        // THEN epoch was of 8 weeks
        assertEq(block.timestamp - _timestampBefore, 8 weeks);

        // THEN epoch starts now
        assertEq(sponsorsManager.epochStart(block.timestamp), block.timestamp);
        // THEN epoch ends in 1 weeks
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1 weeks);

        // WHEN alice claim rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);

        // THEN alice rewardToken balance is 100% of the distributed amount
        assertApproxEqAbs(rewardToken.balanceOf(alice), 100 ether, 100);
    }

    /**
     * SCENARIO: After deployment SponsorsManager starts in a distribution window
     */
    function test_DeployStartsInDistributionWindow() public {
        // GIVEN a SponsorsManager contract initialized with 3 days of offset

        // all the tests are running with the SponsorsManager already initialized with epochStartOffset = 0
        // to simplify the calcs. since, we cannot change that value after the initialization we need this function
        // to test the scenario where the contract is initialized with a different value
        uint24 _newOffset = 3 days;

        stdstore.target(address(sponsorsManager)).sig("epochData()").depth(4).enable_packed_slots().checked_write(
            _newOffset
        );

        // AND alice allocates 2 ether to builder and 6 ether to builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND distribution starts
        sponsorsManager.startDistribution();
        // THEN distribution finished
        assertEq(sponsorsManager.onDistributionPeriod(), false);

        uint256 _deployTimestamp = block.timestamp;
        // AND distribution windows finishes
        vm.warp(_deployTimestamp + 1 hours + 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(SponsorsManager.OnlyInDistributionWindow.selector);
        sponsorsManager.startDistribution();

        // AND offset finishes
        vm.warp(_deployTimestamp + _newOffset + 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(SponsorsManager.OnlyInDistributionWindow.selector);
        sponsorsManager.startDistribution();

        // AND epoch duration finishes
        vm.warp(_deployTimestamp + epochDuration + 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(SponsorsManager.OnlyInDistributionWindow.selector);
        sponsorsManager.startDistribution();

        // AND epoch duration + offset is close to finish
        vm.warp(_deployTimestamp + epochDuration + _newOffset - 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(SponsorsManager.OnlyInDistributionWindow.selector);
        sponsorsManager.startDistribution();

        // AND epoch duration + offset finishes
        vm.warp(_deployTimestamp + epochDuration + _newOffset);
        // AND distribution starts
        sponsorsManager.startDistribution();
        // THEN distribution finished
        assertEq(sponsorsManager.onDistributionPeriod(), false);
    }

    /**
     * SCENARIO: startDistribution reverts if there are no allocations
     */
    function test_RevertsStartDistributionWithoutAllocations() public {
        // GIVEN a SponsorsManager without allocations
        //  WHEN startDistribution is called
        // THEN reverts calling startDistribution because cannot calculate shares, totalAllocation is 0
        vm.expectRevert(stdError.divisionError);
        sponsorsManager.startDistribution();
    }
}
