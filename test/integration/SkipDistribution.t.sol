// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, SponsorsManager, Gauge } from "../BaseTest.sol";
import { UtilsLib } from "../../src/libraries/UtilsLib.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract SkipDistribution is BaseTest {
    function _setUp() internal override {
        // start from a new epoch
        _skipAndStartNewEpoch();
    }

    /**
     * SCENARIO: there is an epoch without distribution.
     * - There are allocations on first epoch
     * - There is a distribution for next epoch and sponsors start to earn rewards
     * - Epoch finishes but there is no distribution during distribution window
     * - Sponsors and builders can still claim rewards from previous epoch
     * - There are new allocations in epoch without distribution
     * - New epoch starts and there is a distribution
     * - Sponsors and builders are able to claim rewards for previous epochs
     */
    function test_integration_NoDistributionOnEpoch() public {
        // EPOCH 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        sponsorsManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 2 ether);

        // EPOCH 2
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);

        // EPOCH 3
        // AND new epoch finishes
        _skipAndStartNewEpoch();
        // AND distribution window ends without a new distribution
        _skipToEndDistributionWindow();
        // AND bob votes to gauge2
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 1 ether);

        // EPOCH 4
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 5
        // WHEN alice claims the rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN alice receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 2 / 4 = 25
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 50 * 2 / 5 = 20
        // total = 45
        assertEq(_clearERC20Balance(alice), 44_994_040_524_433_849_818);
        // THEN alice receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 2 / 4 = 2.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 5 * 2 / 5 ) = 2
        // total = 4.5
        assertEq(_clearCoinbaseBalance(alice), 4_499_404_052_443_384_978);

        // WHEN bob claims the rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN bob receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 2 / 4 = 25
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 50 * 3 / 5 = 30
        // total = 55
        assertEq(_clearERC20Balance(bob), 55_005_959_475_566_150_175);
        // THEN bob receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 2 / 4 = 2.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 5 * 3 / 5 ) = 3
        // total = 5.5
        assertEq(_clearCoinbaseBalance(bob), 5_500_595_947_556_615_013);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 3 / 4 = 37.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 50 * 3 / 5 = 30
        // total = 67.5
        assertEq(_clearERC20Balance(builder), 67_535_756_853_396_901_073);
        // THEN gauge builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 3 / 4 = 3.75
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 5 * 3 / 5 = 3
        // total = 6.75
        assertEq(_clearCoinbaseBalance(builder), 6_753_575_685_339_690_107);

        // THEN gauge2 builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 1 / 4 = 12.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 50 * 2 / 5 = 20
        // total = 32.5
        assertEq(_clearERC20Balance(builder2Receiver), 32_464_243_146_603_098_927);
        // THEN gauge2 builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 1 / 4 = 1.25
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 5 * 2 / 5 = 2
        // total = 3.25
        assertEq(_clearCoinbaseBalance(builder2Receiver), 3_246_424_314_660_309_893);
    }

    /**
     * SCENARIO: there is an epoch without distribution.
     * - There are allocations on first epoch
     * - There is a distribution for next epoch and sponsors start to earn rewards
     * - There are no distribution in two consecutive epochs
     * - Sponsors and builders can still claim rewards from previous epochs
     * - There are new allocations in epoch without distribution
     * - New epoch starts and there is a distribution
     * - Sponsors and builders are able to claim rewards for every epoch
     */
    function test_integration_NoDistributionOnConsecutiveEpochs() public {
        // EPOCH 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        sponsorsManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 2 ether);

        // EPOCH 2
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);

        // EPOCH 3
        // AND new epoch finishes
        _skipAndStartNewEpoch();
        // EPOCH 4
        // AND another new epoch finishes
        _skipAndStartNewEpoch();
        // AND distribution window ends without a new distribution
        _skipToEndDistributionWindow();
        // AND bob votes to gauge2
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 1 ether);

        // EPOCH 5
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 6
        // WHEN alice claims the rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN alice receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 2 / 4 = 25
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 50 * 2 / 5 = 20
        // total = 45
        assertEq(_clearERC20Balance(alice), 44_994_040_524_433_849_818);
        // THEN alice receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 2 / 4 = 2.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 5 * 2 / 5 ) = 2
        // total = 4.5
        assertEq(_clearCoinbaseBalance(alice), 4_499_404_052_443_384_978);

        // WHEN bob claims the rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN bob receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 2 / 4 = 25
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 50 * 3 / 5 = 30
        // total = 55
        assertEq(_clearERC20Balance(bob), 55_005_959_475_566_150_175);
        // THEN bob receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 2 / 4 = 2.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 5 * 3 / 5 = 3
        // total = 5.5
        assertEq(_clearCoinbaseBalance(bob), 5_500_595_947_556_615_013);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 3 / 4 = 37.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 50 * 3 / 5 = 30
        // total = 67.5
        assertEq(_clearERC20Balance(builder), 67_535_756_853_396_901_073);
        // THEN gauge builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 3 / 4 = 3.75
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 5 * 3 / 5 = 3
        // total = 6.75
        assertEq(_clearCoinbaseBalance(builder), 6_753_575_685_339_690_107);

        // THEN gauge2 builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 1 / 4 = 12.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 50 * 2 / 5 = 20
        // total = 32.5
        assertEq(_clearERC20Balance(builder2Receiver), 32_464_243_146_603_098_927);
        // THEN gauge2 builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 1 / 4 = 1.25
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 0 (no new distribution)
        // epoch 5 = 5 * 2 / 5 = 2
        // total = 3.25
        assertEq(_clearCoinbaseBalance(builder2Receiver), 3_246_424_314_660_309_893);
    }

    /**
     * SCENARIO: there is an epoch without distribution and missing rewards.
     * - There are allocations in first epoch
     * - There is a distribution for next epoch
     * - There is a complete deallocation at the middle of the epoch (so there will be missing rewards)
     * - Epoch finishes but there is no distribution during distribution window
     * - There is an allocation in the middle of the new epoch
     * - There is a distribution in following epoch - missing rewards were not lost
     */
    function test_integration_NoDistributionAndMissingRewards() public {
        // EPOCH 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        sponsorsManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 2 ether);

        // EPOCH 2
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);
        // AND half an epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice removes all votes
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0 ether);
        sponsorsManager.allocate(gauge2, 0 ether);
        vm.stopPrank();
        // AND bob removes all votes
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 0 ether);

        // EPOCH 3
        // AND new epoch finishes
        _skipAndStartNewEpoch();
        // AND half an epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice votes to gauge and gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        sponsorsManager.allocate(gauge2, 1 ether);
        vm.stopPrank();

        // EPOCH 4
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);
        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 5
        // WHEN alice claims the rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN alice receives rewardToken
        // epoch 1 = 0
        // epoch 2 = (50 / 2) * 2 / 4 = 12.5
        // epoch 3 = (50 / 2) * 2 / 2 = 25 (missingRewards)
        // epoch 4 = 50 * 2 / 2 = 50
        // total = 87.5
        assertEq(_clearERC20Balance(alice), 87_499_999_999_999_999_995);
        // THEN alice receives coinbase
        // epoch 1 = 0
        // epoch 2 = (5 / 2) * 2 / 4 = 1.25
        // epoch 3 = (5 / 2) * 2 / 2 = 2.5 (missingRewards)
        // epoch 4 = 5 * 2 / 2 = 5
        // total = 8.75
        assertEq(_clearCoinbaseBalance(alice), 8_749_999_999_999_999_995);

        // WHEN bob claims the rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN bob receives rewardToken
        // epoch 1 = 0
        // epoch 2 = (50 / 2) * 2 / 4 = 12.5
        // epoch 3 = 0
        // epoch 4 = 0
        // total = 12.5
        assertEq(_clearERC20Balance(bob), 12_499_999_999_999_999_998);
        // THEN bob receives coinbase
        // epoch 1 = 0
        // epoch 2 = (5 / 2) * 2 / 4 = 1.25
        // epoch 3 = 0
        // epoch 4 = 0
        // total = 1.25
        assertEq(_clearCoinbaseBalance(bob), 1_249_999_999_999_999_998);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 3 / 4 = 37.5
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 50 * 2 / 3 = 33.33 (3 votes for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 70.08
        assertEq(_clearERC20Balance(builder), 70_833_333_333_333_333_333);
        // THEN gauge builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 3 / 4 = 3.75
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 5 * 2 / 3 = 3.33 (3 votes for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 7.00
        assertEq(_clearCoinbaseBalance(builder), 7_083_333_333_333_333_333);

        // THEN gauge2 builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 1 / 4 = 12.5
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 50 * 1 / 3 = 16.66 (1 vote for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 29.16
        assertEq(_clearERC20Balance(builder2Receiver), 29_166_666_666_666_666_667);
        // THEN gauge2 builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 1 / 4 = 1.25
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 5 * 1 / 3 = 1.66 (1 vote for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 2.91
        assertEq(_clearCoinbaseBalance(builder2Receiver), 2_916_666_666_666_666_667);
    }

    /**
     * SCENARIO: there are two consecutive epochs without distribution.
     * - There are allocations in first epoch
     * - There is a distribution for next epoch
     * - There is a complete deallocation at the middle of the epoch (so there will be missing rewards)
     * - Epoch finishes but there is no distribution during distribution window
     * - There is an allocation in the middle of the next epoch and no distribution
     * - There is a distribution in following epoch - missing rewards were not lost
     */
    function test_integration_NoDistributionOnConsecutiveEpochsAndMissingRewards() public {
        // EPOCH 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        sponsorsManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 2 ether);

        // EPOCH 2
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);
        // AND half an epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice removes all votes
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 0 ether);
        sponsorsManager.allocate(gauge2, 0 ether);
        vm.stopPrank();
        // AND bob removes all votes
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 0 ether);

        // EPOCH 3
        // AND new epoch finishes
        _skipAndStartNewEpoch();
        // AND half an epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice votes to gauge and gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        sponsorsManager.allocate(gauge2, 1 ether);
        vm.stopPrank();

        // EPOCH 4
        // AND epoch finishes without distribution
        _skipAndStartNewEpoch();

        // EPOCH 5
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);
        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 6
        // WHEN alice claims the rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN alice receives rewardToken
        // epoch 1 = 0
        // epoch 2 = (50 / 2) * 2 / 4 = 12.5
        // epoch 3 = 0
        // epoch 4 = (50 / 2) * 2 / 2 = 25 (missingRewards)
        // epoch 5 = 50 * 2 / 2 = 50
        // total = 87.5
        assertEq(_clearERC20Balance(alice), 87_499_999_999_999_999_995);
        // THEN alice receives coinbase
        // epoch 1 = 0
        // epoch 2 = (5 / 2) * 2 / 4 = 1.25
        // epoch 3 = 0
        // epoch 4 = (5 / 2) * 2 / 2 = 2.5 (missingRewards)
        // epoch 5 = 5 * 2 / 2 = 5
        // total = 8.75
        assertEq(_clearCoinbaseBalance(alice), 8_749_999_999_999_999_995);

        // WHEN bob claims the rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN bob receives rewardToken
        // epoch 1 = 0
        // epoch 2 = (50 / 2) * 2 / 4 = 12.5
        // epoch 3 = 0
        // epoch 4 = 0
        // epoch 5 = 0
        // total = 12.5
        assertEq(_clearERC20Balance(bob), 12_499_999_999_999_999_998);
        // THEN bob receives coinbase
        // epoch 1 = 0
        // epoch 2 = (50 / 2) * 2 / 4 = 1.25
        // epoch 3 = 0
        // epoch 4 = 0
        // epoch 5 = 0
        // total = 1.25
        assertEq(_clearCoinbaseBalance(bob), 1_249_999_999_999_999_998);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 3 / 4 = 37.5
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 0
        // epoch 5 = 50 * 2 / 3 = 33.33 (3 votes for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 70.08
        assertEq(_clearERC20Balance(builder), 70_833_333_333_333_333_333);
        // THEN gauge builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 3 / 4 = 3.75
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 0
        // epoch 5 = 5 * 2 / 3 = 3.33 (3 votes for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 7.00
        assertEq(_clearCoinbaseBalance(builder), 7_083_333_333_333_333_333);

        // THEN gauge2 builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 1 / 4 = 12.5
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 0
        // epoch 5 = 50 * 1 / 3 = 16.66 (1 vote for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 29.16
        assertEq(_clearERC20Balance(builder2Receiver), 29_166_666_666_666_666_667);
        // THEN gauge2 builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 1 / 4 = 1.25
        // epoch 3 = 0 (shares are not updated since there are is no distribution)
        // epoch 4 = 0
        // epoch 5 = 5 * 1 / 3 = 1.66 (1 vote for half of epoch 2 and 1 vote por half of epoch 3)
        // total = 2.91
        assertEq(_clearCoinbaseBalance(builder2Receiver), 2_916_666_666_666_666_667);
    }

    /**
     * SCENARIO: if there is a skipped distribution and builder gets revoked and permitted,
     * incentives are not lost
     * - There is a builder with no allocations that receives an incentive
     * - Builder gets revoked
     * - A distribution is skipped and builder can't be permitted
     * - There is a distribution with no rewards and builder gets permitted
     * - There are votes for builder
     * - Rewards are not lost and can be claimed by sponsors and builder
     */
    function test_integration_NoDistributionAndRevokedIncentivizedBuilder() public {
        // EPOCH 1
        // GIVEN bob allocates to gauge2 - this way there are allocations
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 1 ether);

        // EPOCH 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // AND half an epoch passes
        _skipRemainingEpochFraction(2);

        // AND builder (gauge) gets revoked
        vm.prank(builder);
        sponsorsManager.revokeBuilder();

        // EPOCH 3
        // AND epoch finishes without a distribution
        _skipAndStartNewEpoch();

        // THEN builder can't be permitted before distribution
        vm.expectRevert(SponsorsManager.BeforeDistribution.selector);
        vm.prank(builder);
        sponsorsManager.permitBuilder(0.5 ether);

        // EPOCH 4
        // AND there is a distribution
        _distribute(0, 0);

        // AND builder is permitted again
        vm.prank(builder);
        sponsorsManager.permitBuilder(0.5 ether);

        // AND alice allocates to gauge
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // EPOCH 5
        // AND there is a distribution
        _distribute(0, 0);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 6
        // WHEN alice claims the rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN alice receives rewardToken
        // epoch 5 = 100 (missingRewards)
        // total = 100
        assertEq(_clearERC20Balance(alice), 99_999_999_999_999_999_999);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives 0 rewardToken since it only got incentives for sponsors
        assertEq(_clearERC20Balance(builder), 0);
    }

    /**
     * SCENARIO: if there is a skipped distribution and builder gets revoked and permitted,
     * incentives and rewards from distribution are not lost
     * - A distribution is skipped and builder can't be permitted
     * - There is a distribution and builder gets permitted
     * - There is a distribution with no rewards and builder gets permitted
     * - There are votes for builder
     * - Rewards are not lost and can be claimed by sponsors and builder
     */
    function test_integration_NoDistributionAndRevokedIncentivizedandRewardsBuilder() public {
        // EPOCH 1
        // GIVEN bob allocates to gauge2 - this way there are allocations
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 1 ether);

        // EPOCH 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100 ether, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // AND half an epoch passes
        _skipRemainingEpochFraction(2);

        // AND builder (gauge) gets revoked
        vm.prank(builder);
        sponsorsManager.revokeBuilder();

        // EPOCH 3
        // AND epoch finishes without a distribution
        _skipAndStartNewEpoch();
        // EPOCH 4
        // AND there is a distribution
        _distribute(0, 0);

        // AND builder is permitted again
        vm.prank(builder);
        sponsorsManager.permitBuilder(0.5 ether);

        // AND alice allocates to gauge
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // EPOCH 5
        // AND there is a distribution
        _distribute(100 ether, 0 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 6
        // WHEN bob claims the rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN bob receives rewardToken
        // epoch 1 = 50
        // epoch 5 = 50 / 2 * 1 = 25
        // total = 75
        assertEq(_clearERC20Balance(bob), 74_999_999_999_999_999_998);

        // WHEN alice claims the rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN alice receives rewardToken
        // epoch 2 = 100 (incentive)
        // epoch 5 = 50 / 2 * 1 = 25
        // total = 125
        assertEq(_clearERC20Balance(alice), 124_999_999_999_999_999_998);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // epoch 5 = 50 / 2 = 25
        assertEq(_clearERC20Balance(builder), 25_000_000_000_000_000_000);
        // THEN gauge builder receives rewardToken
        // epoch 1 = 50
        // epoch 5 = 50 / 2
        // total = 75
        assertEq(_clearERC20Balance(builder2Receiver), 75_000_000_000_000_000_000);
    }

    /**
     * SCENARIO: voting on epoch with skipped distribution an deallocating on same epoch
     * makes sponsor earn no rewards
     * - There is a builder with no allocations that receives an incentive
     * - Next epoch starts without a distribution
     * - Alice allocates to gauge and deallocates in the same epoch that had no distribution
     * - There is a distribution an alice gets no rewards
     */
    function test_integration_NoDistributionAndAllocAndDeallocOnSameEpoch() public {
        // EPOCH 1
        // GIVEN bob allocates to gauge - this way there are allocations
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 1 ether);

        // EPOCH 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // EPOCH 3
        // AND epoch finishes
        _skipAndStartNewEpoch();

        // AND alice allocates to gauge
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // AND half an epoch passes
        _skipRemainingEpochFraction(2);
        // AND alice deallocates all votes
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0 ether);

        // EPOCH 4
        // AND there is a distribution
        _distribute(100, 0);

        //EPOCH 5
        _skipAndStartNewEpoch();

        // THEN alice gets no rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        assertEq(_clearERC20Balance(alice), 0);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives 0 rewardToken since it only got incentives
        assertEq(_clearERC20Balance(builder), 17);
    }

    /**
     * SCENARIO: voting on epoch with skipped distribution an deallocating on next epoch before next
     *    distribution makes sponsor earn no rewards
     * - There is a builder with no allocations that receives an incentive
     * - Next epoch starts without a distribution
     * - Alice allocates to gauge in epoch without distribution and deallocates in the beginning of next
     *      one before distribution
     * - There is a distribution an alice gets no rewards
     */
    function test_integration_NoDistributionAndDeAllocationBeforeNextDistribution() public {
        // EPOCH 1
        // GIVEN bob allocates to gauge - this way there are allocations
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 1 ether);

        // EPOCH 2
        // AND there is a distribution - won't affect gauge, only gauge2
        _distribute(100 ether, 0);

        // AND gauge is incentivized
        _incentivize(gauge, 100 ether, 0);

        // EPOCH 3
        // AND epoch finishes
        _skipAndStartNewEpoch();

        // AND alice allocates to gauge
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // EPOCH 4
        // AND epoch finishes
        _skipAndStartNewEpoch();

        // AND alice deallocates all votes
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0 ether);

        // EPOCH 5
        // AND there is a distribution
        _distribute(100 ether, 0);

        // EPOCH 6
        // AND epoch finishes
        _skipAndStartNewEpoch();

        // THEN alice gets no rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        assertEq(_clearERC20Balance(alice), 0);

        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives 0 rewardToken since it only got incentives
        assertEq(_clearERC20Balance(builder), 0);
    }

    /**
     * SCENARIO: there is an epoch without distribution and builders that get votes on epoch
     *   without distribution get shares as if the were voting from the previous epoch
     * - There is a vote for builder 1 on first epoch
     * - The next epoch starts and builder2 get a vote
     * - Distribution is skipped and next epoch starts with a distribution
     * - Both builders with same amount of votes get same rewards even though builder 1
     *   got votes on first epoch and builder2 on second epoch
     */
    function test_integration_NoDistributionOnEpochVotingIncentive() public {
        // EPOCH 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 1 ether);

        // EPOCH 2
        // AND new epoch starts without a distribution
        _skipAndStartNewEpoch();

        // AND bob votes to gauge2
        vm.prank(bob);
        sponsorsManager.allocate(gauge2, 1 ether);

        // EPOCH 3
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 4
        // WHEN all the builders claim
        _buildersClaim();
        // THEN gauge builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 0
        // epoch 3 = 50 * 1 / 2 = 25
        // total = 25
        assertEq(_clearERC20Balance(builder), 25_000_000_000_000_000_000);
        // THEN gauge builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 0
        // epoch 3 = 5 * 1 / 2 = 2.5
        // total = 2.5
        assertEq(_clearCoinbaseBalance(builder), 2_500_000_000_000_000_000);

        // THEN gauge2 builder receives rewardToken
        // epoch 1 = 0
        // epoch 2 = 0
        // epoch 3 = 50 * 1 / 2 = 25
        // total = 25
        assertEq(_clearERC20Balance(builder2Receiver), 25_000_000_000_000_000_000);
        // THEN gauge2 builder receives coinbase
        // epoch 1 = 0
        // epoch 2 = 0
        // epoch 3 = 5 * 1 / 2 = 2.5
        // total = 2.5
        assertEq(_clearCoinbaseBalance(builder2Receiver), 2_500_000_000_000_000_000);
    }

    /**
     * SCENARIO: distribution starts in one epoch and finishes in the next one so rewards don't
     *  get properly updated
     * - There are allocations on first epoch and enough gauges to require pagination
     * - Distribution starts but does not finish
     * - Next epoch starts and distribution finishes
     * - Sponsors get more rewards than they should
     */
    function test_integration_PaginatedDistributionNotFinishedOnEpoch() public {
        // EPOCH 1
        // GIVEN 2 gauges with 50% of kickback
        //  WHEN alice votes to gauge and gauge2
        vm.startPrank(alice);
        sponsorsManager.allocate(gauge, 1 ether);
        sponsorsManager.allocate(gauge2, 1 ether);
        vm.stopPrank();
        // AND bob votes to gauge
        vm.prank(bob);
        sponsorsManager.allocate(gauge, 2 ether);

        //  AND 20 more gauges are created - 22 in total with _MAX_DISTRIBUTIONS_PER_BATCH = 20;
        for (uint256 i = 0; i < 20; i++) {
            Gauge _newGauge = _whitelistBuilder(makeAddr(string(abi.encode(i + 10))), builder, 1 ether);
            gaugesArray.push(_newGauge);
        }

        // EPOCH 2
        // AND distribution of 100 rewardToken and 10 coinbase starts
        _skipToStartDistributionWindow();
        vm.deal(address(rewardDistributor), 10 ether + address(rewardDistributor).balance);
        rewardToken.mint(address(rewardDistributor), 100 ether);
        vm.prank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(100 ether, 10 ether);

        // THEN distribution is ongoing
        assertTrue(sponsorsManager.onDistributionPeriod());
        // EPOCH 3
        // AND epoch finishes with distribution ongoing
        _skipAndStartNewEpoch();

        // AND distribution finishes in next epoch - and no new distribution
        sponsorsManager.distribute();

        // THEN distribution is no longer ongoing
        assertFalse(sponsorsManager.onDistributionPeriod());

        // EPOCH 4
        // AND 100 rewardTokens and 10 coinbase are distributed in next epoch
        _distribute(100 ether, 10 ether);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // EPOCH 5
        // WHEN alice claims the rewards
        vm.prank(alice);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN alice receives more rewardToken than she should
        // epoch 1 = 0
        // epoch 2 = 50 * 2 / 4 = 25
        // epoch 3 = 50 * 2 / 4 = 25 (should not have received this rewards)
        // epoch 4 = 50 * 2 / 4 = 25
        // total = 75
        assertEq(_clearERC20Balance(alice), 74_999_999_999_999_999_996);
        // THEN alice receives more coinbase than she should
        // epoch 1 = 0
        // epoch 2 = 5 * 2 / 4 = 2.5
        // epoch 3 = 5 * 2 / 4 = 2.5 (should not have received this rewards)
        // epoch 4 = 5 * 2 / 4 = 2.5
        // total = 7.5
        assertEq(_clearCoinbaseBalance(alice), 7_499_999_999_999_999_996);

        // WHEN bob claims the rewards
        vm.prank(bob);
        sponsorsManager.claimSponsorRewards(gaugesArray);
        // THEN bob receives more rewardToken than he should
        // epoch 1 = 0
        // epoch 2 = 50 * 2 / 4 = 25
        // epoch 3 = 50 * 2 / 4 = 25 (should not have received these rewards)
        // epoch 4 = 50 * 2 / 4 = 25
        // total = 75
        assertEq(_clearERC20Balance(bob), 74_999_999_999_999_999_996);
        // THEN bob receives more coinbase than he should
        // epoch 1 = 0
        // epoch 2 = 5 * 2 / 4 = 2.5
        // epoch 3 = 5 * 2 / 4 = 2.5 (should not have received these rewards)
        // epoch 4 = 5 * 2 / 4 = 2.5
        // total = 7.5
        assertEq(_clearCoinbaseBalance(bob), 7_499_999_999_999_999_996);

        // THEN gauge builder has earned rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 3 / 4 = 37.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 50 * 3 / 4 = 37.5
        // total = 75
        assertEq(gauge.builderRewards(address(rewardToken)), 75_000_000_000_000_000_000);
        // THEN gauge builder has earned coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 3 / 4 = 3.75
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 50 * 3 / 4 = 37.5
        // total = 7.5
        assertEq(gauge.builderRewards(UtilsLib._COINBASE_ADDRESS), 7_500_000_000_000_000_000);
        // THEN gauge2 builder has earned rewardToken
        // epoch 1 = 0
        // epoch 2 = 50 * 1 / 4 = 12.5
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 50 * 1 / 4 = 12.5
        // total = 25
        assertEq(gauge2.builderRewards(address(rewardToken)), 25_000_000_000_000_000_000);
        // THEN gauge2 builder has earned coinbase
        // epoch 1 = 0
        // epoch 2 = 5 * 1 / 4 = 1.25
        // epoch 3 = 0 (no new distribution)
        // epoch 4 = 5 * 1 / 4 = 1.25
        // total = 2.5
        assertEq(gauge2.builderRewards(UtilsLib._COINBASE_ADDRESS), 2_500_000_000_000_000_000);

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
