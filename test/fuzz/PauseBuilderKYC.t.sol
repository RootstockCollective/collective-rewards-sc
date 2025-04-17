// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseFuzz } from "./BaseFuzz.sol";
import { BuilderRegistryRootstockCollective } from "../../src/builderRegistry/BuilderRegistryRootstockCollective.sol";

contract PauseBuilderKYCFuzzTest is BaseFuzz {
    mapping(address builder_ => bool paused_) public pausedBuilders;

    /**
     * SCENARIO: In a random time gauges are KYC paused and unpaused again.
     *  There is a distribution, all the gauges receive rewards
     */
    function testFuzz_PauseBuilderKYC(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, 2 * cycleDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        /// AND a random time passes
        skip(randomTime_);

        // AND pause randomly
        _randomPause(seed_);

        // AND a random time passes
        skip(randomTime_);

        // AND unpause randomly
        _randomUnpause(seed_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND unpaused builders claims their rewards
        for (uint256 i = 0; i < builders.length; i++) {
            if (!pausedBuilders[builders[i]]) {
                vm.prank(builders[i]);
                gaugesArray[i].claimBuilderReward();
                // THEN they receive the rewards after deducting the backers reward percentage
                assertApproxEqAbs(
                    rewardToken.balanceOf(builders[i]), _calcBuilderReward(RT_DISTRIBUTION_AMOUNT, i), 100
                );
                assertApproxEqAbs(builders[i].balance, _calcBuilderReward(CB_DISTRIBUTION_AMOUNT, i), 100);
            } else {
                vm.prank(builders[i]);
                // THEN tx reverts because builder rewards are locked
                vm.expectRevert(BuilderRegistryRootstockCollective.BuilderRewardsLocked.selector);
                gaugesArray[i].claimBuilderReward();
            }
        }

        // AND cycle finishes
        _skipAndStartNewCycle();

        // WHEN backers claim their rewards
        for (uint256 i = 0; i < backersArray.length; i++) {
            vm.prank(backersArray[i]);
            backersManager.claimBackerRewards(backersGauges[i]);

            // THEN they receive the rewards
            assertApproxEqAbs(
                rewardToken.balanceOf(backersArray[i]), _calcBackerReward(RT_DISTRIBUTION_AMOUNT, i), 0.000000001 ether
            );
            assertApproxEqAbs(backersArray[i].balance, _calcBackerReward(CB_DISTRIBUTION_AMOUNT, i), 0.000000001 ether);
        }
    }

    /**
     * SCENARIO: In a random time gauges are KYC paused and unpaused again. There is a distribution in the middle
     *  There is a distribution, all the gauges receive rewards
     */
    function testFuzz_PauseBuilderKYCWitDistribution(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, 2 * cycleDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        /// AND a random time passes
        skip(randomTime_);

        // AND pause randomly
        _randomPause(seed_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND a random time passes
        skip(randomTime_);

        // AND unpause randomly
        _randomUnpause(seed_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND unpaused builders claims their rewards
        for (uint256 i = 0; i < builders.length; i++) {
            if (!pausedBuilders[builders[i]]) {
                vm.prank(builders[i]);
                gaugesArray[i].claimBuilderReward();
                // THEN they receive the rewards after deducting the backers reward percentage
                assertApproxEqAbs(
                    rewardToken.balanceOf(builders[i]), _calcBuilderReward(RT_DISTRIBUTION_AMOUNT * 2, i), 100
                );
                assertApproxEqAbs(builders[i].balance, _calcBuilderReward(CB_DISTRIBUTION_AMOUNT * 2, i), 100);
            } else {
                vm.prank(builders[i]);
                // THEN tx reverts because builder rewards are locked
                vm.expectRevert(BuilderRegistryRootstockCollective.BuilderRewardsLocked.selector);
                gaugesArray[i].claimBuilderReward();
            }
        }

        // AND cycle finishes
        _skipAndStartNewCycle();

        // WHEN backers claim their rewards
        for (uint256 i = 0; i < backersArray.length; i++) {
            vm.prank(backersArray[i]);
            backersManager.claimBackerRewards(backersGauges[i]);

            // THEN they receive the rewards
            assertApproxEqAbs(
                rewardToken.balanceOf(backersArray[i]),
                _calcBackerReward(RT_DISTRIBUTION_AMOUNT * 2, i),
                0.000000001 ether
            );
            assertApproxEqAbs(
                backersArray[i].balance, _calcBackerReward(CB_DISTRIBUTION_AMOUNT * 2, i), 0.000000001 ether
            );
        }
    }

    function _randomPause(uint256 seed_) internal {
        for (uint256 i = 0; i < builders.length; i++) {
            uint256 _random = uint256(keccak256(abi.encodePacked(seed_, i)));
            // 70% chance to pause
            if (_random % 10 > 2) {
                vm.prank(kycApprover);
                builderRegistry.pauseBuilderKYC(builders[i], "pause");
                pausedBuilders[builders[i]] = true;
            }
        }
    }

    function _randomUnpause(uint256 seed_) internal {
        for (uint256 i = 0; i < builders.length; i++) {
            uint256 _random = uint256(keccak256(abi.encodePacked(seed_, i, i)));
            // 70% chance to unpause
            if (pausedBuilders[builders[i]] && _random % 10 > 2) {
                vm.prank(kycApprover);
                builderRegistry.unpauseBuilderKYC(builders[i]);
                pausedBuilders[builders[i]] = false;
            }
        }
    }
}
