// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, SponsorsManager, Gauge } from "./BaseTest.sol";

contract SponsorsManagerTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewAllocation(address indexed sponsor_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed sender_, uint256 amount_);
    event RewardDistributionStarted(address indexed sender_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);

    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(sponsorsManager), 100_000 ether);
    }

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
     * SCENARIO: notifyRewardAmount is called and values are updated
     */
    function test_NotifyRewardAmount() public {
        // GIVEN a SponsorManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0.1 ether);
        //   WHEN 2 ether reward are added
        //    THEN NotifyReward event is emitted
        vm.expectEmit();
        emit NotifyReward(address(this), 2 ether);
        sponsorsManager.notifyRewardAmount(2 ether);
        // THEN rewards is 2 ether
        assertEq(sponsorsManager.rewards(), 2 ether);
        // THEN reward token balance of sponsorsManager is 2 ether
        assertEq(rewardToken.balanceOf(address(sponsorsManager)), 2 ether);
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
        // THEN rewardsPerShare is 12 ether
        assertEq(sponsorsManager.rewards(), 12 ether);
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
}
