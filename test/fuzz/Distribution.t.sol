// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseFuzz } from "./BaseFuzz.sol";

contract DistributionFuzzTest is BaseFuzz {
    /* solhint-disable code-complexity */

    /**
     * SCENARIO: After 3 consecutive distributions all the sponsors and builders claim their rewards
     */
    function testFuzz_Distribution(uint256 buildersAmount_, uint256 sponsorsAmount_, uint256 seed_) public {
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

        // AND there are 3 distributions of 10000 rewardToken and 1000 coinbase each one
        _distribute(10_000 ether, 1000 ether);
        _distribute(10_000 ether, 1000 ether);
        _distribute(10_000 ether, 1000 ether);

        // AND each gauge receives its proportional share of rewards based on its allocation
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(rewardToken.balanceOf(address(gaugesArray[i])), _calcGaugeReward(30_000 ether, i), 100);
            assertApproxEqAbs(address(gaugesArray[i]).balance, _calcGaugeReward(3000 ether, i), 100);
        }

        // WHEN all the builders claim their rewards
        _buildersClaim();

        // THEN they receive the rewards after deducting the kickback for the sponsors
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(rewardToken.balanceOf(builders[i]), _calcBuilderReward(30_000 ether, i), 100);
            assertApproxEqAbs(builders[i].balance, _calcBuilderReward(3000 ether, i), 100);
        }

        // AND epoch finishes
        _skipAndStartNewEpoch();

        // WHEN sponsors claim their rewards
        for (uint256 i = 0; i < sponsorsArray.length; i++) {
            vm.prank(sponsorsArray[i]);
            sponsorsManager.claimSponsorRewards(sponsorsGauges[i]);

            // THEN they receive the rewards
            assertApproxEqAbs(
                rewardToken.balanceOf(sponsorsArray[i]), _calcSponsorReward(30_000 ether, i), 0.000000001 ether
            );
            assertApproxEqAbs(sponsorsArray[i].balance, _calcSponsorReward(3000 ether, i), 0.000000001 ether);
        }

        // THEN gauges balances are empty
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(rewardToken.balanceOf(address(gaugesArray[i])), 0, 0.000000001 ether);
            assertApproxEqAbs(address(gaugesArray[i]).balance, 0, 0.000000001 ether);
        }
    }

    /**
     * SCENARIO: After a distribution sponsors modify their allocations.
     *  Shares are updated considering the new allocations and the time until next epoch
     */
    function testFuzz_ModifyAllocations(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint256 allocationsTime_
    )
        public
    {
        allocationsTime_ = bound(allocationsTime_, 0, 2 * epochDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

        // AND there is a distribution of 10000 rewardToken and 1000 coinbase
        _distribute(10_000 ether, 1000 ether);

        // AND a random time passes
        skip(allocationsTime_);

        uint256[] memory _gaugesAllocationsBefore = new uint256[](gaugesArray.length);
        uint256 _totalAllocations;
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            _gaugesAllocationsBefore[i] = gaugesArray[i].totalAllocation();
            _totalAllocations += gaugesArray[i].totalAllocation();
        }

        // AND sponsors randomly modify their allocations
        for (uint256 i = 0; i < sponsorsArray.length; i++) {
            for (uint256 j = 0; j < sponsorsGauges[i].length; j++) {
                sponsorsAllocations[i][j] = uint256(keccak256(abi.encodePacked(block.timestamp, i, j))) % MAX_VOTE;
            }
            vm.prank(sponsorsArray[i]);
            sponsorsManager.allocateBatch(sponsorsGauges[i], sponsorsAllocations[i]);
        }

        uint256 _newTotalAllocations;
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            _newTotalAllocations += gaugesArray[i].totalAllocation();
        }

        // THEN totalPotentialReward is updated considering the new allocations and the time until next epoch
        uint256 _expectedTotalPotentialReward = _totalAllocations * epochDuration;
        if (_newTotalAllocations > _totalAllocations) {
            _expectedTotalPotentialReward +=
                (_newTotalAllocations - _totalAllocations) * sponsorsManager.timeUntilNextEpoch(block.timestamp);
        } else {
            _expectedTotalPotentialReward -=
                (_totalAllocations - _newTotalAllocations) * sponsorsManager.timeUntilNextEpoch(block.timestamp);
        }
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // THEN rewardShares for each gauge is updated considering the new allocations and the time until next epoch
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            uint256 _expectedRewardShares = _gaugesAllocationsBefore[i] * epochDuration;
            if (gaugesArray[i].totalAllocation() > _gaugesAllocationsBefore[i]) {
                _expectedRewardShares += (gaugesArray[i].totalAllocation() - _gaugesAllocationsBefore[i])
                    * sponsorsManager.timeUntilNextEpoch(block.timestamp);
            } else {
                _expectedRewardShares -= (_gaugesAllocationsBefore[i] - gaugesArray[i].totalAllocation())
                    * sponsorsManager.timeUntilNextEpoch(block.timestamp);
            }
            assertEq(gaugesArray[i].rewardShares(), _expectedRewardShares);
        }

        // AND there is a distribution of 10000 rewardToken and 1000 coinbase
        _distribute(10_000 ether, 1000 ether);
        // THEN totalPotentialReward is the entire epoch
        assertEq(sponsorsManager.totalPotentialReward(), _newTotalAllocations * epochDuration);
        // THEN rewardShares for each gauge is the entire epoch
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertEq(gaugesArray[i].rewardShares(), gaugesArray[i].totalAllocation() * epochDuration);
        }
    }
}
