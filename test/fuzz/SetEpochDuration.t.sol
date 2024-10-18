// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseFuzz } from "./BaseFuzz.sol";

contract SetEpochDurationFuzzTest is BaseFuzz {
    uint32 public constant MAX_EPOCH_DURATION = 365 days;
    uint24 public constant MAX_OFFSET = 20 weeks;

    function testFuzz_SetEpochDuration(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint32 newEpochDuration_,
        uint24 epochStartOffset_
    )
        public
    {
        newEpochDuration_ = uint32(bound(newEpochDuration_, 2 hours, MAX_EPOCH_DURATION));
        epochStartOffset_ = uint24(bound(epochStartOffset_, 0, MAX_OFFSET));
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);
        // AND governor sets a random epoch duration and offset
        sponsorsManager.setEpochDuration(newEpochDuration_, epochStartOffset_);

        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart,) =
            sponsorsManager.epochData();
        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = sponsorsManager.epochData();
        // THEN previous epoch duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next epoch duration is the new random epoch duration
        assertEq(_nextDuration, newEpochDuration_);
        // THEN previous epoch starts is 1 week ago
        assertEq(_previousStart, block.timestamp - 1 weeks);
        // THEN next epoch starts in 1 weeks from now
        assertEq(_nextStart, block.timestamp + 1 weeks);

        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch starts is 1 week ago
        assertEq(_epochStart, block.timestamp - 1 weeks);
        // THEN epoch duration is 1 week
        assertEq(_epochDuration, 1 weeks);
        // THEN epoch finishes in 1 week
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1 weeks);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is newEpochDuration_ + epochStartOffset_
        assertEq(_epochDuration, newEpochDuration_ + epochStartOffset_);
        // THEN epochs start time is now
        assertEq(_epochStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in newEpochDuration_ + epochStartOffset_
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + newEpochDuration_ + epochStartOffset_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);
        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is the new random epoch duration
        assertEq(_epochDuration, newEpochDuration_);
        // THEN epochs starts time is the new random epoch duration ago
        assertEq(_epochStart, block.timestamp - newEpochDuration_);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is after the new random epoch duration
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + newEpochDuration_);

        // WHEN all the builders claim their rewards
        _buildersClaim();

        // THEN they receive the rewards after deducting the kickback for the sponsors
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(
                rewardToken.balanceOf(builders[i]), _calcBuilderReward(RT_DISTRIBUTION_AMOUNT * 3, i), 100
            );
            assertApproxEqAbs(builders[i].balance, _calcBuilderReward(CB_DISTRIBUTION_AMOUNT * 3, i), 100);
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
                _calcSponsorReward(RT_DISTRIBUTION_AMOUNT * 3, i),
                0.000000001 ether
            );
            assertApproxEqAbs(
                sponsorsArray[i].balance, _calcSponsorReward(CB_DISTRIBUTION_AMOUNT * 3, i), 0.000000001 ether
            );
        }

        // THEN gauges balances are empty
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(rewardToken.balanceOf(address(gaugesArray[i])), 0, 0.000000001 ether);
            assertApproxEqAbs(address(gaugesArray[i]).balance, 0, 0.000000001 ether);
        }
    }
}
