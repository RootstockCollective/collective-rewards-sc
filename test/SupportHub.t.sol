// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdError } from "forge-std/src/Test.sol";
import { BaseTest, SupportHub, BuilderGauge } from "./BaseTest.sol";
import { EpochLib } from "../src/libraries/EpochLib.sol";

contract SupportHubTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderGaugeCreated(address indexed builder_, address indexed builderGauge_, address creator_);
    event NewAllocation(address indexed supporter_, address indexed builderGauge_, uint256 allocation_);
    event NotifyReward(address indexed sender_, uint256 amount_);
    event DistributeReward(address indexed sender_, address indexed builderGauge_, uint256 amount_);

    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(supportHub), 100_000 ether);
    }

    /**
     * SCENARIO: createBuilderGauge should revert if it is called twice for the same builder
     */
    function test_RevertGaugeExists() public {
        // GIVEN a SponsorManager contract and a builderGauge deployed for builder
        //  WHEN tries to deployed a builderGauge again
        //   THEN tx reverts because builderGauge already exists
        vm.expectRevert(SupportHub.BuilderGaugeExists.selector);
        supportHub.createBuilderGauge(builder);
    }

    /**
     * SCENARIO: createBuilderGauge is called for a new builder
     * BuilderGaugeCreated event is emitted and new builderGauges added to the list
     */
    function test_CreateGauge() public {
        address newBuilder = makeAddr("newBuilder");
        // GIVEN a SponsorManager contract
        //  WHEN a builderGauge is deployed for a new builder
        //   THEN a BuilderGaugeCreated event is emitted
        vm.expectEmit(true, false, true, true); // ignore new builderGauge address
        emit BuilderGaugeCreated(newBuilder, /*ignored*/ address(0), address(this));
        BuilderGauge newBuilderGauge = supportHub.createBuilderGauge(newBuilder);
        //   THEN new builderGauge is assigned to the new builder
        assertEq(address(supportHub.builderToGauge(newBuilder)), address(newBuilderGauge));
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
        vm.expectRevert(SupportHub.UnequalLengths.selector);
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
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
        emit NewAllocation(alice, address(builderGaugesArray[0]), 2 ether);
        vm.expectEmit();
        emit NewAllocation(alice, address(builderGaugesArray[1]), 6 ether);
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // THEN total allocation is 22 ether
        assertEq(supportHub.totalAllocation(), 22 ether);
        // THEN alice total allocation is 8 ether
        assertEq(supportHub.supporterTotalAllocation(alice), 8 ether);
        // THEN bob total allocation is 14 ether
        assertEq(supportHub.supporterTotalAllocation(bob), 14 ether);
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
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        // THEN total allocation is 8 ether
        assertEq(supportHub.totalAllocation(), 8 ether);
        // THEN alice total allocation is 8 ether
        assertEq(supportHub.supporterTotalAllocation(alice), 8 ether);

        // WHEN alice modifies the allocation: 10 ether to builder and 0 ether to builder2
        allocationsArray[0] = 10 ether;
        allocationsArray[1] = 0 ether;
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // THEN total allocation is 10 ether
        assertEq(supportHub.totalAllocation(), 10 ether);
        // THEN alice total allocation is 10 ether
        assertEq(supportHub.supporterTotalAllocation(alice), 10 ether);
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
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // WHEN alice modifies the allocation: trying to add 1 ether more
        allocationsArray[0] = 100_001 ether;
        allocationsArray[1] = 0 ether;
        // THEN tx reverts because NotEnoughStaking
        vm.expectRevert(SupportHub.NotEnoughStaking.selector);
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
    }

    /**
     * SCENARIO: notifyRewardAmount is called without any allocation
     */
    function test_NotifyRewardAmountWithoutAllocation() public {
        // GIVEN a SponsorManager contract
        //  WHEN notifyRewardAmount is called without allocations
        //   THEN tx reverts because division by zero
        vm.expectRevert(stdError.divisionError);
        supportHub.notifyRewardAmount(2 ether);
    }

    /**
     * SCENARIO: notifyRewardAmount is called and values are updated
     */
    function test_NotifyRewardAmount() public {
        // GIVEN a SponsorManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        supportHub.allocate(builderGauge, 0.1 ether);
        //   WHEN 2 ether reward are added
        //    THEN NotifyReward event is emitted
        vm.expectEmit();
        emit NotifyReward(address(this), 2 ether);
        supportHub.notifyRewardAmount(2 ether);
        // THEN rewardsPerShare is 20 = 2 / 0.1 ether
        assertEq(supportHub.rewardsPerShare(), 20 ether);
        // THEN reward token balance of supportHub is 2 ether
        assertEq(rewardToken.balanceOf(address(supportHub)), 2 ether);
    }

    /**
     * SCENARIO: notifyRewardAmount is called twice before distribution and values are updated
     */
    function test_NotifyRewardAmountTwice() public {
        // GIVEN a SponsorManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        supportHub.allocate(builderGauge, 0.1 ether);
        // AND 2 ether reward are added
        supportHub.notifyRewardAmount(2 ether);
        // WHEN 10 ether reward are more added
        supportHub.notifyRewardAmount(10 ether);
        // THEN rewardsPerShare is 120 = 12 / 0.1 ether
        assertEq(supportHub.rewardsPerShare(), 120 ether);
        // THEN reward token balance of supportHub is 12 ether
        assertEq(rewardToken.balanceOf(address(supportHub)), 12 ether);
    }

    /**
     * SCENARIO: should revert is distribution period started
     */
    function test_RevertNotInDistributionPeriod() public {
        // GIVEN a SponsorManager contract
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 builderGauges created
        for (uint256 i = 0; i < 20; i++) {
            BuilderGauge _newGauge = supportHub.createBuilderGauge(makeAddr(string(abi.encode(i + 10))));
            builderGaugesArray.push(_newGauge);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        //  AND 2 ether reward are added
        supportHub.notifyRewardAmount(2 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        //  AND distribution start
        supportHub.startDistribution();

        // WHEN tries to allocate during the distribution period
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(SupportHub.NotInDistributionPeriod.selector);
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        // WHEN tries to add more reward
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(SupportHub.NotInDistributionPeriod.selector);
        supportHub.notifyRewardAmount(2 ether);
        // WHEN tries to start distribution again
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(SupportHub.NotInDistributionPeriod.selector);
        supportHub.startDistribution();
    }

    /**
     * SCENARIO: should revert is distribution window did not start
     */
    function test_RevertOnlyInDistributionWindow() public {
        // GIVEN a SponsorManager contract
        // WHEN someone tries to distribute after the distribution window start
        _skipToEndDistributionWindow();
        //  THEN tx reverts because OnlyInDistributionWindow
        vm.expectRevert(SupportHub.OnlyInDistributionWindow.selector);
        supportHub.startDistribution();
    }

    /**
     * SCENARIO: should revert is distribution period did not start
     */
    function test_RevertDistributionPeriodDidNotStart() public {
        // GIVEN a SponsorManager contract
        // WHEN someone tries to distribute before the distribution period start
        //  THEN tx reverts because DistributionPeriodDidNotStart
        vm.expectRevert(SupportHub.DistributionPeriodDidNotStart.selector);
        supportHub.distribute();
    }

    /**
     * SCENARIO: alice and bob allocates to 2 builderGauges and distribute rewards to them
     */
    function test_Distribute() public {
        // GIVEN a SponsorManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added
        supportHub.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        //  WHEN distribute is executed
        //   THEN DistributeReward event is emitted for builderGauge
        vm.expectEmit();
        emit DistributeReward(address(this), address(builderGauge), 27_272_727_272_727_272_724);
        //   THEN DistributeReward event is emitted for builderGauge2
        vm.expectEmit();
        emit DistributeReward(address(this), address(builderGauge2), 72_727_272_727_272_727_264);
        supportHub.startDistribution();
        // THEN reward token balance of builderGauge is 27.272727272727272724 = 100 * 6 / 22
        assertEq(rewardToken.balanceOf(address(builderGauge)), 27_272_727_272_727_272_724);
        // THEN reward token balance of builderGauge2 is 72.727272727272727264 = 100 * 16 / 22
        assertEq(rewardToken.balanceOf(address(builderGauge2)), 72_727_272_727_272_727_264);
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
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added and distributed
        supportHub.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        supportHub.startDistribution();

        // AND bob modifies his allocations 16 ether to builder and 4 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 16 ether;
        allocationsArray[1] = 4 ether;
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        vm.stopPrank();

        //  WHEN 100 ether reward are added and distributed again
        supportHub.notifyRewardAmount(100 ether);
        supportHub.startDistribution();

        // THEN reward token balance of builderGauge is 91.558441558441558428 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(builderGauge)), 91_558_441_558_441_558_428);
        // THEN reward token balance of builderGauge2 is 108.441558441558441544 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(builderGauge2)), 108_441_558_441_558_441_544);
    }

    /**
     * SCENARIO: distribute on 2 consecutive epoch with different allocations
     */
    function test_DistributeTwice() public {
        // GIVEN a supporter alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added and distributed
        supportHub.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        supportHub.startDistribution();
        // AND epoch finish
        _skipAndStartNewEpoch();

        // AND bob modifies his allocations 16 ether to builder and 4 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 16 ether;
        allocationsArray[1] = 4 ether;
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        vm.stopPrank();

        //  WHEN 100 ether reward are added and distributed again
        supportHub.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        supportHub.startDistribution();

        // THEN reward token balance of builderGauge is 91.558441558441558428 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(builderGauge)), 91_558_441_558_441_558_428);
        // THEN reward token balance of builderGauge2 is 108.441558441558441544 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(builderGauge2)), 108_441_558_441_558_441_544);
    }

    /**
     * SCENARIO: distribution occurs on different transactions using pagination
     */
    function test_DistributeUsingPagination() public {
        // GIVEN a supporter alice
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 builderGauges created
        for (uint256 i = 0; i < 20; i++) {
            BuilderGauge _newGauge = supportHub.createBuilderGauge(makeAddr(string(abi.encode(i + 10))));
            builderGaugesArray.push(_newGauge);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);

        // AND 100 ether reward are added
        supportHub.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // WHEN distribute is executed
        supportHub.startDistribution();
        // THEN distribution period is still started
        assertEq(supportHub.onDistributionPeriod(), true);
        // THEN last builderGauge distributed is builderGauge 20
        assertEq(supportHub.indexLastGaugeDistributed(), 20);

        // AND distribute is executed again
        supportHub.distribute();
        // THEN distribution period finished
        assertEq(supportHub.onDistributionPeriod(), false);
        // THEN last builderGauge distributed is 0
        assertEq(supportHub.indexLastGaugeDistributed(), 0);

        for (uint256 i = 0; i < 22; i++) {
            // THEN reward token balance of all the builderGauges is 4.545454545454545454 = 100 * 1 / 22
            assertEq(rewardToken.balanceOf(address(builderGaugesArray[i])), 4_545_454_545_454_545_454);
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

        // GIVEN a supporter alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        supportHub.allocateBatch(builderGaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether reward are added
        supportHub.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        supportHub.startDistribution();

        // AND epoch finish
        _skipAndStartNewEpoch();

        // WHEN alice claim rewards
        vm.prank(alice);
        supportHub.claimSponsorRewards(builderGaugesArray);

        // THEN alice rewardToken balance is all of the distributed amount
        assertEq(rewardToken.balanceOf(alice), 99_999_999_999_999_999_992);
    }
}
