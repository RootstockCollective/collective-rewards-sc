// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseFuzz } from "./BaseFuzz.sol";
import { stdStorage, StdStorage } from "forge-std/src/Test.sol";

contract SelfPauseBuilderFuzzTest is BaseFuzz {
    using stdStorage for StdStorage;

    uint32 public constant MAX_CYCLE_DURATION = 365 days;
    mapping(address builder_ => SelfPauseState selfPauseState_) public pausedBuilders;

    enum SelfPauseState {
        none,
        unpaused,
        paused
    }

    /**
     * SCENARIO: In a random time gauges are self paused and self unpaused again.
     *  There is a distribution, self paused gauges don't receive rewards
     */
    function testFuzz_SelfPauseBuilderAndSelfUnpauseWithNewRewardPercentage(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, cycleDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        // use a low rewardPercentageCooldown to let apply it
        stdstore.target(address(builderRegistry)).sig("rewardPercentageCooldown()").checked_write(1 days);

        uint256[] memory _rewardPercentageBefore = new uint256[](builders.length);
        for (uint256 i = 0; i < builders.length; i++) {
            _rewardPercentageBefore[i] = builderRegistry.getRewardPercentageToApply(builders[i]);
        }

        /// AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self pause randomly
        _randomSelfPause(seed_, backersManager.totalPotentialReward());
        uint256 _selfPausedTimestamp = block.timestamp;

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self unpause randomly
        _randomUnpauseSelf(seed_, backersManager.totalPotentialReward());

        // AND self unpaused builders have the new reward percentage applied if cooldown time has passed
        for (uint256 i = 0; i < builders.length; i++) {
            if (
                pausedBuilders[builders[i]] == SelfPauseState.unpaused
                    && block.timestamp - _selfPausedTimestamp >= builderRegistry.rewardPercentageCooldown()
            ) {
                assertEq(builderRegistry.getRewardPercentageToApply(builders[i]), 0.1 ether);
            } else {
                assertEq(builderRegistry.getRewardPercentageToApply(builders[i]), _rewardPercentageBefore[i]);
            }
        }

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND each not self paused gauge receives its proportional share of rewards based on its allocation
        // AND self paused gauges don't receive rewards
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (pausedBuilders[builders[i]] < SelfPauseState.paused) {
                assertApproxEqAbs(
                    rifToken.balanceOf(address(gaugesArray[i])), _calcGaugeReward(RT_DISTRIBUTION_AMOUNT, i), 100
                );
                assertApproxEqAbs(address(gaugesArray[i]).balance, _calcGaugeReward(CB_DISTRIBUTION_AMOUNT, i), 100);
            } else {
                assertApproxEqAbs(rifToken.balanceOf(address(gaugesArray[i])), 0, 100);
                assertApproxEqAbs(address(gaugesArray[i]).balance, 0, 100);
            }
        }
    }

    /**
     * SCENARIO: In a random time gauges are self paused, allocated, and self unpaused again.
     *  Shares are updated correctly
     */
    function testFuzz_SelfPausedBuilderAndSelfUnpausedWithNewAllocations(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, cycleDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self pause randomly
        uint256 _expectedTotalPotentialReward = _randomSelfPause(seed_, backersManager.totalPotentialReward());

        // THEN totalPotentialReward does not consider the self paused gauges
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND backers randomly modify their allocations
        for (uint256 i = 0; i < backersArray.length; i++) {
            for (uint256 j = 0; j < backersGauges[i].length; j++) {
                uint256 _allocationBefore = backersAllocations[i][j];
                backersAllocations[i][j] = uint256(keccak256(abi.encodePacked(block.timestamp, i, j))) % MAX_VOTE;
                // self paused gauges don't modify the totalPotentialReward
                if (!builderRegistry.isGaugeHalted(address(backersGauges[i][j]))) {
                    if (backersAllocations[i][j] > _allocationBefore) {
                        _expectedTotalPotentialReward += (backersAllocations[i][j] - _allocationBefore)
                            * backersManager.timeUntilNextCycle(block.timestamp);
                    } else {
                        _expectedTotalPotentialReward -= (_allocationBefore - backersAllocations[i][j])
                            * backersManager.timeUntilNextCycle(block.timestamp);
                    }
                } else {
                    if (backersAllocations[i][j] > _allocationBefore) {
                        backersAllocations[i][j] = _allocationBefore;
                    }
                }
            }
            vm.prank(backersArray[i]);
            backersManager.allocateBatch(backersGauges[i], backersAllocations[i]);
        }

        // THEN totalPotentialReward does not consider the self paused gauges
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self unpause randomly
        _expectedTotalPotentialReward = _randomUnpauseSelf(seed_, _expectedTotalPotentialReward);

        // THEN totalPotentialReward increase by self unpaused gauges
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        _expectedTotalPotentialReward = 0;
        // THEN rewardShares for each non self paused gauge is the entire cycle
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (pausedBuilders[builders[i]] != SelfPauseState.paused) {
                _expectedTotalPotentialReward += gaugesArray[i].totalAllocation() * cycleDuration;
                assertEq(gaugesArray[i].rewardShares(), gaugesArray[i].totalAllocation() * cycleDuration);
            }
        }
        // THEN totalPotentialReward is the entire cycle of non self paused gauge
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }

    /**
     * SCENARIO: In a random time gauges are self paused and self unpaused again. There was an cycle duration change in
     * the
     * middle
     *  Shares are updated correctly
     */
    function testFuzz_SelfPauseBuilderAndSelfUnpauseWithNewCycleDuration(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint256 randomTime_,
        uint32 newCycleDuration_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, cycleDuration);
        newCycleDuration_ = uint32(bound(newCycleDuration_, 2 hours, MAX_CYCLE_DURATION));
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self pause randomly
        uint256 _expectedTotalPotentialReward = _randomSelfPause(seed_, backersManager.totalPotentialReward());

        // THEN totalPotentialReward does not consider the self paused gauges
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND governor sets a random cycle duration
        vm.prank(governor);
        backersManager.setCycleDuration(newCycleDuration_, 0);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self unpause randomly
        _expectedTotalPotentialReward = _randomUnpauseSelf(seed_, _expectedTotalPotentialReward);

        // THEN totalPotentialReward increase by self unpaused gauges
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        _expectedTotalPotentialReward = 0;
        // THEN rewardShares for each non self paused gauge is the entire cycle
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (pausedBuilders[builders[i]] != SelfPauseState.paused) {
                _expectedTotalPotentialReward += gaugesArray[i].totalAllocation() * newCycleDuration_;
                assertEq(gaugesArray[i].rewardShares(), gaugesArray[i].totalAllocation() * newCycleDuration_);
            }
        }
        // THEN totalPotentialReward is the entire cycle of non self paused gauge
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }

    /**
     * SCENARIO: In a random time gauges are self paused and self unpaused again. There was distribution in the middle
     *  Shares are updated correctly
     */
    function testFuzzSelfPauseBuilderAndSelfUnpauseWithDistribution(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint256 randomTime_
    )
        public
    {
        randomTime_ = bound(randomTime_, 0, cycleDuration);
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self pause randomly
        _randomSelfPause(seed_, backersManager.totalPotentialReward());

        // AND a random time passes
        skip(randomTime_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND a random time passes
        _skipLimitPeriodFinish(randomTime_);

        // AND self unpause randomly
        _randomUnpauseSelf(seed_, backersManager.totalPotentialReward());

        uint256 _expectedTotalPotentialReward;
        // THEN rewardShares for each non self paused gauge is the entire cycle
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (pausedBuilders[builders[i]] != SelfPauseState.paused) {
                _expectedTotalPotentialReward += gaugesArray[i].totalAllocation() * cycleDuration;
                assertEq(gaugesArray[i].rewardShares(), gaugesArray[i].totalAllocation() * cycleDuration);
            }
        }
        // THEN totalPotentialReward is the entire cycle of non self paused gauge
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }

    /**
     * @notice skip some random time but using the current cycle as a limit
     *  Used to avoid jump to another cycle because unpauseSelf will fail if there is no distribution
     * @param randomTime_ time to skip
     */
    function _skipLimitPeriodFinish(uint256 randomTime_) internal {
        skip(randomTime_ % (backersManager.periodFinish() - block.timestamp - 1));
    }

    function _randomSelfPause(uint256 seed_, uint256 expectedTotalPotentialReward_) internal returns (uint256) {
        bool _skipPauseSelf = true;
        for (uint256 i = 0; i < builders.length; i++) {
            uint256 _random = uint256(keccak256(abi.encodePacked(seed_, i)));
            // at least one gauge with allocations must be operational
            if (_skipPauseSelf && gaugesArray[i].totalAllocation() > 0) {
                _skipPauseSelf = false;
            }
            // 70% chance to self pause
            else if (_random % 10 > 2) {
                vm.prank(builders[i]);
                builderRegistry.pauseSelf();
                pausedBuilders[builders[i]] = SelfPauseState.paused;
                expectedTotalPotentialReward_ -= gaugesArray[i].rewardShares();
            }
        }
        return expectedTotalPotentialReward_;
    }

    function _randomUnpauseSelf(uint256 seed_, uint256 expectedTotalPotentialReward_) internal returns (uint256) {
        for (uint256 i = 0; i < builders.length; i++) {
            uint256 _random = uint256(keccak256(abi.encodePacked(seed_, i, i)));
            // 70% chance to self unpause
            if (pausedBuilders[builders[i]] == SelfPauseState.paused && _random % 10 > 2) {
                expectedTotalPotentialReward_ += gaugesArray[i].rewardShares();
                vm.prank(builders[i]);
                builderRegistry.unpauseSelf(0.1 ether /*reward percentage*/ );
                pausedBuilders[builders[i]] = SelfPauseState.unpaused;
            }
        }
        return expectedTotalPotentialReward_;
    }
}
