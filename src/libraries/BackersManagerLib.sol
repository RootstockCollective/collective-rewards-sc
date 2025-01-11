// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";

library BackersManagerLib {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error UnequalLengths();
    error NotEnoughStaking();
    error OnlyInDistributionWindow();
    error NotInDistributionPeriod();
    error DistributionPeriodDidNotStart();
    error BeforeDistribution();
    error PositiveAllocationOnHaltedGauge();
    error NoGaugesForDistribution();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event RewardDistributionStarted(address indexed sender_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------
    struct BackerData {
        /// @notice address of the token used to stake
        IERC20 stakingToken;
        /// @notice address of the token rewarded to builder and voters
        address rewardToken;
        /// @notice total potential reward
        uint256 totalPotentialReward;
        /// @notice on a paginated distribution we need to temporarily store the totalPotentialReward
        uint256 tempTotalPotentialReward;
        /// @notice ERC20 rewards to distribute [N]
        uint256 rewardsERC20;
        /// @notice Coinbase rewards to distribute [N]
        uint256 rewardsCoinbase;
        /// @notice index of tha last gauge distributed during a distribution period
        uint256 indexLastGaugeDistributed;
        /// @notice timestamp end of current rewards period
        uint256 _periodFinish;
        /// @notice true if distribution period started. Allocations remain blocked until it finishes
        bool onDistributionPeriod;
        /// @notice total amount of stakingToken allocated by a backer
        mapping(address backer => uint256 allocation) backerTotalAllocation;
    }

    /**
     * @notice internal function used to allocate votes for a gauge or a batch of gauges
     * @param gauge_ address of the gauge where the votes will be allocated
     * @param allocation_ amount of votes to allocate
     * @param backerTotalAllocation_ current backer total allocation
     * @param totalPotentialReward_ current total potential reward
     * @return newbackerTotalAllocation_ backer total allocation after new the allocation
     * @return newTotalPotentialReward_ total potential reward  after the new allocation
     */
    function _allocate(
        function (address) external view returns (bool) isGaugeHalted,
        GaugeRootstockCollective gauge_,
        uint256 allocation_,
        uint256 backerTotalAllocation_,
        uint256 totalPotentialReward_,
        uint256 allocationDeviation_, 
        uint256 rewardSharesDeviation_, 
        bool isNegative_
    )
        public
        returns (uint256 newbackerTotalAllocation_, uint256 newTotalPotentialReward_)
    {
        // halted gauges are not taken into account for the rewards; newTotalPotentialReward_ == totalPotentialReward_
        if (isGaugeHalted(address(gauge_))) {
            if (!isNegative_) {
                revert PositiveAllocationOnHaltedGauge();
            }
            newbackerTotalAllocation_ = backerTotalAllocation_ - allocationDeviation_;
            return (newbackerTotalAllocation_, totalPotentialReward_);
        }

        if (isNegative_) {
            newbackerTotalAllocation_ = backerTotalAllocation_ - allocationDeviation_;
            newTotalPotentialReward_ = totalPotentialReward_ - rewardSharesDeviation_;
        } else {
            newbackerTotalAllocation_ = backerTotalAllocation_ + allocationDeviation_;
            newTotalPotentialReward_ = totalPotentialReward_ + rewardSharesDeviation_;
        }

        emit NewAllocation(msg.sender, address(gauge_), allocation_);
        return (newbackerTotalAllocation_, newTotalPotentialReward_);
    }

    /**
     * @notice internal function used to update allocation variables
     * @dev reverts if backer doesn't have enough staking token balance
     * @param backer_ address of the backer who allocates
     * @param newbackerTotalAllocation_ backer total allocation after new the allocation
     * @param newTotalPotentialReward_ total potential reward after the new allocation
     */
    function _updateAllocation(
        BackerData storage self,
        address backer_,
        uint256 newbackerTotalAllocation_,
        uint256 newTotalPotentialReward_
    )
        public
    {
        self.backerTotalAllocation[backer_] = newbackerTotalAllocation_;
        self.totalPotentialReward = newTotalPotentialReward_;

        if (newbackerTotalAllocation_ > self.stakingToken.balanceOf(backer_)) revert NotEnoughStaking();
    }

    /**
     * @notice distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     * @return true if distribution has finished
     */
    // function _distribute() internal returns (bool) {
    //     uint256 _newTotalPotentialReward = tempTotalPotentialReward;
    //     uint256 _gaugeIndex = indexLastGaugeDistributed;
    //     uint256 _gaugesLength = getGaugesLength();
    //     uint256 _lastDistribution = Math.min(_gaugesLength, _gaugeIndex + _MAX_DISTRIBUTIONS_PER_BATCH);

    //     // cache variables read in the loop
    //     uint256 _rewardsERC20 = rewardsERC20;
    //     uint256 _rewardsCoinbase = rewardsCoinbase;
    //     uint256 _totalPotentialReward = totalPotentialReward;
    //     uint256 __periodFinish = _periodFinish;
    //     (uint256 _cycleStart, uint256 _cycleDuration) = getCycleStartAndDuration();
    //     // loop through all pending distributions
    //     while (_gaugeIndex < _lastDistribution) {
    //         _newTotalPotentialReward += _gaugeDistribute(
    //             GaugeRootstockCollective(getGaugeAt(_gaugeIndex)),
    //             _rewardsERC20,
    //             _rewardsCoinbase,
    //             _totalPotentialReward,
    //             __periodFinish,
    //             _cycleStart,
    //             _cycleDuration
    //         );
    //         _gaugeIndex = UtilsLib._uncheckedInc(_gaugeIndex);
    //     }
    //     emit RewardDistributed(msg.sender);
    //     // all the gauges were distributed, so distribution period is finished
    //     if (_lastDistribution == _gaugesLength) {
    //         emit RewardDistributionFinished(msg.sender);
    //         indexLastGaugeDistributed = 0;
    //         rewardsERC20 = rewardsCoinbase = 0;
    //         onDistributionPeriod = false;
    //         tempTotalPotentialReward = 0;
    //         totalPotentialReward = _newTotalPotentialReward;
    //         _periodFinish = cycleNext(block.timestamp);
    //         return true;
    //     }
    //     // Define new reference to batch beginning
    //     indexLastGaugeDistributed = _gaugeIndex;
    //     tempTotalPotentialReward = _newTotalPotentialReward;
    //     return false;
    // }

    /**
     * @notice internal function used to distribute reward tokens to a gauge
     * @param gauge_ address of the gauge to distribute
     * @param rewardsERC20_ ERC20 rewards to distribute
     * @param rewardsCoinbase_ Coinbase rewards to distribute
     * @param totalPotentialReward_ cached total potential reward
     * @param periodFinish_ cached period finish
     * @param cycleStart_ cached cycle start timestamp
     * @param cycleDuration_ cached cycle duration
     * @return newGaugeRewardShares_ new gauge rewardShares, updated after the distribution
     */
    // function _gaugeDistribute(
    //     GaugeRootstockCollective gauge_,
    //     uint256 rewardsERC20_,
    //     uint256 rewardsCoinbase_,
    //     uint256 totalPotentialReward_,
    //     uint256 periodFinish_,
    //     uint256 cycleStart_,
    //     uint256 cycleDuration_
    // )
    //     internal
    //     returns (uint256)
    // {
    //     uint256 _rewardShares = gauge_.rewardShares();
    //     // [N] = [N] * [N] / [N]
    //     uint256 _amountERC20 = (_rewardShares * rewardsERC20_) / totalPotentialReward_;
    //     // [N] = [N] * [N] / [N]
    //     uint256 _amountCoinbase = (_rewardShares * rewardsCoinbase_) / totalPotentialReward_;
    //     uint256 _backerRewardPercentage = getRewardPercentageToApply(gaugeToBuilder[gauge_]);
    //     return gauge_.notifyRewardAmountAndUpdateShares{ value: _amountCoinbase }(
    //         _amountERC20, _backerRewardPercentage, periodFinish_, cycleStart_, cycleDuration_
    //     );
    // }

    // /**
    //  * @notice approves rewardTokens to a given gauge
    //  * @dev give full allowance when it is community approved and remove it when it is dewhitelisted
    //  * @param gauge_ gauge contract to approve rewardTokens
    //  * @param value_ amount of rewardTokens to approve
    //  */
    // function _rewardTokenApprove(address gauge_, uint256 value_) internal override {
    //     IERC20(rewardToken).approve(gauge_, value_);
    // }

    /**
     * @notice removes halted gauge shares to not be accounted on the distribution anymore
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be halted
     */
    // function _haltGaugeShares(GaugeRootstockCollective gauge_) internal override notInDistributionPeriod {
    //     // allocations are not considered for the reward's distribution
    //     totalPotentialReward -= gauge_.rewardShares();
    //     haltedGaugeLastPeriodFinish[gauge_] = _periodFinish;
    // }

    /**
     * @notice adds resumed gauge shares to be accounted on the distribution again
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be resumed
     */
    // function _resumeGaugeShares(GaugeRootstockCollective gauge_) internal override notInDistributionPeriod {
    //     // gauges cannot be resumed before the distribution,
    //     // incentives can stay in the gauge because lastUpdateTime > lastTimeRewardApplicable
    //     if (_periodFinish <= block.timestamp) revert BeforeDistribution();
    //     // allocations are considered again for the reward's distribution
    //     // if there was a distribution we need to update the shares with the full cycle duration
    //     if (haltedGaugeLastPeriodFinish[gauge_] < _periodFinish) {
    //         (uint256 _cycleStart, uint256 _cycleDuration) = getCycleStartAndDuration();
    //         totalPotentialReward += gauge_.notifyRewardAmountAndUpdateShares{ value: 0 }(
    //             0, 0, haltedGaugeLastPeriodFinish[gauge_], _cycleStart, _cycleDuration
    //         );
    //     } else {
    //         // halt and resume were in the same cycle, we don't update the shares
    //         totalPotentialReward += gauge_.rewardShares();
    //     }
    //     haltedGaugeLastPeriodFinish[gauge_] = 0;
    // }

}