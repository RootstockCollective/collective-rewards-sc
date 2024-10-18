// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseFuzz, Gauge } from "./BaseFuzz.sol";

contract PauseBuilderFuzzTest is BaseFuzz {
    mapping(address builder_ => bool paused_) public pausedBuilders;

    /**
     * SCENARIO: In a random time gauges are paused and unpaused again.
     *  There is a distribution, all the gauges receive rewards
     */
    function testFuzz_PauseBuilder(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, 2 * epochDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

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
                // THEN they receive the rewards after deducting the kickback for the sponsors
                assertApproxEqAbs(
                    rewardToken.balanceOf(builders[i]), _calcBuilderReward(RT_DISTRIBUTION_AMOUNT, i), 100
                );
                assertApproxEqAbs(builders[i].balance, _calcBuilderReward(CB_DISTRIBUTION_AMOUNT, i), 100);
            } else {
                vm.prank(builders[i]);
                // THEN tx reverts because builder rewards are locked
                vm.expectRevert(Gauge.BuilderRewardsLocked.selector);
                gaugesArray[i].claimBuilderReward();
            }
        }

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // WHEN sponsors claim their rewards
        for (uint256 i = 0; i < sponsorsArray.length; i++) {
            vm.prank(sponsorsArray[i]);
            sponsorsManager.claimSponsorRewards(sponsorsGauges[i]);

            // THEN they receive the rewards
            assertApproxEqAbs(
                rewardToken.balanceOf(sponsorsArray[i]),
                _calcSponsorReward(RT_DISTRIBUTION_AMOUNT, i),
                0.000000001 ether
            );
            assertApproxEqAbs(
                sponsorsArray[i].balance, _calcSponsorReward(CB_DISTRIBUTION_AMOUNT, i), 0.000000001 ether
            );
        }
    }

    /**
     * SCENARIO: In a random time gauges are paused and unpaused again. There is a distribution in the middle
     *  There is a distribution, all the gauges receive rewards
     */
    function testFuzz_PauseBuilderWitDistribution(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, 2 * epochDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

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
                // THEN they receive the rewards after deducting the kickback for the sponsors
                assertApproxEqAbs(
                    rewardToken.balanceOf(builders[i]), _calcBuilderReward(RT_DISTRIBUTION_AMOUNT * 2, i), 100
                );
                assertApproxEqAbs(builders[i].balance, _calcBuilderReward(CB_DISTRIBUTION_AMOUNT * 2, i), 100);
            } else {
                vm.prank(builders[i]);
                // THEN tx reverts because builder rewards are locked
                vm.expectRevert(Gauge.BuilderRewardsLocked.selector);
                gaugesArray[i].claimBuilderReward();
            }
        }

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // WHEN sponsors claim their rewards
        for (uint256 i = 0; i < sponsorsArray.length; i++) {
            vm.prank(sponsorsArray[i]);
            sponsorsManager.claimSponsorRewards(sponsorsGauges[i]);

            // THEN they receive the rewards
            assertApproxEqAbs(
                rewardToken.balanceOf(sponsorsArray[i]),
                _calcSponsorReward(RT_DISTRIBUTION_AMOUNT * 2, i),
                0.000000001 ether
            );
            assertApproxEqAbs(
                sponsorsArray[i].balance, _calcSponsorReward(CB_DISTRIBUTION_AMOUNT * 2, i), 0.000000001 ether
            );
        }
    }

    function _randomPause(uint256 seed_) internal {
        for (uint256 i = 0; i < builders.length; i++) {
            uint256 _random = uint256(keccak256(abi.encodePacked(seed_, i)));
            // 70% chance to pause
            if (_random % 10 > 2) {
                vm.prank(kycApprover);
                sponsorsManager.pauseBuilder(builders[i], "pause");
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
                sponsorsManager.unpauseBuilder(builders[i]);
                pausedBuilders[builders[i]] = false;
            }
        }
    }
}
