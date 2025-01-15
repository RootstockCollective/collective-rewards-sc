// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseFuzz } from "./BaseFuzz.sol";

contract SetCycleDurationFuzzTest is BaseFuzz {
    uint32 public constant MAX_CYCLE_DURATION = 365 days;
    uint24 public constant MAX_OFFSET = 20 weeks;

    function testFuzz_SetCycleDuration(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint32 newCycleDuration_,
        uint24 cycleStartOffset_
    )
        public
    {
        newCycleDuration_ = uint32(bound(newCycleDuration_, 2 hours, MAX_CYCLE_DURATION));
        cycleStartOffset_ = uint24(bound(cycleStartOffset_, 0, MAX_OFFSET));
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);
        // AND governor sets a random cycle duration and offset
        vm.prank(governor);
        backersManager.setCycleDuration(newCycleDuration_, cycleStartOffset_);

        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart,) =
            backersManager.cycleData();
        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = backersManager.cycleData();
        // THEN previous cycle duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next cycle duration is the new random cycle duration
        assertEq(_nextDuration, newCycleDuration_);
        // THEN previous cycle starts is 1 week ago
        assertEq(_previousStart, block.timestamp - 1 weeks);
        // THEN next cycle starts in 1 weeks from now
        assertEq(_nextStart, block.timestamp + 1 weeks);

        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle starts is 1 week ago
        assertEq(_cycleStart, block.timestamp - 1 weeks);
        // THEN cycle duration is 1 week
        assertEq(_cycleDuration, 1 weeks);
        // THEN cycle finishes in 1 week
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1 weeks);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is newCycleDuration_ + cycleStartOffset_
        assertEq(_cycleDuration, newCycleDuration_ + cycleStartOffset_);
        // THEN cycles start time is now
        assertEq(_cycleStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in newCycleDuration_ + cycleStartOffset_
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + newCycleDuration_ + cycleStartOffset_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);
        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is the new random cycle duration
        assertEq(_cycleDuration, newCycleDuration_);
        // THEN cycles starts time is the new random cycle duration ago
        assertEq(_cycleStart, block.timestamp - newCycleDuration_);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is after the new random cycle duration
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + newCycleDuration_);

        // WHEN all the builders claim their rewards
        _buildersClaim();

        // THEN they receive the rewards after deducting the backers reward percentage
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(
                rewardToken.balanceOf(builders[i]), _calcBuilderReward(RT_DISTRIBUTION_AMOUNT * 3, i), 100
            );
            assertApproxEqAbs(builders[i].balance, _calcBuilderReward(CB_DISTRIBUTION_AMOUNT * 3, i), 100);
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
                _calcBackerReward(RT_DISTRIBUTION_AMOUNT * 3, i),
                0.000000001 ether
            );
            assertApproxEqAbs(
                backersArray[i].balance, _calcBackerReward(CB_DISTRIBUTION_AMOUNT * 3, i), 0.000000001 ether
            );
        }

        // THEN gauges balances are empty
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(rewardToken.balanceOf(address(gaugesArray[i])), 0, 0.000000001 ether);
            assertApproxEqAbs(address(gaugesArray[i]).balance, 0, 0.000000001 ether);
        }
    }
}
