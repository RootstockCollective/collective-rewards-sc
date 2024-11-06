// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, GaugeRootstockCollective } from "../BaseTest.sol";

contract BaseFuzz is BaseTest {
    uint256 public constant MAX_BUILDERS = 50;
    uint256 public constant MAX_BACKERS = 50;
    uint256 public constant MAX_VOTE = 100_000 ether;
    uint256 public constant RT_DISTRIBUTION_AMOUNT = 10_000 ether;
    uint256 public constant CB_DISTRIBUTION_AMOUNT = 1000 ether;

    address[] public backersArray;
    GaugeRootstockCollective[][] public backersGauges;
    uint256[][] public backersAllocations;

    function _setUp() internal override {
        // delete all the arrays created on BaseTest setup to start from scratch
        delete gaugesArray;
        delete allocationsArray;
        delete builders;
    }

    function _initialFuzzAllocation(uint256 buildersAmount_, uint256 backersAmount_, uint256 seed_) internal {
        buildersAmount_ = bound(buildersAmount_, 1, MAX_BUILDERS);
        backersAmount_ = bound(backersAmount_, 1, MAX_BACKERS);

        // GIVEN a random amount of builders
        for (uint256 i = 0; i < buildersAmount_; i++) {
            // random reward percentage pct for each gauge between 0 and 100%
            uint64 _randomRewardPercentage = uint64(uint256(keccak256(abi.encodePacked(seed_, i))) % 1 ether);
            _createGauge(_randomRewardPercentage);
        }
        // THEN all the gauges and builders were created
        assertEq(gaugesArray.length, buildersAmount_);
        assertEq(builders.length, buildersAmount_);

        // AND a random amount of backers voting the gauges
        for (uint256 i = 0; i < backersAmount_; i++) {
            backersArray.push(makeAddr(string(abi.encodePacked("backer", i))));
            backersGauges.push();
            backersAllocations.push();
            stakingToken.mint(backersArray[i], type(uint192).max / backersAmount_);

            bool hasVote;
            for (uint256 j = 0; j < buildersAmount_; j++) {
                uint256 _randomVoting = uint256(keccak256(abi.encodePacked(seed_, i, j)));
                // 70% chance to vote the gauge
                if (_randomVoting % 10 > 2) {
                    backersGauges[i].push(gaugesArray[j]);
                    backersAllocations[i].push(_randomVoting % MAX_VOTE);
                    hasVote = true;
                }
            }

            // each backers must vote at least one gauge
            if (!hasVote) {
                uint256 _randomGauge = uint256(keccak256(abi.encodePacked(seed_, i)));
                backersGauges[i].push(gaugesArray[_randomGauge % buildersAmount_]);
                backersAllocations[i].push(_randomGauge % MAX_VOTE);
            }

            vm.prank(backersArray[i]);
            backersManager.allocateBatch(backersGauges[i], backersAllocations[i]);

            // THEN there are allocations
            assertGt(backersManager.totalPotentialReward(), 0);
        }
    }

    function _calcGaugeReward(uint256 amount_, uint256 gaugeIndex_) internal view returns (uint256) {
        return amount_ * gaugesArray[gaugeIndex_].rewardShares() / backersManager.totalPotentialReward();
    }

    function _calcBuilderReward(uint256 amount_, uint256 gaugeIndex_) internal view returns (uint256) {
        uint256 _rewardPercentage = 10 ** 18 - backersManager.getRewardPercentageToApply(builders[gaugeIndex_]);
        return (_calcGaugeReward(amount_, gaugeIndex_) * _rewardPercentage) / 10 ** 18;
    }

    function _calcBackerReward(uint256 amount_, uint256 backerIndex_) internal view virtual returns (uint256) {
        uint256 _rewards;
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (gaugesArray[i].totalAllocation() > 0) {
                _rewards += (_calcGaugeReward(amount_, i) - _calcBuilderReward(amount_, i))
                    * gaugesArray[i].allocationOf(backersArray[backerIndex_]) / gaugesArray[i].totalAllocation();
            }
        }
        return _rewards;
    }
}
