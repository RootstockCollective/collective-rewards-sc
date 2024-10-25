// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseFuzz } from "./BaseFuzz.sol";
import { stdStorage, StdStorage } from "forge-std/src/Test.sol";

contract RevokeBuilderFuzzTest is BaseFuzz {
    using stdStorage for StdStorage;

    uint32 public constant MAX_EPOCH_DURATION = 365 days;
    mapping(address builder_ => RevokeState revokedState_) public revokedBuilders;

    enum RevokeState {
        nonRevoked,
        permitted,
        revoked
    }

    /**
     * SCENARIO: In a random time gauges are revoked and permitted again.
     *  There is a distribution, revoked gauges don't receive rewards
     */
    function testFuzz_RevokeBuilderAndPermitWithNewKickback(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, epochDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

        // use a low kickbackCooldown to let apply it
        stdstore.target(address(sponsorsManager)).sig("kickbackCooldown()").checked_write(1 days);

        uint256[] memory _kickbackBefore = new uint256[](builders.length);
        for (uint256 i = 0; i < builders.length; i++) {
            _kickbackBefore[i] = sponsorsManager.getKickbackToApply(builders[i]);
        }

        /// AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND revoke randomly
        _randomRevoke(seed_, sponsorsManager.totalPotentialReward());
        uint256 _revokeTimestamp = block.timestamp;

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND permit randomly
        _randomPermit(seed_, sponsorsManager.totalPotentialReward());

        // AND permitted builders have the new kickback applied if cooldown time has passed
        for (uint256 i = 0; i < builders.length; i++) {
            if (
                revokedBuilders[builders[i]] == RevokeState.permitted
                    && block.timestamp - _revokeTimestamp >= sponsorsManager.kickbackCooldown()
            ) {
                assertEq(sponsorsManager.getKickbackToApply(builders[i]), 0.1 ether);
            } else {
                assertEq(sponsorsManager.getKickbackToApply(builders[i]), _kickbackBefore[i]);
            }
        }

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND each not revoked gauge receives its proportional share of rewards based on its allocation
        // AND revoked gauges don't receive rewards
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (revokedBuilders[builders[i]] < RevokeState.revoked) {
                assertApproxEqAbs(
                    rewardToken.balanceOf(address(gaugesArray[i])), _calcGaugeReward(RT_DISTRIBUTION_AMOUNT, i), 100
                );
                assertApproxEqAbs(address(gaugesArray[i]).balance, _calcGaugeReward(CB_DISTRIBUTION_AMOUNT, i), 100);
            } else {
                assertApproxEqAbs(rewardToken.balanceOf(address(gaugesArray[i])), 0, 100);
                assertApproxEqAbs(address(gaugesArray[i]).balance, 0, 100);
            }
        }
    }

    /**
     * SCENARIO: In a random time gauges are revoked, allocated, and permitted again.
     *  Shares are updated correctly
     */
    function testFuzz_RevokeBuilderAndPermitWithNewAllocations(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, epochDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND revoke randomly
        uint256 _expectedTotalPotentialReward = _randomRevoke(seed_, sponsorsManager.totalPotentialReward());

        // THEN totalPotentialReward does not consider the revoked gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND sponsors randomly modify their allocations
        for (uint256 i = 0; i < sponsorsArray.length; i++) {
            for (uint256 j = 0; j < sponsorsGauges[i].length; j++) {
                uint256 _allocationBefore = sponsorsAllocations[i][j];
                sponsorsAllocations[i][j] = uint256(keccak256(abi.encodePacked(block.timestamp, i, j))) % MAX_VOTE;
                // revoked gauges don't modify the totalPotentialReward
                if (!sponsorsManager.isGaugeHalted(address(sponsorsGauges[i][j]))) {
                    if (sponsorsAllocations[i][j] > _allocationBefore) {
                        _expectedTotalPotentialReward += (sponsorsAllocations[i][j] - _allocationBefore)
                            * sponsorsManager.timeUntilNextEpoch(block.timestamp);
                    } else {
                        _expectedTotalPotentialReward -= (_allocationBefore - sponsorsAllocations[i][j])
                            * sponsorsManager.timeUntilNextEpoch(block.timestamp);
                    }
                }
            }
            vm.prank(sponsorsArray[i]);
            sponsorsManager.allocateBatch(sponsorsGauges[i], sponsorsAllocations[i]);
        }

        // THEN totalPotentialReward does not consider the revoked gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND permit randomly
        _expectedTotalPotentialReward = _randomPermit(seed_, _expectedTotalPotentialReward);

        // THEN totalPotentialReward increase by permitted gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        _expectedTotalPotentialReward = 0;
        // THEN rewardShares for each non revoked gauge is the entire epoch
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (revokedBuilders[builders[i]] != RevokeState.revoked) {
                _expectedTotalPotentialReward += gaugesArray[i].totalAllocation() * epochDuration;
                assertEq(gaugesArray[i].rewardShares(), gaugesArray[i].totalAllocation() * epochDuration);
            }
        }
        // THEN totalPotentialReward is the entire epoch of non revoked gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }

    /**
     * SCENARIO: In a random time gauges are revoked and permitted again. There was an epoch duration change in the
     * middle
     *  Shares are updated correctly
     */
    function testFuzz_RevokeBuilderAndPermitWithNewEpochDuration(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint256 randomTime_,
        uint32 newEpochDuration_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, epochDuration);
        newEpochDuration_ = uint32(bound(newEpochDuration_, 2 hours, MAX_EPOCH_DURATION));
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND revoke randomly
        uint256 _expectedTotalPotentialReward = _randomRevoke(seed_, sponsorsManager.totalPotentialReward());

        // THEN totalPotentialReward does not consider the revoked gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND governor sets a random epoch duration
        sponsorsManager.setEpochDuration(newEpochDuration_, 0);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND permit randomly
        _expectedTotalPotentialReward = _randomPermit(seed_, _expectedTotalPotentialReward);

        // THEN totalPotentialReward increase by permitted gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        _expectedTotalPotentialReward = 0;
        // THEN rewardShares for each non revoked gauge is the entire epoch
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (revokedBuilders[builders[i]] != RevokeState.revoked) {
                _expectedTotalPotentialReward += gaugesArray[i].totalAllocation() * newEpochDuration_;
                assertEq(gaugesArray[i].rewardShares(), gaugesArray[i].totalAllocation() * newEpochDuration_);
            }
        }
        // THEN totalPotentialReward is the entire epoch of non revoked gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }

    /**
     * SCENARIO: In a random time gauges are revoked and permitted again. There was distribution in the middle
     *  Shares are updated correctly
     */
    function testFuzz_RevokeBuilderAndPermitWithDistribution(
        uint256 buildersAmount_,
        uint256 sponsorsAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, epochDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of sponsors voting the gauges
        _initialFuzzAllocation(buildersAmount_, sponsorsAmount_, seed_);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND revoke randomly
        _randomRevoke(seed_, sponsorsManager.totalPotentialReward());

        // AND a random time passes
        skip(randomTime_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND permit randomly
        _randomPermit(seed_, sponsorsManager.totalPotentialReward());

        uint256 _expectedTotalPotentialReward;
        // THEN rewardShares for each non revoked gauge is the entire epoch
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (revokedBuilders[builders[i]] != RevokeState.revoked) {
                _expectedTotalPotentialReward += gaugesArray[i].totalAllocation() * epochDuration;
                assertEq(gaugesArray[i].rewardShares(), gaugesArray[i].totalAllocation() * epochDuration);
            }
        }
        // THEN totalPotentialReward is the entire epoch of non revoked gauges
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }

    /**
     * @notice skip some random time but using the current epoch as a limit
     *  Used to avoid jump to another epoch because permitBuilder will fail if there is no distribution
     * @param randomTime_ time to skip
     */
    function _skipLimitPeriodFinish(uint256 randomTime_) internal {
        skip(randomTime_ % (sponsorsManager.periodFinish() - block.timestamp - 1));
    }

    function _randomRevoke(uint256 seed_, uint256 expectedTotalPotentialReward_) internal returns (uint256) {
        bool _skipRevoke = true;
        for (uint256 i = 0; i < builders.length; i++) {
            uint256 _random = uint256(keccak256(abi.encodePacked(seed_, i)));
            // at least one gauge with allocations must be operational
            if (_skipRevoke && gaugesArray[i].totalAllocation() > 0) {
                _skipRevoke = false;
            }
            // 70% chance to revoke
            else if (_random % 10 > 2) {
                vm.prank(builders[i]);
                sponsorsManager.revokeBuilder();
                revokedBuilders[builders[i]] = RevokeState.revoked;
                expectedTotalPotentialReward_ -= gaugesArray[i].rewardShares();
            }
        }
        return expectedTotalPotentialReward_;
    }

    function _randomPermit(uint256 seed_, uint256 expectedTotalPotentialReward_) internal returns (uint256) {
        for (uint256 i = 0; i < builders.length; i++) {
            uint256 _random = uint256(keccak256(abi.encodePacked(seed_, i, i)));
            // 70% chance to permit
            if (revokedBuilders[builders[i]] == RevokeState.revoked && _random % 10 > 2) {
                expectedTotalPotentialReward_ += gaugesArray[i].rewardShares();
                vm.prank(builders[i]);
                sponsorsManager.permitBuilder(0.1 ether /*kickback*/ );
                revokedBuilders[builders[i]] = RevokeState.permitted;
            }
        }
        return expectedTotalPotentialReward_;
    }
}
