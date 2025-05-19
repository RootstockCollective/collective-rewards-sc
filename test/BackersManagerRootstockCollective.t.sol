// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { stdStorage, StdStorage } from "forge-std/src/Test.sol";
import { BaseTest, BackersManagerRootstockCollective, GaugeRootstockCollective } from "./BaseTest.sol";
import { IGovernanceManagerRootstockCollective } from "../src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract BackersManagerRootstockCollectiveTest is BaseTest {
    using stdStorage for StdStorage;
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event RewardDistributionStarted(address indexed sender_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);
    event MaxDistributionsPerBatchUpdated(uint256 oldMaxDistributionsPerBatch_, uint256 newMaxDistributionsPerBatch_);

    /**
     * SCENARIO: allocate should revert if it is called with arrays with different lengths
     */
    function test_RevertAllocateBatchUnequalLengths() public {
        // GIVEN a BackerManager contract
        //  WHEN alice calls allocateBatch with wrong array lengths
        vm.startPrank(alice);
        allocationsArray.push(0);
        //   THEN tx reverts because UnequalLengths
        vm.expectRevert(BackersManagerRootstockCollective.UnequalLengths.selector);
        backersManager.allocateBatch(gaugesArray, allocationsArray);
    }

    /**
     * SCENARIO: should revert if gauge does not exist
     */
    function test_RevertGaugeDoesNotExist() public {
        // GIVEN a BackerManager contract
        // AND a new gauge created by the factor
        GaugeRootstockCollective _wrongGauge = gaugeFactory.createGauge();
        gaugesArray.push(_wrongGauge);
        allocationsArray.push(100 ether);
        //  WHEN alice calls allocate using the wrong gauge
        //   THEN tx reverts because GaugeDoesNotExist
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.GaugeDoesNotExist.selector);
        backersManager.allocate(_wrongGauge, 100 ether);
        //  WHEN alice calls allocateBatch using the wrong gauge
        //   THEN tx reverts because GaugeDoesNotExist
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.GaugeDoesNotExist.selector);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        //  WHEN alice calls claimBackerRewards using the wrong gauge
        //   THEN tx reverts because GaugeDoesNotExist
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.GaugeDoesNotExist.selector);
        backersManager.claimBackerRewards(gaugesArray);

        //  WHEN alice calls claimBackerRewards using the wrong gauge
        //   THEN tx reverts because GaugeDoesNotExist
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.GaugeDoesNotExist.selector);
        backersManager.claimBackerRewards(address(rewardToken), gaugesArray);

        //  WHEN alice calls claimBackerRewards using the wrong gauge
        //   THEN tx reverts because GaugeDoesNotExist
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.GaugeDoesNotExist.selector);
        backersManager.claimBackerRewards(UtilsLib._COINBASE_ADDRESS, gaugesArray);
    }

    /**
     * SCENARIO: should revert if gauge is community approved but not initialized
     */
    function test_RevertGaugeIsCommunityApprovedButNotInitialized() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = builderRegistry.communityApproveBuilder(_newBuilder);

        gaugesArray.push(_newGauge);
        allocationsArray.push(100 ether);
        //  WHEN alice calls allocate using the new gauge
        //   THEN tx reverts because BuilderNotInitialized
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotInitialized.selector);
        backersManager.allocate(_newGauge, 100 ether);
        //  WHEN alice calls allocateBatch using the new gauge
        //   THEN tx reverts because BuilderNotInitialized
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotInitialized.selector);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        //  WHEN alice calls claimBackerRewards using the new gauge
        //   THEN tx reverts because BuilderNotInitialized
        vm.prank(alice);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotInitialized.selector);
        backersManager.claimBackerRewards(gaugesArray);
    }

    /**
     * SCENARIO: should revert if the reward token approval returns false
     * @dev during the initial setup, the contract was already approved for a spending allowance greater than zero,
     * and the mock reward token implements approve() logic which forces users to negate the allowance before approving
     * a new quantity of allowance
     * The function will revert if called before negating the previous allowance
     */
    function test_RevertRewardTokenApprove() public {
        // Should not revert, as the allowance is negated before approving a new amount
        vm.startPrank(address(builderRegistry));
        backersManager.rewardTokenApprove(address(gauge), 0);
        backersManager.rewardTokenApprove(address(gauge), type(uint256).max);

        // Should revert, as the allowance is not negated before approving a new amount
        vm.expectRevert(BackersManagerRootstockCollective.RewardTokenNotApproved.selector);
        backersManager.rewardTokenApprove(address(gauge), type(uint256).max);
    }

    /**
     * SCENARIO: alice and bob allocate for 2 builders and variables are updated
     */
    function test_AllocateBatch() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND a new cycle
        _skipAndStartNewCycle();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // WHEN alice allocates 2 ether to builder and 6 ether to builder2
        //  THEN 2 NewAllocation events are emitted
        vm.expectEmit();
        emit NewAllocation(alice, address(gaugesArray[0]), 2 ether);
        vm.expectEmit();
        emit NewAllocation(alice, address(gaugesArray[1]), 6 ether);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN total potential rewards is 13305600 ether = 22 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 13_305_600 ether);
        // THEN alice total allocation is 8 ether
        assertEq(backersManager.backerTotalAllocation(alice), 8 ether);
        // THEN bob total allocation is 14 ether
        assertEq(backersManager.backerTotalAllocation(bob), 14 ether);
    }

    /**
     * SCENARIO: alice allocates on a batch passing the same gauge twice
     */
    function test_AllocateBatchGaugeRepeated() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND a new cycle
        _skipAndStartNewCycle();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;

        gaugesArray.push(gauge);
        allocationsArray.push(10 ether);
        // WHEN alice allocates to [gauge, gauge2, gauge] = [2, 6, 10]
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN is considered the last allocation
        //  alice gauge allocation is 10 ether
        assertEq(gauge.allocationOf(alice), 10 ether);
        // THEN alice gauge2 allocation is 6 ether
        assertEq(gauge2.allocationOf(alice), 6 ether);
        // THEN total potential rewards is 9676800 ether = 16 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 9_676_800 ether);
        // THEN alice total allocation is 16 ether
        assertEq(backersManager.backerTotalAllocation(alice), 16 ether);
    }

    /**
     * SCENARIO: alice override her allocaition
     */
    function test_AllocateOverride() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND a new cycle
        _skipAndStartNewCycle();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // WHEN alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND alice override gauge allocation from 2 ether to 10 ether
        backersManager.allocate(gauge, 10 ether);

        // THEN is considered the last allocation
        //  alice gauge allocation is 10 ether
        assertEq(gauge.allocationOf(alice), 10 ether);
        // THEN alice gauge2 allocation is 6 ether
        assertEq(gauge2.allocationOf(alice), 6 ether);
        // THEN total potential rewards is 9676800 ether = 16 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 9_676_800 ether);
        // THEN alice total allocation is 16 ether
        assertEq(backersManager.backerTotalAllocation(alice), 16 ether);
    }

    /**
     * SCENARIO: alice allocates on a batch to gauge and gauge2. After, allocates again
     *  adding allocation to gauge3. Previous allocation is not modified
     */
    function test_AllocateBatchOverride() public {
        // GIVEN a BackerManager contract
        // AND a new cycle
        _skipAndStartNewCycle();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;

        // WHEN alice allocates to [gauge, gauge2] = [2, 6]
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        address _builder3 = makeAddr("_builder3");
        GaugeRootstockCollective _gauge3 = _whitelistBuilder(_builder3, _builder3, 0.5 ether);
        allocationsArray.push(10 ether);

        // AND alice allocates again to [gauge, gauge2, gauge3] = [2, 6, 10]
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN previous allocation didn't change
        //  alice gauge allocation is 2 ether
        assertEq(gauge.allocationOf(alice), 2 ether);
        // THEN alice gauge2 allocation is 6 ether
        assertEq(gauge2.allocationOf(alice), 6 ether);
        // THEN alice gauge3 allocation is 6 ether
        assertEq(_gauge3.allocationOf(alice), 10 ether);
        // THEN total potential rewards is 10886400 ether = 18 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 10_886_400 ether);
        // THEN alice total allocation is 18 ether
        assertEq(backersManager.backerTotalAllocation(alice), 18 ether);
    }

    /**
     * SCENARIO: alice modifies allocation for 2 builders and variables are updated
     */
    function test_ModifyAllocation() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        // AND a new cycle
        _skipAndStartNewCycle();
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // WHEN alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        // THEN total allocation is 4838400 ether = 8 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 4_838_400 ether);
        // THEN alice total allocation is 8 ether
        assertEq(backersManager.backerTotalAllocation(alice), 8 ether);

        // WHEN half cycle pass
        _skipRemainingCycleFraction(2);
        // AND alice modifies the allocation: 10 ether to builder and 0 ether to builder2
        allocationsArray[0] = 10 ether;
        allocationsArray[1] = 0 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN total allocation is 5443200 ether = 8 * 1 WEEK + 2 * 1/2 WEEK
        assertEq(backersManager.totalPotentialReward(), 5_443_200 ether);
        // THEN alice total allocation is 10 ether
        assertEq(backersManager.backerTotalAllocation(alice), 10 ether);
    }

    /**
     * SCENARIO: allocate should revert when alice tries to allocate more than her staking token balance
     */
    function test_RevertNotEnoughStaking() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 99_000 ether;
        allocationsArray[1] = 1000 ether;
        // WHEN alice allocates all the staking to 2 builders
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // WHEN alice modifies the allocation: trying to add 1 ether more
        allocationsArray[0] = 100_001 ether;
        allocationsArray[1] = 0 ether;
        // THEN tx reverts because NotEnoughStaking
        vm.expectRevert(BackersManagerRootstockCollective.NotEnoughStaking.selector);
        backersManager.allocateBatch(gaugesArray, allocationsArray);
    }

    /**
     * SCENARIO: alice has all votes staked and wants to move some from one gauge to another using allocateBatch
     */
    function test_ReallocateVotes() public {
        // GIVEN alice has 100_000 ether in stakingToken
        assertEq(stakingToken.balanceOf(alice), 100_000 ether);
        // WHEN alice allocates all the staking to 2 builders
        allocationsArray[0] = 99_000 ether;
        allocationsArray[1] = 1000 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN allocations get updated
        assertEq(gauge.allocationOf(alice), 99_000 ether);
        assertEq(gauge2.allocationOf(alice), 1000 ether);

        // WHEN alice moves votes to first gauge in the array (removing votes from second gauge)
        allocationsArray[0] = 99_999 ether;
        allocationsArray[1] = 1 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN allocations get updated
        assertEq(gauge.allocationOf(alice), 99_999 ether);
        assertEq(gauge2.allocationOf(alice), 1 ether);

        // WHEN alice moves votes to second gauge in the array (removing votes from first gauge)
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 100_000 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN allocations get updated
        assertEq(gauge.allocationOf(alice), 0);
        assertEq(gauge2.allocationOf(alice), 100_000 ether);
    }

    /**
     * SCENARIO: alice has all votes staked and wants to move votes from a revoked gauge to another one using
     * allocateBatch
     */
    function test_ReallocateVotesFromRevokedBuilder() public {
        // GIVEN alice has 100_000 ether in stakingToken
        assertEq(stakingToken.balanceOf(alice), 100_000 ether);
        // WHEN alice allocates all the staking to 2 builders
        allocationsArray[0] = 99_000 ether;
        allocationsArray[1] = 1000 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND first builder pauses itself
        vm.prank(builder);
        builderRegistry.pauseSelf();

        // WHEN alice moves votes from revoked gauge to the other
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 100_000 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN allocations get updated
        assertEq(gauge.allocationOf(alice), 0);
        assertEq(gauge2.allocationOf(alice), 100_000 ether);
    }

    /**
     * SCENARIO: alice has all votes staked and wants to move votes from a KYC revoked gauge to another one using
     * allocateBatch
     */
    function test_ReallocateVotesFromKYCRevokedBuilder() public {
        // GIVEN alice has 100_000 ether in stakingToken
        assertEq(stakingToken.balanceOf(alice), 100_000 ether);
        // WHEN alice allocates all the staking to 2 builders
        allocationsArray[0] = 99_000 ether;
        allocationsArray[1] = 1000 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND first gauge builder gets KYC revoked
        vm.prank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // WHEN alice moves votes from KYC revoked gauge to the other
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 100_000 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // THEN allocations get updated
        assertEq(gauge.allocationOf(alice), 0);
        assertEq(gauge2.allocationOf(alice), 100_000 ether);
    }

    /**
     * SCENARIO: notifyRewardAmount is called using ERC20 and values are updated
     */
    function test_NotifyRewardAmountERC20() public {
        // GIVEN a BackerManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        //   WHEN 2 ether reward are added
        //    THEN NotifyReward event is emitted
        vm.expectEmit();
        emit NotifyReward(address(rewardToken), address(this), 2 ether);
        backersManager.notifyRewardAmount(2 ether);
        // THEN rewards is 2 ether
        assertEq(backersManager.rewardsERC20(), 2 ether);
        // THEN Coinbase rewards is 0
        assertEq(backersManager.rewardsCoinbase(), 0);
        // THEN reward token balance of backersManager is 2 ether
        assertEq(rewardToken.balanceOf(address(backersManager)), 2 ether);
        // THEN Coinbase balance of backersManager is 0
        assertEq(address(backersManager).balance, 0);
    }

    /**
     * SCENARIO: notifyRewardAmount is called with zero value - should not revert and rewards don't change
     */
    function test_NotifyRewardAmountZeroValue() public {
        // GIVEN a BackersManager contract
        //   WHEN 0 ether in rewardToken and 0 coinbase are added
        //    THEN it does not revert and rewards don't change
        backersManager.notifyRewardAmount(0 ether);
        // THEN reward for reward token is 0 ether
        assertEq(backersManager.rewardsERC20(), 0 ether);
        // THEN Coinbase reward is 0
        assertEq(backersManager.rewardsCoinbase(), 0);
    }

    /**
     * SCENARIO: notifyRewardAmount reverts when there are no active gauges
     */
    function test_NotifyRewardAmountWithNoActiveBuilders() public {
        // GIVEN a BackerManager contract
        //   WHEN both existing builders get revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);
        builderRegistry.revokeBuilderKYC(builder2);
        vm.stopPrank();

        // THEN there are no active gauges
        assertEq(builderRegistry.getGaugesLength(), 0);
        // THEN all there are 2 halted gauges
        assertEq(builderRegistry.getHaltedGaugesLength(), 2);

        // AND notifyRewardAmount is called with coinbase
        //  THEN it reverts with NoGaugesForDistribution error
        vm.expectRevert(BackersManagerRootstockCollective.NoGaugesForDistribution.selector);
        backersManager.notifyRewardAmount{ value: 1 ether }(0 ether);

        // AND notifyRewardAmount is called with rewardTken
        //  THEN it reverts with NoGaugesForDistribution error
        vm.expectRevert(BackersManagerRootstockCollective.NoGaugesForDistribution.selector);
        backersManager.notifyRewardAmount(0 ether);

        // AND notifyRewardAmount is called with both coinbase and rewardToken
        //  THEN it reverts with NoGaugesForDistribution error
        vm.expectRevert(BackersManagerRootstockCollective.NoGaugesForDistribution.selector);
        backersManager.notifyRewardAmount{ value: 1 ether }(1 ether);
    }

    /**
     * SCENARIO: notifyRewardAmount is called using Coinbase and values are updated
     */
    function test_NotifyRewardAmountCoinbase() public {
        // GIVEN a BackerManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        //   WHEN 2 ether reward are added
        //    THEN NotifyReward event is emitted
        vm.expectEmit();
        emit NotifyReward(UtilsLib._COINBASE_ADDRESS, address(this), 2 ether);
        backersManager.notifyRewardAmount{ value: 2 ether }(0);
        // THEN Coinbase rewards is 2 ether
        assertEq(backersManager.rewardsCoinbase(), 2 ether);
        // THEN ERC20 rewards is 0
        assertEq(backersManager.rewardsERC20(), 0);
        // THEN Coinbase balance of backersManager is 2 ether
        assertEq(address(backersManager).balance, 2 ether);
        // THEN reward token balance of backersManager is 0
        assertEq(rewardToken.balanceOf(address(backersManager)), 0);
    }

    /**
     * SCENARIO: notifyRewardAmount is called twice before distribution and values are updated
     */
    function test_NotifyRewardAmountTwice() public {
        // GIVEN a BackerManager contract
        //  AND alice allocates 0.1 ether
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        // AND 2 ether reward are added
        backersManager.notifyRewardAmount(2 ether);
        // WHEN 10 ether reward are more added
        backersManager.notifyRewardAmount(10 ether);
        // THEN rewards is is 12 ether
        assertEq(backersManager.rewardsERC20(), 12 ether);
        // THEN reward token balance of backersManager is 12 ether
        assertEq(rewardToken.balanceOf(address(backersManager)), 12 ether);
    }

    /**
     * SCENARIO: should revert is distribution period started
     */
    function test_RevertNotInDistributionPeriod() public {
        // GIVEN a BackerManager contract
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 gauges created
        for (uint256 i = 0; i < 20; i++) {
            GaugeRootstockCollective _newGauge =
                _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            allocationsArray.push(1 ether);

            // THEN gauges length increase
            assertEq(builderRegistry.getGaugesLength(), gaugesArray.length);
            // THEN new gauge is added in the last index
            assertEq(builderRegistry.getGaugeAt(gaugesArray.length - 1), address(_newGauge));
        }
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        vm.prank(builder2);
        builderRegistry.pauseSelf();

        //  AND 2 ether reward are added
        backersManager.notifyRewardAmount(2 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        //  AND distribution start
        backersManager.startDistribution();

        // WHEN tries to allocate during the distribution period
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(BackersManagerRootstockCollective.NotInDistributionPeriod.selector);
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        // WHEN tries to add more reward
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(BackersManagerRootstockCollective.NotInDistributionPeriod.selector);
        backersManager.notifyRewardAmount(2 ether);
        // WHEN tries to start distribution again
        //  THEN tx reverts because NotInDistributionPeriod
        vm.expectRevert(BackersManagerRootstockCollective.NotInDistributionPeriod.selector);
        backersManager.startDistribution();
        // WHEN builder tries to pause himself
        //  THEN tx reverts because NotInDistributionPeriod
        vm.prank(builder);
        vm.expectRevert(BackersManagerRootstockCollective.NotInDistributionPeriod.selector);
        builderRegistry.pauseSelf();
        // WHEN tries builder2 tries to unpause himself
        //  THEN tx reverts because NotInDistributionPeriod
        vm.prank(builder2);
        vm.expectRevert(BackersManagerRootstockCollective.NotInDistributionPeriod.selector);
        builderRegistry.unpauseSelf(0.1 ether);
    }

    /**
     * SCENARIO: should revert if distribution window did not start
     */
    function test_RevertOnlyInDistributionWindow() public {
        // GIVEN a BackerManager contract
        // WHEN someone tries to distribute after the distribution window start
        _skipToEndDistributionWindow();
        //  THEN tx reverts because OnlyInDistributionWindow
        vm.expectRevert(BackersManagerRootstockCollective.OnlyInDistributionWindow.selector);
        backersManager.startDistribution();
    }

    /**
     * SCENARIO: should revert is distribution period did not start
     */
    function test_RevertDistributionPeriodDidNotStart() public {
        // GIVEN a BackerManager contract
        // WHEN someone tries to distribute before the distribution period start
        //  THEN tx reverts because DistributionPeriodDidNotStart
        vm.expectRevert(BackersManagerRootstockCollective.DistributionPeriodDidNotStart.selector);
        backersManager.distribute();
    }

    /**
     * SCENARIO: alice and bob allocates to 2 gauges and distribute rewards to them
     */
    function test_Distribute() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
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
        backersManager.startDistribution();
        // THEN reward token balance of gauge is 27.272727272727272727 = 100 * 6 / 22
        assertEq(rewardToken.balanceOf(address(gauge)), 27_272_727_272_727_272_727);
        // THEN reward token balance of gauge2 is 72.727272727272727272 = 100 * 16 / 22
        assertEq(rewardToken.balanceOf(address(gauge2)), 72_727_272_727_272_727_272);
    }

    /**
     * SCENARIO: alice and bob allocates to 2 gauges and receive coinbase rewards
     */
    function test_DistributeCoinbase() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether rewardToken and 50 ether coinbase are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        backersManager.notifyRewardAmountCoinBase{value: 50 ether}();
        // AND distribution window starts
        _skipToStartDistributionWindow();

        //  WHEN distribute is executed
        backersManager.startDistribution();
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
     * SCENARIO: distribute twice on the same cycle with different allocations.
     *  The second allocation occurs on the distribution window timestamp.
     */
    function test_DistributeTwiceSameCycle() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added and distributed
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        backersManager.startDistribution();

        // AND bob modifies his allocations 16 ether to builder and 4 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 16 ether;
        allocationsArray[1] = 4 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  WHEN 100 ether reward are added and distributed again
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        backersManager.startDistribution();

        // THEN reward token balance of gauge is 91.558441558441558441 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(gauge)), 91_558_441_558_441_558_441);
        // THEN reward token balance of gauge2 is 108.441558441558441557 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(gauge2)), 108_441_558_441_558_441_557);
    }

    /**
     * SCENARIO: alice transfer part of her allocation in the middle of the cycle
     *  from builder to builder2, so the rewards accounted on that time are moved to builder2 too
     */
    function test_ModifyAllocationBeforeDistribution() public {
        // GIVEN a BackerManager contract
        // AND a new cycle
        _skipAndStartNewCycle();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        backersManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        backersManager.allocate(gauge2, 10 ether);

        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // AND alice modifies his allocations 5 ether to builder2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 5 ether);
        backersManager.allocate(gauge2, 5 ether);
        vm.stopPrank();

        // THEN rewardShares is 4536000 ether = 10 * 1/2 WEEK + 5 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 4_536_000 ether);
        // THEN rewardShares is 7560000 ether = 10 * 1/2 WEEK + 15 * 1/2 WEEK
        assertEq(gauge2.rewardShares(), 7_560_000 ether);
        // THEN total allocation is 12096000 ether = 4536000 + 7560000
        assertEq(backersManager.totalPotentialReward(), 12_096_000 ether);

        //  AND 100 ether reward are added and distributed
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        backersManager.startDistribution();

        // THEN rewardShares is 3024000 ether = 5 * 1 WEEK
        assertEq(gauge.rewardShares(), 3_024_000 ether);
        // THEN rewardShares is 9072000 ether = 15 * 1 WEEK
        assertEq(gauge2.rewardShares(), 9_072_000 ether);
        // THEN total allocation is 12096000 ether = 3024000 + 9072000
        assertEq(backersManager.totalPotentialReward(), 12_096_000 ether);

        // THEN reward token balance of gauge is 37.5 ether = 100 * 4536000 / 12096000
        assertEq(rewardToken.balanceOf(address(gauge)), 37.5 ether);
        // THEN reward token balance of gauge2 is 62.5 ether = 100 * 7560000 / 12096000
        assertEq(rewardToken.balanceOf(address(gauge2)), 62.5 ether);
    }

    /**
     * SCENARIO: alice removes all her allocation in the middle of the cycle
     *  from builder, so the rewards accounted on that time decrease
     */
    function test_UnallocationBeforeDistribution() public {
        // GIVEN a BackerManager contract
        // AND a new cycle
        _skipAndStartNewCycle();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        backersManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        backersManager.allocate(gauge2, 10 ether);

        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // AND alice unallocates all from builder
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0);
        vm.stopPrank();

        // THEN rewardShares is 3024000 ether = 10 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 3_024_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 9072000 ether = 3024000 + 6048000
        assertEq(backersManager.totalPotentialReward(), 9_072_000 ether);

        //  AND 100 ether reward are added and distributed
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        backersManager.startDistribution();

        // THEN rewardShares is 0
        assertEq(gauge.rewardShares(), 0);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 6048000 ether = 0 + 6048000
        assertEq(backersManager.totalPotentialReward(), 6_048_000 ether);

        // THEN reward token balance of gauge is 33.33 ether = 100 * 3024000 / 9072000
        assertEq(rewardToken.balanceOf(address(gauge)), 33_333_333_333_333_333_333);
        // THEN reward token balance of gauge2 is 66.66 ether = 100 * 6048000 / 9072000
        assertEq(rewardToken.balanceOf(address(gauge2)), 66_666_666_666_666_666_666);
    }

    /**
     * SCENARIO: alice removes part of her allocation in the middle of the cycle
     *  from builder, so the rewards accounted on that time decrease
     */
    function test_RemoveAllocationBeforeDistribution() public {
        // GIVEN a BackerManager contract
        // AND a new cycle
        _skipAndStartNewCycle();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        backersManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        backersManager.allocate(gauge2, 10 ether);

        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // AND alice removes 5 ether from builder
        vm.startPrank(alice);
        backersManager.allocate(gauge, 5 ether);
        vm.stopPrank();

        // THEN rewardShares is 4536000 ether = 10 * 1/2 WEEK + 5 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 4_536_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 10584000 ether = 4536000 + 6048000
        assertEq(backersManager.totalPotentialReward(), 10_584_000 ether);

        //  AND 100 ether reward are added and distributed
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        backersManager.startDistribution();

        // THEN rewardShares is 3024000 ether = 5 * 1 WEEK
        assertEq(gauge.rewardShares(), 3_024_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 9072000 ether = 3024000 + 6048000
        assertEq(backersManager.totalPotentialReward(), 9_072_000 ether);

        // THEN reward token balance of gauge is 42.857 ether = 100 * 4536000 / 10584000
        assertEq(rewardToken.balanceOf(address(gauge)), 42_857_142_857_142_857_142);
        // THEN reward token balance of gauge2 is 57.142 ether = 100 * 6048000 / 10584000
        assertEq(rewardToken.balanceOf(address(gauge2)), 57_142_857_142_857_142_857);
    }

    /**
     * SCENARIO: alice adds allocation in the middle of the cycle
     *  to builder, so the rewards accounted on that time increase
     */
    function test_AddAllocationBeforeDistribution() public {
        // GIVEN a BackerManager contract
        // AND a new cycle
        _skipAndStartNewCycle();
        // AND alice allocates 10 ether to builder
        vm.prank(alice);
        backersManager.allocate(gauge, 10 ether);

        // AND bob allocates 10 ether to builder2
        vm.prank(bob);
        backersManager.allocate(gauge2, 10 ether);

        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // AND alice adds 5 ether to builder
        vm.startPrank(alice);
        backersManager.allocate(gauge, 15 ether);
        vm.stopPrank();

        // THEN rewardShares is 7560000 ether = 10 * 1/2 WEEK + 15 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 7_560_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 13608000 ether = 7560000 + 6048000
        assertEq(backersManager.totalPotentialReward(), 13_608_000 ether);

        //  AND 100 ether reward are added and distributed
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // AND distribution is executed
        backersManager.startDistribution();

        // THEN rewardShares is 9072000 ether = 15 * 1 WEEK
        assertEq(gauge.rewardShares(), 9_072_000 ether);
        // THEN rewardShares is 6048000 ether = 10 * 1 WEEK
        assertEq(gauge2.rewardShares(), 6_048_000 ether);
        // THEN total allocation is 15120000 ether = 9072000 + 6048000
        assertEq(backersManager.totalPotentialReward(), 15_120_000 ether);

        // THEN reward token balance of gauge is 55.5 ether = 100 * 7560000 / 13608000
        assertEq(rewardToken.balanceOf(address(gauge)), 55_555_555_555_555_555_555);
        // THEN reward token balance of gauge2 is 44.4 ether = 100 * 6048000 / 13608000
        assertEq(rewardToken.balanceOf(address(gauge2)), 44_444_444_444_444_444_444);
    }

    /**
     * SCENARIO: distribute on 2 consecutive cycle with different allocations
     */
    function test_DistributeTwice() public {
        // GIVEN a backer alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 4 ether;
        allocationsArray[1] = 10 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  AND 100 ether reward are added and distributed
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        backersManager.startDistribution();
        // AND cycle finish
        _skipAndStartNewCycle();

        // AND bob modifies his allocations 16 ether to builder and 4 ether to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 16 ether;
        allocationsArray[1] = 4 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        //  WHEN 100 ether reward are added and distributed again
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        backersManager.startDistribution();

        // THEN reward token balance of gauge is 91.558441558441558441 = 100 * 6 / 22 + 100 * 18 / 28
        assertEq(rewardToken.balanceOf(address(gauge)), 91_558_441_558_441_558_441);
        // THEN reward token balance of gauge2 is 108.441558441558441557 = 100 * 16 / 22 + 100 * 10 / 28
        assertEq(rewardToken.balanceOf(address(gauge2)), 108_441_558_441_558_441_557);
    }

    /**
     * SCENARIO: distribution occurs on different transactions using pagination
     */
    function test_DistributeUsingPagination() public {
        // GIVEN a backer alice
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 gauges created
        for (uint256 i = 0; i < 20; i++) {
            _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 ether reward are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // WHEN distribute is executed
        backersManager.startDistribution();
        // THEN temporal total potential rewards is 12096000 ether = 20 * 1 WEEK
        assertEq(backersManager.tempTotalPotentialReward(), 12_096_000 ether);
        // THEN distribution period is still started
        assertEq(backersManager.onDistributionPeriod(), true);
        // THEN last gauge distributed is gauge 20
        assertEq(backersManager.indexLastGaugeDistributed(), 20);

        // AND distribute is executed again
        backersManager.distribute();
        // THEN temporal total potential rewards is 0
        assertEq(backersManager.tempTotalPotentialReward(), 0);
        // THEN total potential rewards is 13305600 ether = 22 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 13_305_600 ether);
        // THEN distribution period finished
        assertEq(backersManager.onDistributionPeriod(), false);
        // THEN last gauge distributed is 0
        assertEq(backersManager.indexLastGaugeDistributed(), 0);

        for (uint256 i = 0; i < 22; i++) {
            // THEN reward token balance of all the gauges is 4.545454545454545454 = 100 * 1 / 22
            assertEq(rewardToken.balanceOf(address(gaugesArray[i])), 4_545_454_545_454_545_454);
        }
    }

    /**
     * SCENARIO: distribution occurs on different transactions using pagination and
     * attempts to incentivize a gauge in new cycle before and during distribution should
     * fail
     */
    function test_DistributeAndIncentivizeGaugeDuringPagination() public {
        // GIVEN a backer alice
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND 22 gauges created
        for (uint256 i = 0; i < 20; i++) {
            _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 ether reward are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // WHEN there is an attempt to incentivize a gauge directly before distribution starts
        // with rewardToken
        //  THEN notifyRewardAmount reverts with BeforeDistribution error
        vm.startPrank(incentivizer);
        vm.expectRevert(GaugeRootstockCollective.BeforeDistribution.selector);
        gauge.incentivizeWithRewardToken(100 ether, address(rewardToken));
        vm.stopPrank();

        // WHEN there is an attempt to incentivize a gauge directly before distribution starts
        // with coinbase
        //  THEN notifyRewardAmount reverts with BeforeDistribution error
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);
        vm.expectRevert(GaugeRootstockCollective.BeforeDistribution.selector);
        gauge.incentivizeWithCoinbase{ value: 100 ether }();
        vm.stopPrank();

        // WHEN distribute is executed
        backersManager.startDistribution();

        // THEN last gauge distributed is gauge 20
        assertEq(backersManager.indexLastGaugeDistributed(), 20);

        // AND some minutes pass
        skip(600);

        // WHEN there is an attempt to incentivize a gauge directly before distribution ends
        //  THEN notifyRewardAmount reverts
        vm.startPrank(incentivizer);
        vm.expectRevert(GaugeRootstockCollective.BeforeDistribution.selector);
        gauge.incentivizeWithRewardToken(100 ether, address(rewardToken));
        vm.stopPrank();

        // WHEN there is an attempt to incentivize a gauge directly before distribution ends
        // with coinbase
        //  THEN notifyRewardAmount reverts
        vm.startPrank(incentivizer);
        vm.expectRevert(GaugeRootstockCollective.BeforeDistribution.selector);
        gauge.incentivizeWithCoinbase{ value: 100 ether }();
        vm.stopPrank();

        // AND distribute is executed again
        backersManager.distribute();

        // THEN distribution period finished
        assertEq(backersManager.onDistributionPeriod(), false);
        // THEN last gauge distributed is 0
        assertEq(backersManager.indexLastGaugeDistributed(), 0);

        for (uint256 i = 0; i < 22; i++) {
            // THEN reward token balance of all the gauges is 4.545454545454545454 = 100 * 1 / 22
            assertEq(rewardToken.balanceOf(address(gaugesArray[i])), 4_545_454_545_454_545_454);
        }
    }

    /**
     * SCENARIO: distribution occurs on different transactions using pagination and attempts to incentivize
     * BackersManagerRootstockCollective between both transactions should fail
     */
    function test_DistributeAndIncentivizeBackersManagerRootstockCollectiveDuringPagination() public {
        _createGaugesAllocateAndStartDistribution(20);

        // WHEN there is an attempt to add 100 ether reward in the middle of the distribution
        //  THEN notifyRewardAmount reverts
        vm.expectRevert(BackersManagerRootstockCollective.NotInDistributionPeriod.selector);
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);

        // AND distribute is executed again
        backersManager.distribute();

        // THEN distribution period finished
        assertEq(backersManager.onDistributionPeriod(), false);

        for (uint256 i = 0; i < 22; i++) {
            // THEN reward token balance of all the gauges is 4.545454545454545454 = 100 * 1 / 22
            assertEq(rewardToken.balanceOf(address(gaugesArray[i])), 4_545_454_545_454_545_454);
        }
    }

    /**
     * SCENARIO: alice claims all the rewards in a single tx
     */
    function test_ClaimBackerRewards() public {
        // GIVEN builder and builder2 which reward percentage is 50%
        //  AND a backer alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether reward are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        backersManager.startDistribution();

        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice rewardToken balance is 50% of the distributed amount
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_992);
    }

    /**
     * SCENARIO: alice claims all the rewards from a backersManager distribution and
     * incentivized gauge with rewardToken
     */
    function test_ClaimBackerRewardsWithIncentivizerInRewardToken() public {
        // GIVEN builder and builder2 and reward percentage of 50%
        //  AND a backer alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether reward are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND 100 ether are added directly to first gauge by incentivizer
        vm.startPrank(incentivizer);
        rewardToken.mint(address(incentivizer), 100 ether);
        rewardToken.approve(address(gaugesArray[0]), 100 ether);
        gauge.incentivizeWithRewardToken(100 ether, address(rewardToken));
        vm.stopPrank();

        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        backersManager.startDistribution();

        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice rewardToken balance is 50% of the distributed amount from the backersManager
        // and 100% of the rewards incentivized directly to the first gauge
        // 149.999999999999999990 = 100 ether * 0.5 + 100 ether
        assertEq(rewardToken.balanceOf(alice), 149_999_999_999_999_999_990);
    }

    /**
     * SCENARIO: alice claims all the rewards from a backersManager distribution and
     * incentivized gauge in coinbase
     */
    function test_ClaimBackerRewardsWithIncentivizerInCoinbase() public {
        // GIVEN builder and builder2 and reward percentage of 50%
        //  AND a backer alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether reward in coinbase are added
        backersManager.notifyRewardAmount{ value: 100 ether }(0 ether);
        // AND 100 ether in coinbase are added directly to first gauge by incentivizer
        vm.startPrank(incentivizer);
        vm.deal(address(incentivizer), 100 ether);
        gauge.incentivizeWithCoinbase{ value: 100 ether }();
        vm.stopPrank();

        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        backersManager.startDistribution();

        // AND cycle finishes
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice balance is 50% of the distributed amount from the backersManager
        // and 100% of the rewards incentivized directly to the first gauge
        // 149.999999999999999990 = 100 ether * 0.5 + 100 ether
        assertEq(address(alice).balance, 149_999_999_999_999_999_990);
    }

    /**
     * SCENARIO: alice claims all the ERC20 rewards in a single tx
     */
    function test_ClaimBackerERC20Rewards() public {
        // GIVEN builder and builder2 which reward percentage is 50%
        //  AND a backer alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether rewardToken and 50 ether coinbase are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        backersManager.notifyRewardAmountCoinBase{value: 50 ether}();
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        backersManager.startDistribution();

        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(address(rewardToken), gaugesArray);

        // THEN alice rewardToken balance is 50% of the distributed amount
        assertEq(rewardToken.balanceOf(alice), 49_999_999_999_999_999_992);

        // THEN coinbase balance is 0 of the distributed amount
        assertEq(alice.balance, 0);
    }

    /**
     * SCENARIO: alice claims all the coinbase rewards in a single tx
     */
    function test_ClaimBackerCoinbaseRewards() public {
        // GIVEN builder and builder2 which reward percentage is 50%
        //  AND a backer alice
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 ether rewardToken and 50 ether coinbase are added
        backersManager.notifyRewardAmount{ value: 50 ether }(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // AND distribute is executed
        backersManager.startDistribution();

        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(UtilsLib._COINBASE_ADDRESS, gaugesArray);

        // THEN alice coinbase balance is 50% of the distributed amount
        assertEq(alice.balance, 24_999_999_999_999_999_992);

        // THEN rewardToken balance is 0 of the distributed amount
        assertEq(rewardToken.balanceOf(alice), 0);
    }

    /**
     * SCENARIO: after a distribution, in the middle of the cycle, gauge loses all allocations.
     *  One distribution later, alice allocates there again in the next cycle and earn the old remaining rewards
     */
    function test_GaugeLosesAllocationForOneCycle() public {
        // GIVEN alice allocates to gauge and gauge2
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        // AND bob allocates to gauge2
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        vm.prank(bob);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND half cycle pass
        _skipRemainingCycleFraction(2);

        // WHEN alice removes allocations from gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 0);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND alice adds allocations again
        vm.prank(alice);
        backersManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice rewardToken balance is:
        //  cycle 1 = 21.875 = 3.125 + 18.75 = (100 * 2 / 16) * 0.5 * 0.5 WEEKS + (100 * 6 / 16) * 0.5
        //  cycle 2 = 23.33 = 3.333 + 20 = (100 * 1 / 15) * 0.5 + (100 * 6 / 15) * 0.5
        //  cycle 3 = 3.125 + 25 = 3.125(missingRewards) + (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(alice), 73_333_333_333_333_333_314);
        // THEN alice coinbase balance is:
        //  cycle 1 = 2.1875 = 0.3125 + 1.875 = (10 * 2 / 16) * 0.5 * 0.5 WEEKS + (10 * 6 / 16) * 0.5
        //  cycle 2 = 2.333 = 0.3333 + 2 = (10 * 1 / 15) * 0.5 + (10 * 6 / 15) * 0.5
        //  cycle 3 = 0.3125 + 2.5 = 0.3125(missingRewards) + (10 * 8 / 16) * 0.5
        assertEq(alice.balance, 7_333_333_333_333_333_314);

        // WHEN bob claim rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN bob rewardToken balance is:
        //  cycle 1 = 25 = (100 * 8 / 16) * 0.5
        //  cycle 2 = 26.66 = (100 * 8 / 15) * 0.5
        //  cycle 3 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(bob), 76_666_666_666_666_666_648);
        // THEN bob coinbase balance is:
        //  cycle 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  cycle 2 = 2.66 = (10 * 8 / 15) * 0.5
        //  cycle 3 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(bob.balance, 7_666_666_666_666_666_648);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is:
        //  cycle 1 = 6.25 = (100 * 2 / 16) * 0.5
        //  cycle 2 = 3.333 = (100 * 1 / 15) * 0.5
        //  cycle 3 = 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 15_833_333_333_333_333_333);
        // THEN builder coinbase balance is:
        //  cycle 1 = 0.625 = (10 * 2 / 16) * 0.5
        //  cycle 2 = 0.3333 = (10 * 1 / 15) * 0.5
        //  cycle 3 = 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 1_583_333_333_333_333_333);

        // THEN builder2Receiver rewardToken balance is:
        //  cycle 1 = 43.75 = (100 * 14 / 16) * 0.5
        //  cycle 2 = 46.66 = (100 * 14 / 15) * 0.5
        //  cycle 3 = 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 134_166_666_666_666_666_667);
        // THEN builder2Receiver coinbase balance is:
        //  cycle 1 = 4.375 = (10 * 14 / 16) * 0.5
        //  cycle 2 = 4.66 = (10 * 14 / 15) * 0.5
        //  cycle 3 = 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 13_416_666_666_666_666_667);

        // THEN gauge rewardToken balance is 0, there is no remaining rewards
        assertApproxEqAbs(rewardToken.balanceOf(address(gauge)), 0, 100);
        // THEN gauge coinbase balance is 0, there is no remaining rewards
        assertApproxEqAbs(address(gauge).balance, 0, 100);
    }

    /**
     * SCENARIO: after a distribution, in the middle of the cycle, gauge loses all allocations.
     *  One distribution later, alice allocates there again in 2 cycles later and earn the old remaining rewards
     */
    function test_GaugeLosesAllocationForTwoCycles() public {
        // GIVEN alice allocates to gauge and gauge2
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        // AND bob allocates to gauge2
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        vm.prank(bob);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND half cycle pass
        _skipRemainingCycleFraction(2);

        // WHEN alice removes allocations from gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 0);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND alice adds allocations again
        vm.prank(alice);
        backersManager.allocate(gauge, 2 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice rewardToken balance is:
        //  cycle 1 = 21.875 = 3.125 + 18.75 = (100 * 2 / 16) * 0.5 * 0.5 WEEKS + (100 * 6 / 16) * 0.5
        //  cycle 2 = 20 = (100 * 6 / 15) * 0.5
        //  cycle 3 = 6.455 + 21.42  = (3.33 + 3.125)(missingRewards) + (100 * 6 / 14) * 0.5
        //  cycle 4 = 6.25 + 18.75 = (100 * 2 / 16) * 0.5 + (100 * 6 / 16) * 0.5
        assertEq(rewardToken.balanceOf(alice), 94_761_904_761_904_761_882);
        // THEN alice coinbase balance is:
        //  cycle 1 = 2.1875 = 0.3125 + 1.875 = (10 * 2 / 16) * 0.5 * 0.5 WEEKS + (10 * 6 / 16) * 0.5
        //  cycle 2 = 2 = (10 * 6 / 15) * 0.5
        //  cycle 3 = 0.645 + 2.142  = (0.33 + 0.3125)(missingRewards) + (10 * 6 / 14) * 0.5
        //  cycle 4 = 0.625 + 1.875 = (10 * 2 / 16) * 0.5 + (10 * 6 / 16) * 0.5
        assertEq(alice.balance, 9_476_190_476_190_476_166);

        // WHEN bob claim rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN bob rewardToken balance is:
        //  cycle 1 = 25 = (100 * 8 / 16) * 0.5
        //  cycle 2 = 26.66 = (100 * 8 / 15) * 0.5
        //  cycle 3 = 28.57 = (100 * 8 / 14) * 0.5
        //  cycle 4 = 25 = (100 * 8 / 16) * 0.5
        assertEq(rewardToken.balanceOf(bob), 105_238_095_238_095_238_072);
        // THEN bob coinbase balance is:
        //  cycle 1 = 2.5 = (10 * 8 / 16) * 0.5
        //  cycle 2 = 2.66 = (10 * 8 / 15) * 0.5
        //  cycle 3 = 2.857 = (10 * 8 / 14) * 0.5
        //  cycle 4 = 2.5 = (10 * 8 / 16) * 0.5
        assertEq(bob.balance, 10_523_809_523_809_523_784);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is:
        //  cycle 1 = 6.25 = (100 * 2 / 16) * 0.5
        //  cycle 2 = 3.333 = (100 * 1 / 15) * 0.5
        //  cycle 3 = 0
        //  cycle 4 = 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 15_833_333_333_333_333_333);
        // THEN builder coinbase balance is:
        //  cycle 1 = 0.625 = (10 * 2 / 16) * 0.5
        //  cycle 2 = 0.3333 = (10 * 1 / 15) * 0.5
        //  cycle 3 = 0
        //  cycle 4 = 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 1_583_333_333_333_333_333);

        // THEN builder2Receiver rewardToken balance is:
        //  cycle 1 = 43.75 = (100 * 14 / 16) * 0.5
        //  cycle 2 = 46.66 = (100 * 14 / 15) * 0.5
        //  cycle 3 = 50 = (100 * 14 / 14) * 0.5
        //  cycle 4 = 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 184_166_666_666_666_666_667);
        // THEN builder2Receiver coinbase balance is:
        //  cycle 1 = 4.375 = (10 * 14 / 16) * 0.5
        //  cycle 2 = 4.66 = (10 * 14 / 15) * 0.5
        //  cycle 3 = 5 = (10 * 14 / 14) * 0.5
        //  cycle 4 = 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 18_416_666_666_666_666_667);

        // THEN gauge rewardToken balance is 0, there is no remaining rewards
        assertApproxEqAbs(rewardToken.balanceOf(address(gauge)), 0, 100);
        // THEN gauge coinbase balance is 0, there is no remaining rewards
        assertApproxEqAbs(address(gauge).balance, 0, 100);
    }

    /**
     * SCENARIO: after a distribution, alice deallocates and allocates twice on the same cycle
     *  Missing rewards are accumulated
     */
    function test_MissingRewardsAccumulation() public {
        // GIVEN alice allocates to gauge and gauge2
        _skipAndStartNewCycle();
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to gauge2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
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
        backersManager.allocate(gauge, 0);
        // AND 1 day pass
        skip(1 days);
        // AND alice adds allocations from gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 2 ether);

        // THEN rewardToken's rewardMissing is 0.89 = 0.0000103 * 1 day
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 892_857_142_857_142_857);
        // THEN coinbase's rewardMissing is 0.089 = 0.00000103 * 1 day
        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 89_285_714_285_714_285);

        // AND 1 day pass
        skip(1 days);
        // AND alice removes allocations from gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0);
        // AND 1 day pass
        skip(1 days);
        // AND alice adds allocations from gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 2 ether);

        // THEN rewardToken's rewardMissing is 1.78 = 0.0000103 * 2 days
        assertEq(gauge.rewardMissing(address(rewardToken)) / 10 ** 18, 1_785_714_285_714_285_714);
        // THEN coinbase's rewardMissing is 0.178 = 0.00000103 * 2 days
        assertEq(gauge.rewardMissing(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 178_571_428_571_428_571);
    }

    /**
     * SCENARIO: BackersManagerRootstockCollective is initialized with an offset of 7 weeks. First distribution starts
     *  8 weeks after the deploy
     */
    function test_InitializedWithAnCycleStartOffset() public {
        // GIVEN a BackersManagerRootstockCollective contract initialized with 7 weeks of offset

        // all the tests are running with the BackersManagerRootstockCollective already initialized with
        // cycleStartOffset = 0
        // to simplify the calcs. since, we cannot change that value after the initialization we need this function
        // to test the scenario where the contract is initialized with a different value
        uint24 _newOffset = 7 weeks;

        stdstore.target(address(backersManager)).sig("cycleData()").depth(4).enable_packed_slots().checked_write(
            _newOffset
        );

        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart, uint24 _offset) =
            backersManager.cycleData();

        // THEN previous cycle duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next cycle duration is 1 week
        assertEq(_nextDuration, 1 weeks);
        // THEN previous cycle start is now
        assertEq(_previousStart, block.timestamp);
        // THEN previous cycle start is now
        assertEq(_nextStart, block.timestamp);
        // THEN cycle start offset is 7 weeks
        assertEq(_offset, 7 weeks);

        // THEN cycle starts now
        assertEq(backersManager.cycleStart(block.timestamp), block.timestamp);
        // THEN cycle ends in 8 weeks from now (1 weeks duration + 7 weeks offset)
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 8 weeks);

        // AND alice allocates 2 ether to builder and 6 ether to builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        uint256 _timestampBefore = block.timestamp;
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN cycle was of 8 weeks
        assertEq(block.timestamp - _timestampBefore, 8 weeks);
        _timestampBefore = block.timestamp;
        // AND cycle finishes
        _skipAndStartNewCycle();
        // THEN cycle was of 1 weeks
        assertEq(block.timestamp - _timestampBefore, 1 weeks);

        // THEN cycle starts now
        assertEq(backersManager.cycleStart(block.timestamp), block.timestamp);
        // THEN cycle ends in 1 weeks
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1 weeks);

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice rewardToken balance is 50% of the distributed amount
        assertApproxEqAbs(rewardToken.balanceOf(alice), 50 ether, 100);
        // THEN alice coinbase balance is 50% of the distributed amount
        assertApproxEqAbs(alice.balance, 5 ether, 100);
    }

    /**
     * SCENARIO: BackersManagerRootstockCollective is initialized with an offset of 7 weeks.
     *  There is a notifyReward amount to incentive the gauge before the distribution
     */
    function test_IncentivizeWithCycleStartOffset() public {
        // GIVEN a BackersManagerRootstockCollective contract initialized with 7 weeks of offset

        // all the tests are running with the BackersManagerRootstockCollective already initialized with
        // cycleStartOffset = 0
        // to simplify the calcs. since, we cannot change that value after the initialization we need this function
        // to test the scenario where the contract is initialized with a different value
        uint24 _newOffset = 7 weeks;

        stdstore.target(address(backersManager)).sig("cycleData()").depth(4).enable_packed_slots().checked_write(
            _newOffset
        );

        // periodFinish is initialized using the cycleStartOffset = 0 on initialization, we need to calculate it again
        // with the newCycleStartOffset = 7 weeks
        stdstore.target(address(backersManager)).sig("periodFinish()").checked_write(
            backersManager.cycleNext(block.timestamp)
        );

        // AND gauge is incentive with 100 ether of rewardToken
        rewardToken.approve(address(gauge), 100 ether);
        gauge.incentivizeWithRewardToken(100 ether, address(rewardToken));

        // AND alice allocates 2 ether to builder
        vm.startPrank(alice);
        backersManager.allocate(gauge, 2 ether);
        vm.stopPrank();

        uint256 _timestampBefore = block.timestamp;
        // AND cycle finishes
        _distribute(0, 0);
        // THEN cycle was of 8 weeks
        assertEq(block.timestamp - _timestampBefore, 8 weeks);

        // THEN cycle starts now
        assertEq(backersManager.cycleStart(block.timestamp), block.timestamp);
        // THEN cycle ends in 1 weeks
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1 weeks);

        // WHEN alice claim rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice rewardToken balance is 100% of the distributed amount
        assertApproxEqAbs(rewardToken.balanceOf(alice), 100 ether, 100);
    }

    /**
     * SCENARIO: After deployment BackersManagerRootstockCollective starts in a distribution window
     */
    function test_DeployStartsInDistributionWindow() public {
        // GIVEN a BackersManagerRootstockCollective contract initialized with 3 days of offset

        // all the tests are running with the BackersManagerRootstockCollective already initialized with
        // cycleStartOffset = 0
        // to simplify the calcs. since, we cannot change that value after the initialization we need this function
        // to test the scenario where the contract is initialized with a different value
        uint24 _newOffset = 3 days;

        stdstore.target(address(backersManager)).sig("cycleData()").depth(4).enable_packed_slots().checked_write(
            _newOffset
        );

        // AND alice allocates 2 ether to builder and 6 ether to builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND distribution starts
        backersManager.startDistribution();
        // THEN distribution finished
        assertEq(backersManager.onDistributionPeriod(), false);

        uint256 _deployTimestamp = block.timestamp;
        // AND distribution windows finishes
        vm.warp(_deployTimestamp + 1 hours + 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(BackersManagerRootstockCollective.OnlyInDistributionWindow.selector);
        backersManager.startDistribution();

        // AND offset finishes
        vm.warp(_deployTimestamp + _newOffset + 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(BackersManagerRootstockCollective.OnlyInDistributionWindow.selector);
        backersManager.startDistribution();

        // AND cycle duration finishes
        vm.warp(_deployTimestamp + cycleDuration + 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(BackersManagerRootstockCollective.OnlyInDistributionWindow.selector);
        backersManager.startDistribution();

        // AND cycle duration + offset is close to finish
        vm.warp(_deployTimestamp + cycleDuration + _newOffset - 1);
        // THEN reverts calling startDistribution
        vm.expectRevert(BackersManagerRootstockCollective.OnlyInDistributionWindow.selector);
        backersManager.startDistribution();

        // AND cycle duration + offset finishes
        vm.warp(_deployTimestamp + cycleDuration + _newOffset);
        // AND distribution starts
        backersManager.startDistribution();
        // THEN distribution finished
        assertEq(backersManager.onDistributionPeriod(), false);
    }

    /**
     * SCENARIO: distribution with no allocations
     */
    function test_StartDistributionWithoutAllocations() public {
        _startDistributionWithoutAllocations();
    }

    /**
     * SCENARIO: after a distribution with allocations, the next distribution with no allocations
     */
    function test_StartDistributionAfterLosingAllocations() public {
        // GIVEN a BackersManagerRootstockCollective with allocations
        vm.startPrank(alice);
        backersManager.allocate(gauge, 2 ether);
        vm.stopPrank();

        // THEN total potential reward is 12096000 ether = 2 ether * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 1_209_600 ether);

        //  AND 50 ether rewardToken and 50 ether coinbase are added
        backersManager.notifyRewardAmount(address(rewardToken), 50 ether);
        backersManager.notifyRewardAmountCoinBase{value: 50 ether}();

        // AND a new cycle
        _skipAndStartNewCycle();

        //  AND distribute is executed
        backersManager.startDistribution();

        // THEN reward token balance of backersManager is 0 ether
        assertEq(rewardToken.balanceOf(address(backersManager)), 0);
        // THEN Coinbase balance of backersManager is 0 ether
        assertEq(address(backersManager).balance, 0);
        // THEN backersManager rewardsERC20 is 0 ether
        assertEq(backersManager.rewardsERC20(), 0);
        // THEN backersManager rewardsCoinbase is 0 ether
        assertEq(backersManager.rewardsCoinbase(), 0);

        // AND alice removes allocations from gauge
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0);
        vm.stopPrank();

        // AND a new cycle
        _skipAndStartNewCycle();

        _startDistributionWithoutAllocations();
    }

    function _startDistributionWithoutAllocations() internal {
        // GIVEN a BackersManagerRootstockCollective without allocations
        assertEq(backersManager.totalPotentialReward(), 0);

        //  AND 50 ether rewardToken and 50 ether coinbase are added
        backersManager.notifyRewardAmount{ value: 50 ether }(50 ether);

        //  WHEN distribute is executed
        //   THEN RewardDistributionStarted event is emitted
        vm.expectEmit();
        emit RewardDistributionStarted(address(this));
        //   THEN RewardDistributionFinished event is emitted
        vm.expectEmit();
        emit RewardDistributionFinished(address(this));
        backersManager.startDistribution();

        // THEN reward token balance of backersManager is 50 ether
        assertEq(rewardToken.balanceOf(address(backersManager)), 50 ether);
        // THEN Coinbase balance of backersManager is 50 ether
        assertEq(address(backersManager).balance, 50 ether);
        // THEN backersManager rewardsERC20 is 50 ether
        assertEq(backersManager.rewardsERC20(), 50 ether);
        // THEN backersManager rewardsCoinbase is 50 ether
        assertEq(backersManager.rewardsCoinbase(), 50 ether);

        // THEN last gauge distributed is gauge 0
        assertEq(backersManager.indexLastGaugeDistributed(), 0);
        // THEN temporal total potential rewards is 0
        assertEq(backersManager.tempTotalPotentialReward(), 0);
        // THEN distribution finished
        assertEq(backersManager.onDistributionPeriod(), false);
        // THEN periodFinish is 0
        assertEq(backersManager.periodFinish(), backersManager.cycleNext(block.timestamp));
    }

    function _createGaugesAllocateAndStartDistribution(uint256 gaugesAmount_) internal {
        // GIVEN a backer alice
        allocationsArray[0] = 1 ether;
        allocationsArray[1] = 1 ether;
        //  AND additional gaugesAmount_ gauges created
        for (uint256 i = 0; i < gaugesAmount_; i++) {
            _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            allocationsArray.push(1 ether);
        }
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 ether reward are added
        backersManager.notifyRewardAmount(address(rewardToken), 100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        // WHEN distribute is executed
        backersManager.startDistribution();

        // THEN distribution period started
        assertTrue(backersManager.onDistributionPeriod());
    }

    /**
     * SCENARIO: configurator can update maxDistributionsPerBatch
     */
    function test_UpdateMaxDistributionsPerBatch() public {
        // GIVEN a new maxDistributionsPerBatch value
        uint256 _newMaxDistributionsPerBatch = 30;
        uint256 _oldMaxDistributionsPerBatch = backersManager.maxDistributionsPerBatch();

        // WHEN configurator calls updateMaxDistributionsPerBatch
        vm.prank(governanceManager.configurator());
        vm.expectEmit();
        emit MaxDistributionsPerBatchUpdated(_oldMaxDistributionsPerBatch, _newMaxDistributionsPerBatch);
        backersManager.updateMaxDistributionsPerBatch(_newMaxDistributionsPerBatch);

        // THEN maxDistributionsPerBatch is updated
        assertEq(backersManager.maxDistributionsPerBatch(), _newMaxDistributionsPerBatch);
    }

    /**
     * SCENARIO: non-configurator cannot update maxDistributionsPerBatch
     */
    function test_RevertUpdateMaxDistributionsPerBatchNotConfigurator() public {
        // GIVEN a new maxDistributionsPerBatch value
        uint256 _newMaxDistributionsPerBatch = 30;

        // WHEN a non-configurator tries to update maxDistributionsPerBatch
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IGovernanceManagerRootstockCollective.NotAuthorizedConfigurator.selector, alice)
        );
        backersManager.updateMaxDistributionsPerBatch(_newMaxDistributionsPerBatch);
    }

    /**
     * SCENARIO: distribution functions work correctly after changing maxDistributionsPerBatch
     */
    function test_DistributeAfterChangingMaxDistributionsPerBatch() public {
        _createGaugesAllocateAndStartDistribution(23);
        // AND indexLastGaugeDistributed is updated to 20
        assertEq(backersManager.indexLastGaugeDistributed(), 20);

        // THEN maxDistributionsPerBatch is updated to a smaller value
        uint256 _newMaxDistributionsPerBatch = 3; // Smaller than the number of gauges (20)
        vm.prank(governanceManager.configurator());
        backersManager.updateMaxDistributionsPerBatch(_newMaxDistributionsPerBatch);

        // WHEN distribute is called again
        bool _finished = backersManager.distribute();

        // THEN distribution is not finished (since we have 25 gauges but maxDistributionsPerBatch is 3)
        assertFalse(_finished);

        // AND indexLastGaugeDistributed is updated to 23 (3 more gauges were processed)
        assertEq(backersManager.indexLastGaugeDistributed(), 23);

        // WHEN distribute is called one more time
        _finished = backersManager.distribute();

        // THEN distribution is finished (all gauges were processed)
        assertTrue(_finished);

        // AND indexLastGaugeDistributed is reset to 0
        assertEq(backersManager.indexLastGaugeDistributed(), 0);

        // AND distribution period is over
        assertFalse(backersManager.onDistributionPeriod());
    }
}
