// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdError } from "forge-std/src/Test.sol";
import { BaseTest, SponsorsManager, Gauge } from "./BaseTest.sol";
import { EpochLib } from "../src/libraries/EpochLib.sol";

contract SponsorsManagerTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
    event NewAllocation(address indexed sponsor_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed sender_, uint256 amount_);
    event DistributeReward(address indexed sender_, address indexed gauge_, uint256 amount_);

    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(sponsorsManager), 100_000 ether);
    }

    /**
     * SCENARIO: createGauge should revert if it is called twice for the same builder
     */
    function test_RevertGaugeExists() public {
        // GIVEN a SponsorManager contract and a gauge deployed for builder
        //  WHEN tries to deployed a gauge again
        //   THEN tx reverts because gauge already exists
        vm.expectRevert(SponsorsManager.GaugeExists.selector);
        sponsorsManager.createGauge(builder);
    }

    /**
     * SCENARIO: createGauge is called for a new builder
     * GaugeCreated event is emitted and new gauges added to the list
     */
    function test_CreateGauge() public {
        address newBuilder = makeAddr("newBuilder");
        // GIVEN a SponsorManager contract
        //  WHEN a gauge is deployed for a new builder
        //   THEN a GaugeCreated event is emitted
        vm.expectEmit(true, false, true, true); // ignore new gauge address
        emit GaugeCreated(newBuilder, /*ignored*/ address(0), address(this));
        Gauge newGauge = sponsorsManager.createGauge(newBuilder);
        //   THEN new gauge is assigned to the new builder
        assertEq(address(sponsorsManager.builderToGauge(newBuilder)), address(newGauge));
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

        // THEN total allocation is 22 ether
        assertEq(sponsorsManager.totalAllocation(), 22 ether);
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
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // WHEN alice allocates 2 ether to builder and 6 ether to builder2
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        // THEN total allocation is 8 ether
        assertEq(sponsorsManager.totalAllocation(), 8 ether);
        // THEN alice total allocation is 8 ether
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 8 ether);

        // WHEN alice modifies the allocation: 10 ether to builder and 0 ether to builder2
        allocationsArray[0] = 10 ether;
        allocationsArray[1] = 0 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN total allocation is 10 ether
        assertEq(sponsorsManager.totalAllocation(), 10 ether);
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
     * SCENARIO: notifyRewardAmount is called without any allocation
     */
    function test_NotifyRewardAmountWithoutAllocation() public {
        // GIVEN a SponsorManager contract
        //  WHEN notifyRewardAmount is called without allocations
        //   THEN tx reverts because division by zero
        vm.expectRevert(stdError.divisionError);
        sponsorsManager.notifyRewardAmount(2 ether);
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
        // THEN rewardsPerShare is 20 = 2 / 0.1 ether
        assertEq(sponsorsManager.rewardsPerShare(), 20 ether);
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
        // THEN rewardsPerShare is 120 = 12 / 0.1 ether
        assertEq(sponsorsManager.rewardsPerShare(), 120 ether);
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
            Gauge _newGauge = sponsorsManager.createGauge(makeAddr(string(abi.encode(i + 10))));
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
        //   THEN DistributeReward event is emitted for gauge
        vm.expectEmit();
        emit DistributeReward(address(this), address(gauge), 27_272_727_272_727_272_724);
        //   THEN DistributeReward event is emitted for gauge2
        vm.expectEmit();
        emit DistributeReward(address(this), address(gauge2), 72_727_272_727_272_727_264);
        sponsorsManager.startDistribution();
        // THEN reward token balance of gauge is 27.272727272727272724 = 100 * 6 / 22
        assertEq(rewardToken.balanceOf(address(gauge)), 27_272_727_272_727_272_724);
        // THEN reward token balance of gauge2 is 72.727272727272727264 = 100 * 16 / 22
        assertEq(rewardToken.balanceOf(address(gauge2)), 72_727_272_727_272_727_264);
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

        // THEN reward token balance of gauge is 91.558441558441558428 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(gauge)), 91_558_441_558_441_558_428);
        // THEN reward token balance of gauge2 is 108.441558441558441544 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(gauge2)), 108_441_558_441_558_441_544);
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

        // THEN reward token balance of gauge is 91.558441558441558428 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(gauge)), 91_558_441_558_441_558_428);
        // THEN reward token balance of gauge2 is 108.441558441558441544 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(gauge2)), 108_441_558_441_558_441_544);
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
            Gauge _newGauge = sponsorsManager.createGauge(makeAddr(string(abi.encode(i + 10))));
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
        // THEN distribution period is still started
        assertEq(sponsorsManager.onDistributionPeriod(), true);
        // THEN last gauge distributed is gauge 20
        assertEq(sponsorsManager.indexLastGaugeDistributed(), 20);

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
     * SCENARIO: alice claims all the rewards in a single tx
     */
    function test_ClaimSponsorRewards() public {
        // GIVEN builder kickback percentage is 100%
        vm.startPrank(kycApprover);
        builderRegistry.activateBuilder(builder, builder, 1 ether);
        builderRegistry.activateBuilder(builder2, builder2, 1 ether);

        // GIVEN a sponsor alice
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

        // THEN alice rewardToken balance is all of the distributed amount
        assertEq(rewardToken.balanceOf(alice), 99_999_999_999_999_999_992);
    }
}
