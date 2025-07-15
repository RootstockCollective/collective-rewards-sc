// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, BackersManagerRootstockCollective, GaugeRootstockCollective } from "../BaseTest.sol";
import { UtilsLib } from "src/libraries/UtilsLib.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract SkipDistribution is BaseTest {
    function _setUp() internal override {
        // start from a new cycle
        _skipAndStartNewCycle();
    }

    /**
     * SCENARIO: there is an cycle without distribution.
     * - There are allocations on first cycle
     * - There is a distribution for next cycle and sponsors start to earn rewards
     * - Cycle finishes but there is no distribution during distribution window
     * - Sponsors and builders can still claim rewards from previous cycle
     * - There are new allocations in cycle without distribution
     * - New cycle starts and there is a distribution
     * - Sponsors and builders are able to claim rewards for previous cycles
     */
    function test_integration_NoDistributionOnCycle() public {
        // CYCLE 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        backersManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        backersManager.allocate(gauge, 2 ether);

        // CYCLE 2
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);

        // CYCLE 3
        // AND new cycle finishes
        _skipAndStartNewCycle();
        // AND distribution window ends without a new distribution
        _skipToEndDistributionWindow();
        // AND bob votes to gauge2
        vm.prank(bob);
        backersManager.allocate(gauge2, 1 ether);

        // CYCLE 4
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 5
        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 2 / 4 = 25
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 50 * 2 / 5 = 20
        // total = 45
        assertEq(_clearERC20Balance(alice), 44_994_040_524_433_849_818);
        // THEN alice receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 2 / 4 = 2.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 5 * 2 / 5 ) = 2
        // total = 4.5
        assertEq(_clearNativeBalance(alice), 4_499_404_052_443_384_978);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 2 / 4 = 25
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 50 * 3 / 5 = 30
        // total = 55
        assertEq(_clearERC20Balance(bob), 55_005_959_475_566_150_175);
        // THEN bob receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 2 / 4 = 2.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 5 * 3 / 5 ) = 3
        // total = 5.5
        assertEq(_clearNativeBalance(bob), 5_500_595_947_556_615_013);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 3 / 4 = 37.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 50 * 3 / 5 = 30
        // total = 67.5
        assertEq(_clearERC20Balance(builder), 67_535_756_853_396_901_073);
        // THEN gauge builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 3 / 4 = 3.75
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 5 * 3 / 5 = 3
        // total = 6.75
        assertEq(_clearNativeBalance(builder), 6_753_575_685_339_690_107);

        // THEN gauge2 builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 1 / 4 = 12.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 50 * 2 / 5 = 20
        // total = 32.5
        assertEq(_clearERC20Balance(builder2Receiver), 32_464_243_146_603_098_927);
        // THEN gauge2 builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 1 / 4 = 1.25
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 5 * 2 / 5 = 2
        // total = 3.25
        assertEq(_clearNativeBalance(builder2Receiver), 3_246_424_314_660_309_893);
    }

    /**
     * SCENARIO: there is an cycle without distribution.
     * - There are allocations on first cycle
     * - There is a distribution for next cycle and sponsors start to earn rewards
     * - There are no distribution in two consecutive cycles
     * - Sponsors and builders can still claim rewards from previous cycles
     * - There are new allocations in cycle without distribution
     * - New cycle starts and there is a distribution
     * - Sponsors and builders are able to claim rewards for every cycle
     */
    function test_integration_NoDistributionOnConsecutiveCycles() public {
        // CYCLE 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        backersManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        backersManager.allocate(gauge, 2 ether);

        // CYCLE 2
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);

        // CYCLE 3
        // AND new cycle finishes
        _skipAndStartNewCycle();
        // CYCLE 4
        // AND another new cycle finishes
        _skipAndStartNewCycle();
        // AND distribution window ends without a new distribution
        _skipToEndDistributionWindow();
        // AND bob votes to gauge2
        vm.prank(bob);
        backersManager.allocate(gauge2, 1 ether);

        // CYCLE 5
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 6
        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 2 / 4 = 25
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 50 * 2 / 5 = 20
        // total = 45
        assertEq(_clearERC20Balance(alice), 44_994_040_524_433_849_818);
        // THEN alice receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 2 / 4 = 2.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 5 * 2 / 5 ) = 2
        // total = 4.5
        assertEq(_clearNativeBalance(alice), 4_499_404_052_443_384_978);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 2 / 4 = 25
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 50 * 3 / 5 = 30
        // total = 55
        assertEq(_clearERC20Balance(bob), 55_005_959_475_566_150_175);
        // THEN bob receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 2 / 4 = 2.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 5 * 3 / 5 = 3
        // total = 5.5
        assertEq(_clearNativeBalance(bob), 5_500_595_947_556_615_013);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 3 / 4 = 37.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 50 * 3 / 5 = 30
        // total = 67.5
        assertEq(_clearERC20Balance(builder), 67_535_756_853_396_901_073);
        // THEN gauge builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 3 / 4 = 3.75
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 5 * 3 / 5 = 3
        // total = 6.75
        assertEq(_clearNativeBalance(builder), 6_753_575_685_339_690_107);

        // THEN gauge2 builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 1 / 4 = 12.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 50 * 2 / 5 = 20
        // total = 32.5
        assertEq(_clearERC20Balance(builder2Receiver), 32_464_243_146_603_098_927);
        // THEN gauge2 builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 1 / 4 = 1.25
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 0 (no new distribution)
        // cycle 5 = 5 * 2 / 5 = 2
        // total = 3.25
        assertEq(_clearNativeBalance(builder2Receiver), 3_246_424_314_660_309_893);
    }

    /**
     * SCENARIO: there is an cycle without distribution and missing rewards.
     * - There are allocations in first cycle
     * - There is a distribution for next cycle
     * - There is a complete deallocation at the middle of the cycle (so there will be missing rewards)
     * - Cycle finishes but there is no distribution during distribution window
     * - There is an allocation in the middle of the new cycle
     * - There is a distribution in following cycle - missing rewards were not lost
     */
    function test_integration_NoDistributionAndMissingRewards() public {
        // CYCLE 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        backersManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        backersManager.allocate(gauge, 2 ether);

        // CYCLE 2
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);
        // AND half an cycle passes
        _skipRemainingCycleFraction(2);
        // AND alice removes all votes
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0 ether);
        backersManager.allocate(gauge2, 0 ether);
        vm.stopPrank();
        // AND bob removes all votes
        vm.prank(bob);
        backersManager.allocate(gauge, 0 ether);

        // CYCLE 3
        // AND new cycle finishes
        _skipAndStartNewCycle();
        // AND half an cycle passes
        _skipRemainingCycleFraction(2);
        // AND alice votes to gauge and gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        backersManager.allocate(gauge2, 1 ether);
        vm.stopPrank();

        // CYCLE 4
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);
        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 5
        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // cycle 1 = 0
        // cycle 2 = (50 / 2) * 2 / 4 = 12.5
        // cycle 3 = (50 / 2) * 2 / 2 = 25 (missingRewards)
        // cycle 4 = 50 * 2 / 2 = 50
        // total = 87.5
        assertEq(_clearERC20Balance(alice), 87_499_999_999_999_999_995);
        // THEN alice receives native tokens
        // cycle 1 = 0
        // cycle 2 = (5 / 2) * 2 / 4 = 1.25
        // cycle 3 = (5 / 2) * 2 / 2 = 2.5 (missingRewards)
        // cycle 4 = 5 * 2 / 2 = 5
        // total = 8.75
        assertEq(_clearNativeBalance(alice), 8_749_999_999_999_999_995);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives rewardToken
        // cycle 1 = 0
        // cycle 2 = (50 / 2) * 2 / 4 = 12.5
        // cycle 3 = 0
        // cycle 4 = 0
        // total = 12.5
        assertEq(_clearERC20Balance(bob), 12_499_999_999_999_999_998);
        // THEN bob receives native tokens
        // cycle 1 = 0
        // cycle 2 = (5 / 2) * 2 / 4 = 1.25
        // cycle 3 = 0
        // cycle 4 = 0
        // total = 1.25
        assertEq(_clearNativeBalance(bob), 1_249_999_999_999_999_998);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 3 / 4 = 37.5
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 50 * 2 / 3 = 33.33 (3 votes for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 70.08
        assertEq(_clearERC20Balance(builder), 70_833_333_333_333_333_333);
        // THEN gauge builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 3 / 4 = 3.75
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 5 * 2 / 3 = 3.33 (3 votes for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 7.00
        assertEq(_clearNativeBalance(builder), 7_083_333_333_333_333_333);

        // THEN gauge2 builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 1 / 4 = 12.5
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 50 * 1 / 3 = 16.66 (1 vote for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 29.16
        assertEq(_clearERC20Balance(builder2Receiver), 29_166_666_666_666_666_667);
        // THEN gauge2 builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 1 / 4 = 1.25
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 5 * 1 / 3 = 1.66 (1 vote for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 2.91
        assertEq(_clearNativeBalance(builder2Receiver), 2_916_666_666_666_666_667);
    }

    /**
     * SCENARIO: there are two consecutive cycles without distribution.
     * - There are allocations in first cycle
     * - There is a distribution for next cycle
     * - There is a complete deallocation at the middle of the cycle (so there will be missing rewards)
     * - Cycle finishes but there is no distribution during distribution window
     * - There is an allocation in the middle of the next cycle and no distribution
     * - There is a distribution in following cycle - missing rewards were not lost
     */
    function test_integration_NoDistributionOnConsecutiveCyclesAndMissingRewards() public {
        // CYCLE 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        backersManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        backersManager.allocate(gauge, 2 ether);

        // CYCLE 2
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);
        // AND half an cycle passes
        _skipRemainingCycleFraction(2);
        // AND alice removes all votes
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0 ether);
        backersManager.allocate(gauge2, 0 ether);
        vm.stopPrank();
        // AND bob removes all votes
        vm.prank(bob);
        backersManager.allocate(gauge, 0 ether);

        // CYCLE 3
        // AND new cycle finishes
        _skipAndStartNewCycle();
        // AND half an cycle passes
        _skipRemainingCycleFraction(2);
        // AND alice votes to gauge and gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        backersManager.allocate(gauge2, 1 ether);
        vm.stopPrank();

        // CYCLE 4
        // AND cycle finishes without distribution
        _skipAndStartNewCycle();

        // CYCLE 5
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);
        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 6
        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // cycle 1 = 0
        // cycle 2 = (50 / 2) * 2 / 4 = 12.5
        // cycle 3 = 0
        // cycle 4 = (50 / 2) * 2 / 2 = 25 (missingRewards)
        // cycle 5 = 50 * 2 / 2 = 50
        // total = 87.5
        assertEq(_clearERC20Balance(alice), 87_499_999_999_999_999_995);
        // THEN alice receives native tokens
        // cycle 1 = 0
        // cycle 2 = (5 / 2) * 2 / 4 = 1.25
        // cycle 3 = 0
        // cycle 4 = (5 / 2) * 2 / 2 = 2.5 (missingRewards)
        // cycle 5 = 5 * 2 / 2 = 5
        // total = 8.75
        assertEq(_clearNativeBalance(alice), 8_749_999_999_999_999_995);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives rewardToken
        // cycle 1 = 0
        // cycle 2 = (50 / 2) * 2 / 4 = 12.5
        // cycle 3 = 0
        // cycle 4 = 0
        // cycle 5 = 0
        // total = 12.5
        assertEq(_clearERC20Balance(bob), 12_499_999_999_999_999_998);
        // THEN bob receives native tokens
        // cycle 1 = 0
        // cycle 2 = (50 / 2) * 2 / 4 = 1.25
        // cycle 3 = 0
        // cycle 4 = 0
        // cycle 5 = 0
        // total = 1.25
        assertEq(_clearNativeBalance(bob), 1_249_999_999_999_999_998);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 3 / 4 = 37.5
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 0
        // cycle 5 = 50 * 2 / 3 = 33.33 (3 votes for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 70.08
        assertEq(_clearERC20Balance(builder), 70_833_333_333_333_333_333);
        // THEN gauge builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 3 / 4 = 3.75
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 0
        // cycle 5 = 5 * 2 / 3 = 3.33 (3 votes for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 7.00
        assertEq(_clearNativeBalance(builder), 7_083_333_333_333_333_333);

        // THEN gauge2 builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 1 / 4 = 12.5
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 0
        // cycle 5 = 50 * 1 / 3 = 16.66 (1 vote for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 29.16
        assertEq(_clearERC20Balance(builder2Receiver), 29_166_666_666_666_666_667);
        // THEN gauge2 builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 1 / 4 = 1.25
        // cycle 3 = 0 (shares are not updated since there are is no distribution)
        // cycle 4 = 0
        // cycle 5 = 5 * 1 / 3 = 1.66 (1 vote for half of cycle 2 and 1 vote por half of cycle 3)
        // total = 2.91
        assertEq(_clearNativeBalance(builder2Receiver), 2_916_666_666_666_666_667);
    }

    /**
     * SCENARIO: if there is a skipped distribution and builder gets self paused and self unpaused,
     * incentives are not lost
     * - There is a builder with no allocations that receives an incentive
     * - Builder gets self paused
     * - A distribution is skipped and builder can't self unpause
     * - There is a distribution with no rewards and builder unpauses himself
     * - There are votes for builder
     * - Rewards are not lost and can be claimed by sponsors and builder
     */
    function test_integration_NoDistributionAndSelfPausedIncentivizedBuilder() public {
        // CYCLE 1
        // GIVEN bob allocates to gauge2 - this way there are allocations
        vm.prank(bob);
        backersManager.allocate(gauge2, 1 ether);

        // CYCLE 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // AND half an cycle passes
        _skipRemainingCycleFraction(2);

        // AND builder (gauge) pauses itself
        vm.prank(builder);
        builderRegistry.pauseSelf();

        // CYCLE 3
        // AND cycle finishes without a distribution
        _skipAndStartNewCycle();

        // THEN builder can't self unpause before distribution
        vm.expectRevert(BackersManagerRootstockCollective.BeforeDistribution.selector);
        vm.prank(builder);
        builderRegistry.unpauseSelf(0.5 ether);

        // CYCLE 4
        // AND there is a distribution
        _distribute(0, 0);

        // AND builder unpauses himself again
        vm.prank(builder);
        builderRegistry.unpauseSelf(0.5 ether);

        // AND alice allocates to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);

        // CYCLE 5
        // AND there is a distribution
        _distribute(0, 0);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 6
        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // cycle 5 = 100 (missingRewards)
        // total = 100
        assertEq(_clearERC20Balance(alice), 99_999_999_999_999_999_999);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives 0 rewardToken since it only got incentives for sponsors
        assertEq(_clearERC20Balance(builder), 0);
    }

    /**
     * SCENARIO: if there is a skipped distribution and builder gets self paused and self unpaused,
     * incentives and rewards from distribution are not lost
     * - A distribution is skipped and builder can't self unpause
     * - There is a distribution and builder self unpauses
     * - There is a distribution with no rewards and builder unpauses himself
     * - There are votes for builder
     * - Rewards are not lost and can be claimed by sponsors and builder
     */
    function test_integration_NoDistributionAndSelfPausedIncentivizedandRewardsBuilder() public {
        // CYCLE 1
        // GIVEN bob allocates to gauge2 - this way there are allocations
        vm.prank(bob);
        backersManager.allocate(gauge2, 1 ether);

        // CYCLE 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100 ether, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // AND half an cycle passes
        _skipRemainingCycleFraction(2);

        // AND builder (gauge) gets self paused
        vm.prank(builder);
        builderRegistry.pauseSelf();

        // CYCLE 3
        // AND cycle finishes without a distribution
        _skipAndStartNewCycle();
        // CYCLE 4
        // AND there is a distribution
        _distribute(0, 0);

        // AND builder is self unpaused again
        vm.prank(builder);
        builderRegistry.unpauseSelf(0.5 ether);

        // AND alice allocates to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);

        // CYCLE 5
        // AND there is a distribution
        _distribute(100 ether, 0 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 6
        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives rewardToken
        // cycle 1 = 50
        // cycle 5 = 50 / 2 * 1 = 25
        // total = 75
        assertEq(_clearERC20Balance(bob), 74_999_999_999_999_999_998);

        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives rewardToken
        // cycle 2 = 100 (incentive)
        // cycle 5 = 50 / 2 * 1 = 25
        // total = 125
        assertEq(_clearERC20Balance(alice), 124_999_999_999_999_999_998);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // cycle 5 = 50 / 2 = 25
        assertEq(_clearERC20Balance(builder), 25_000_000_000_000_000_000);
        // THEN gauge builder receives rewardToken
        // cycle 1 = 50
        // cycle 5 = 50 / 2
        // total = 75
        assertEq(_clearERC20Balance(builder2Receiver), 75_000_000_000_000_000_000);
    }

    /**
     * SCENARIO: voting on cycle with skipped distribution an deallocating on same cycle
     * makes sponsor earn no rewards
     * - There is a builder with no allocations that receives an incentive
     * - Next cycle starts without a distribution
     * - Alice allocates to gauge and deallocates in the same cycle that had no distribution
     * - There is a distribution an alice gets no rewards
     */
    function test_integration_NoDistributionAndAllocAndDeallocOnSameCycle() public {
        // CYCLE 1
        // GIVEN bob allocates to gauge - this way there are allocations
        vm.prank(bob);
        backersManager.allocate(gauge2, 1 ether);

        // CYCLE 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // CYCLE 3
        // AND cycle finishes
        _skipAndStartNewCycle();

        // AND alice allocates to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);

        // AND half an cycle passes
        _skipRemainingCycleFraction(2);
        // AND alice deallocates all votes
        vm.prank(alice);
        backersManager.allocate(gauge, 0 ether);

        // CYCLE 4
        // AND there is a distribution
        _distribute(100, 0);

        //CYCLE 5
        _skipAndStartNewCycle();

        // THEN alice gets no rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        assertEq(_clearERC20Balance(alice), 0);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives 0 rewardToken since it only got incentives
        assertEq(_clearERC20Balance(builder), 17);
    }

    /**
     * SCENARIO: voting on cycle with skipped distribution an deallocating on next cycle before next
     *    distribution makes sponsor earn no rewards
     * - There is a builder with no allocations that receives an incentive
     * - Next cycle starts without a distribution
     * - Alice allocates to gauge in cycle without distribution and deallocates in the beginning of next
     *      one before distribution
     * - There is a distribution an alice gets no rewards
     */
    function test_integration_NoDistributionAndDeAllocationBeforeNextDistribution() public {
        // CYCLE 1
        // GIVEN bob allocates to gauge - this way there are allocations
        vm.prank(bob);
        backersManager.allocate(gauge2, 1 ether);

        // CYCLE 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100 ether, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // CYCLE 3
        // AND cycle finishes
        _skipAndStartNewCycle();

        // AND alice allocates to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);

        // CYCLE 4
        // AND cycle finishes
        _skipAndStartNewCycle();

        // AND alice deallocates all votes
        vm.prank(alice);
        backersManager.allocate(gauge, 0 ether);

        // CYCLE 5
        // AND there is a distribution
        _distribute(100 ether, 0);

        // CYCLE 6
        // AND cycle finishes
        _skipAndStartNewCycle();

        // THEN alice gets no rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        assertEq(_clearERC20Balance(alice), 0);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives 0 rewardToken since it only got incentives
        assertEq(_clearERC20Balance(builder), 0);
    }

    /**
     * SCENARIO: there is an cycle without distribution and builders that get votes on cycle
     *   without distribution get shares as if the were voting from the previous cycle
     * - There is a vote for builder 1 on first cycle
     * - The next cycle starts and builder2 get a vote
     * - Distribution is skipped and next cycle starts with a distribution
     * - Both builders with same amount of votes get same rewards even though builder 1
     *   got votes on first cycle and builder2 on second cycle
     */
    function test_integration_NoDistributionOnCycleVotingIncentive() public {
        // CYCLE 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge
        vm.prank(alice);
        backersManager.allocate(gauge, 1 ether);

        // CYCLE 2
        // AND new cycle starts without a distribution
        _skipAndStartNewCycle();

        // AND bob votes to gauge2
        vm.prank(bob);
        backersManager.allocate(gauge2, 1 ether);

        // CYCLE 3
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 4
        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 0
        // cycle 3 = 50 * 1 / 2 = 25
        // total = 25
        assertEq(_clearERC20Balance(builder), 25_000_000_000_000_000_000);
        // THEN gauge builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 0
        // cycle 3 = 5 * 1 / 2 = 2.5
        // total = 2.5
        assertEq(_clearNativeBalance(builder), 2_500_000_000_000_000_000);

        // THEN gauge2 builder receives rewardToken
        // cycle 1 = 0
        // cycle 2 = 0
        // cycle 3 = 50 * 1 / 2 = 25
        // total = 25
        assertEq(_clearERC20Balance(builder2Receiver), 25_000_000_000_000_000_000);
        // THEN gauge2 builder receives native tokens
        // cycle 1 = 0
        // cycle 2 = 0
        // cycle 3 = 5 * 1 / 2 = 2.5
        // total = 2.5
        assertEq(_clearNativeBalance(builder2Receiver), 2_500_000_000_000_000_000);
    }

    /**
     * SCENARIO: distribution starts in one cycle and finishes in the next one so rewards don't
     *  get properly updated
     * - There are allocations on first cycle and enough gauges to require pagination
     * - Distribution starts but does not finish
     * - Next cycle starts and distribution finishes
     * - Sponsors get more rewards than they should
     */
    function test_integration_PaginatedDistributionNotFinishedOnCycle() public {
        // CYCLE 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        backersManager.allocate(gauge, 1 ether);
        backersManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        backersManager.allocate(gauge, 2 ether);

        //  AND 20 more gauges are created - 22 in total with _MAX_DISTRIBUTIONS_PER_BATCH = 20;
        for (uint256 i = 0; i < 20; i++) {
            GaugeRootstockCollective _newGauge =
                _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            gaugesArray.push(_newGauge);
        }

        // CYCLE 2
        // AND distribution of 100 rewardToken and 10 native tokens starts
        _skipToStartDistributionWindow();
        vm.deal(address(rewardDistributor), 10 ether + address(rewardDistributor).balance);
        rewardToken.mint(address(rewardDistributor), 100 ether);
        usdrifRewardToken.mint(address(rewardDistributor), 100 ether);
        vm.prank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(100 ether, 0, 10 ether);

        // THEN distribution is ongoing
        assertTrue(backersManager.onDistributionPeriod());
        // CYCLE 3
        // AND cycle finishes with distribution ongoing
        _skipAndStartNewCycle();

        // AND distribution finishes in next cycle - and no new distribution
        backersManager.distribute();

        // THEN distribution is no longer ongoing
        assertFalse(backersManager.onDistributionPeriod());

        // CYCLE 4
        // AND 100 rewardTokens and 10 native tokens are distributed in next cycle
        _distribute(100 ether, 10 ether);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // CYCLE 5
        // WHEN alice claims the rewards
        vm.prank(alice);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN alice receives more rewardToken than she should
        // cycle 1 = 0
        // cycle 2 = 50 * 2 / 4 = 25
        // cycle 3 = 50 * 2 / 4 = 25 (should not have received this rewards)
        // cycle 4 = 50 * 2 / 4 = 25
        // total = 75
        assertEq(_clearERC20Balance(alice), 74_999_999_999_999_999_996);
        // THEN alice receives more native tokens than she should
        // cycle 1 = 0
        // cycle 2 = 5 * 2 / 4 = 2.5
        // cycle 3 = 5 * 2 / 4 = 2.5 (should not have received this rewards)
        // cycle 4 = 5 * 2 / 4 = 2.5
        // total = 7.5
        assertEq(_clearNativeBalance(alice), 7_499_999_999_999_999_996);

        // WHEN bob claims the rewards
        vm.prank(bob);
        backersManager.claimBackerRewards(gaugesArray);
        // THEN bob receives more rewardToken than he should
        // cycle 1 = 0
        // cycle 2 = 50 * 2 / 4 = 25
        // cycle 3 = 50 * 2 / 4 = 25 (should not have received these rewards)
        // cycle 4 = 50 * 2 / 4 = 25
        // total = 75
        assertEq(_clearERC20Balance(bob), 74_999_999_999_999_999_996);
        // THEN bob receives more native tokens than he should
        // cycle 1 = 0
        // cycle 2 = 5 * 2 / 4 = 2.5
        // cycle 3 = 5 * 2 / 4 = 2.5 (should not have received these rewards)
        // cycle 4 = 5 * 2 / 4 = 2.5
        // total = 7.5
        assertEq(_clearNativeBalance(bob), 7_499_999_999_999_999_996);

        // THEN gauge builder has earned rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 3 / 4 = 37.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 50 * 3 / 4 = 37.5
        // total = 75
        assertEq(gauge.builderRewards(address(rewardToken)), 75_000_000_000_000_000_000);
        // THEN gauge builder has earned native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 3 / 4 = 3.75
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 50 * 3 / 4 = 37.5
        // total = 7.5
        assertEq(gauge.builderRewards(UtilsLib._NATIVE_ADDRESS), 7_500_000_000_000_000_000);
        // THEN gauge2 builder has earned rewardToken
        // cycle 1 = 0
        // cycle 2 = 50 * 1 / 4 = 12.5
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 50 * 1 / 4 = 12.5
        // total = 25
        assertEq(gauge2.builderRewards(address(rewardToken)), 25_000_000_000_000_000_000);
        // THEN gauge2 builder has earned native tokens
        // cycle 1 = 0
        // cycle 2 = 5 * 1 / 4 = 1.25
        // cycle 3 = 0 (no new distribution)
        // cycle 4 = 5 * 1 / 4 = 1.25
        // total = 2.5
        assertEq(gauge2.builderRewards(UtilsLib._NATIVE_ADDRESS), 2_500_000_000_000_000_000);

        // WHEN builder claims rewards
        //  THEN there is not enough balance
        vm.prank(builder);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(gauge), 37_500_000_000_000_000_006, 75 ether
            )
        );
        gauge.claimBuilderReward();
        // WHEN builder2 claims rewards
        //  THEN there is not enough balance
        vm.prank(builder2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(gauge2), 12_500_000_000_000_000_002, 25 ether
            )
        );
        gauge2.claimBuilderReward();
    }
}
