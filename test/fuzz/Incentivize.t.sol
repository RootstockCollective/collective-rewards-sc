// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseFuzz, GaugeRootstockCollective } from "./BaseFuzz.sol";
import { UtilsLib } from "src/libraries/UtilsLib.sol";

contract IncentivizeFuzzTest is BaseFuzz {
    uint256 public constant MAX_INCENTIVES = 10;
    uint256 public constant MAX_INCENTIVE_AMOUNT = 100 ether;
    mapping(GaugeRootstockCollective gauge_ => uint256 newRewards_) public rewardsAdded;

    /**
     * SCENARIO: After a distribution, in a random part of the cycle gauges are incentivize.
     *  There is another distribution, builder receive only the rewards for the distributions.
     *  Backers receive the rewards for the distributions plus the incentives
     */
    function testFuzz_Incentivize(
        uint256 buildersAmount_,
        uint256 backersAmount_,
        uint256 seed_,
        uint256 incentiveAmount_,
        uint256 incentiveTime_
    )
        public
    {
        uint256 _qIncentives = bound(incentiveAmount_, 1, MAX_INCENTIVES);
        incentiveAmount_ = bound(incentiveAmount_, UtilsLib.MIN_AMOUNT_INCENTIVES, MAX_INCENTIVE_AMOUNT);
        // cannot incentivize in a new cycle and without a distribution, it will revert by BeforeDistribution()
        incentiveTime_ = bound(incentiveTime_, 100, cycleDuration - 1);
        // GIVEN a random amount of builders
        //  AND a random amount of backers voting the gauges
        _initialFuzzAllocation(buildersAmount_, backersAmount_, seed_);

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND a random part of the cycle passes
        skip(incentiveTime_);

        // AND there are random incentivize calls
        for (uint256 i = 0; i < _qIncentives; i++) {
            uint256 _randomGauge = uint256(keccak256(abi.encodePacked(seed_, i))) % gaugesArray.length;
            rewardToken.approve(address(gaugesArray[_randomGauge]), incentiveAmount_);
            gaugesArray[_randomGauge].incentivizeWithRewardToken(incentiveAmount_, address(rewardToken));
            gaugesArray[_randomGauge].incentivizeWithCoinbase{ value: incentiveAmount_ }();
            rewardsAdded[gaugesArray[_randomGauge]] += incentiveAmount_;
        }

        // AND there is a distribution
        _distribute(RT_DISTRIBUTION_AMOUNT, CB_DISTRIBUTION_AMOUNT);

        // AND each gauge receives its proportional share of rewards based on its allocation plus the rewards added
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            uint256 _rewardsOnRewardToken =
                rewardsAdded[gaugesArray[i]] + _calcGaugeReward(RT_DISTRIBUTION_AMOUNT * 2, i);
            uint256 _rewardsOnCoinbase = rewardsAdded[gaugesArray[i]] + _calcGaugeReward(CB_DISTRIBUTION_AMOUNT * 2, i);
            assertApproxEqAbs(rewardToken.balanceOf(address(gaugesArray[i])), _rewardsOnRewardToken, 100);
            assertApproxEqAbs(address(gaugesArray[i]).balance, _rewardsOnCoinbase, 100);
        }

        // WHEN all the builders claim their rewards
        _buildersClaim();

        // THEN they receive the rewards after deducting the backers reward percentage, rewards added are not
        // considered
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            assertApproxEqAbs(
                rewardToken.balanceOf(builders[i]), _calcBuilderReward(RT_DISTRIBUTION_AMOUNT * 2, i), 100
            );
            assertApproxEqAbs(builders[i].balance, _calcBuilderReward(CB_DISTRIBUTION_AMOUNT * 2, i), 100);
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

        // THEN gauges balances are empty if the rewards added are allocated to at least one backer.
        //  otherwise, they are considered in the rewardRate for following allocations(aka rewardMissing)
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (gaugesArray[i].totalAllocation() > 0) {
                assertApproxEqAbs(rewardToken.balanceOf(address(gaugesArray[i])), 0, 0.000000001 ether);
                assertApproxEqAbs(address(gaugesArray[i]).balance, 0, 0.000000001 ether);
            } else {
                assertApproxEqAbs(
                    gaugesArray[i].rewardRate(address(rewardToken)) / 10 ** 18,
                    rewardsAdded[gaugesArray[i]] / cycleDuration,
                    0.000000001 ether
                );
                assertApproxEqAbs(
                    gaugesArray[i].rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18,
                    rewardsAdded[gaugesArray[i]] / cycleDuration,
                    0.000000001 ether
                );
            }
        }
    }

    function _calcBackerReward(uint256 amount_, uint256 backerIndex_) internal view override returns (uint256) {
        uint256 _rewards;
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (gaugesArray[i].totalAllocation() > 0) {
                _rewards += (
                    rewardsAdded[gaugesArray[i]] + _calcGaugeReward(amount_, i) - _calcBuilderReward(amount_, i)
                ) * gaugesArray[i].allocationOf(backersArray[backerIndex_]) / gaugesArray[i].totalAllocation();
            }
        }
        return _rewards;
    }
}
