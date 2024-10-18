// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "../BaseTest.sol";

contract BaseFuzz is BaseTest {
    uint256 public constant MAX_BUILDERS = 50;
    uint256 public constant MAX_SPONSORS = 50;
    uint256 public constant MAX_VOTE = 100_000 ether;
    uint256 public constant RT_DISTRIBUTION_AMOUNT = 10_000 ether;
    uint256 public constant CB_DISTRIBUTION_AMOUNT = 1000 ether;

    address[] public sponsorsArray;
    Gauge[][] public sponsorsGauges;
    uint256[][] public sponsorsAllocations;

    function _setUp() internal override {
        // delete all the arrays created on BaseTest setup to start from scratch
        delete gaugesArray;
        delete allocationsArray;
        delete builders;
    }

    function _initialFuzzAllocation(uint256 buildersAmount_, uint256 sponsorsAmount_, uint256 seed_) internal {
        buildersAmount_ = bound(buildersAmount_, 1, MAX_BUILDERS);
        sponsorsAmount_ = bound(sponsorsAmount_, 1, MAX_SPONSORS);

        // GIVEN a random amount of builders
        for (uint256 i = 0; i < buildersAmount_; i++) {
            // random kickback pct for each gauge between 0 and 100%
            uint64 _randomKickback = uint64(uint256(keccak256(abi.encodePacked(seed_, i))) % 1 ether);
            _createGauge(_randomKickback);
        }
        // THEN all the gauges and builders were created
        assertEq(gaugesArray.length, buildersAmount_);
        assertEq(builders.length, buildersAmount_);

        // AND a random amount of sponsors voting the gauges
        for (uint256 i = 0; i < sponsorsAmount_; i++) {
            sponsorsArray.push(makeAddr(string(abi.encodePacked("sponsor", i))));
            sponsorsGauges.push();
            sponsorsAllocations.push();
            stakingToken.mint(sponsorsArray[i], type(uint192).max / sponsorsAmount_);

            bool hasVote;
            for (uint256 j = 0; j < buildersAmount_; j++) {
                uint256 _randomVoting = uint256(keccak256(abi.encodePacked(seed_, i, j)));
                // 70% chance to vote the gauge
                if (_randomVoting % 10 > 2) {
                    sponsorsGauges[i].push(gaugesArray[j]);
                    sponsorsAllocations[i].push(_randomVoting % MAX_VOTE);
                    hasVote = true;
                }
            }

            // each sponsors must vote at least one gauge
            if (!hasVote) {
                uint256 _randomGauge = uint256(keccak256(abi.encodePacked(seed_, i)));
                sponsorsGauges[i].push(gaugesArray[_randomGauge % buildersAmount_]);
                sponsorsAllocations[i].push(_randomGauge % MAX_VOTE);
            }

            vm.prank(sponsorsArray[i]);
            sponsorsManager.allocateBatch(sponsorsGauges[i], sponsorsAllocations[i]);

            // THEN there are allocations
            assertGt(sponsorsManager.totalPotentialReward(), 0);
        }
    }

    function _calcGaugeReward(uint256 amount_, uint256 gaugeIndex_) internal view returns (uint256) {
        return amount_ * gaugesArray[gaugeIndex_].rewardShares() / sponsorsManager.totalPotentialReward();
    }

    function _calcBuilderReward(uint256 amount_, uint256 gaugeIndex_) internal view returns (uint256) {
        uint256 _kickback = 10 ** 18 - sponsorsManager.getKickbackToApply(builders[gaugeIndex_]);
        return (_calcGaugeReward(amount_, gaugeIndex_) * _kickback) / 10 ** 18;
    }

    function _calcSponsorReward(uint256 amount_, uint256 sponsorIndex_) internal view virtual returns (uint256) {
        uint256 _rewards;
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (gaugesArray[i].totalAllocation() > 0) {
                _rewards += (_calcGaugeReward(amount_, i) - _calcBuilderReward(amount_, i))
                    * gaugesArray[i].allocationOf(sponsorsArray[sponsorIndex_]) / gaugesArray[i].totalAllocation();
            }
        }
        return _rewards;
    }
}
