// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";

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
        /// @notice address of the token rewarded to builder and voters
        address rewardToken; //Todo: remove from struct
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
    }

    struct GaugeDistribute {
        uint256 _newTotalPotentialReward;
        uint256 _gaugeIndex;
        uint256 _gaugesLength;
        uint256 _lastDistribution;
        uint256 _rewardsERC20;
        uint256 _rewardsCoinbase;
        uint256 _totalPotentialReward;
        uint256 __periodFinish;
        uint256 _cycleStart;
        uint256 _cycleDuration;
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
     * @notice distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     * @return true if distribution has finished
     */
    function _distribute(
        BackerData storage self,
        function (uint256) external view returns (address) getGaugeAt, //  function getGaugeAt(uint256 index_) public view returns (address)
        function (uint256) external returns (uint256) cycleNext, //function cycleNext(uint256 timestamp_) public view returns (uint256)
        function (address) external view returns (uint64) getRewardPercentageToApply,
        GaugeDistribute memory gaugeDistribute,
        mapping(GaugeRootstockCollective => address) storage gaugeToBuilder
    ) public returns (bool) {
        uint256 gIndex = gaugeDistribute._gaugeIndex;
        uint256 _newTotalPotentialReward = gaugeDistribute._newTotalPotentialReward;
        while (gIndex < gaugeDistribute._lastDistribution) {
            GaugeRootstockCollective gauge = GaugeRootstockCollective(getGaugeAt(gIndex));
            _newTotalPotentialReward += _gaugeDistribute(
                getRewardPercentageToApply,
                gauge,
                gaugeDistribute._rewardsERC20,
                gaugeDistribute._rewardsCoinbase,
                gaugeDistribute._totalPotentialReward,
                gaugeDistribute.__periodFinish,
                gaugeDistribute._cycleStart,
                gaugeDistribute._cycleDuration,
                gaugeToBuilder[gauge]
            );
            gIndex = UtilsLib._uncheckedInc(gIndex);
        }
    
        emit RewardDistributed(msg.sender);
        // all the gauges were distributed, so distribution period is finished
        if (gaugeDistribute._lastDistribution == gaugeDistribute._gaugesLength) {
            emit RewardDistributionFinished(msg.sender);
            self.indexLastGaugeDistributed = 0;
            self.rewardsERC20 = self.rewardsCoinbase = 0;
            self.onDistributionPeriod = false;
            self.tempTotalPotentialReward = 0;
            self.totalPotentialReward = _newTotalPotentialReward;
            self._periodFinish = cycleNext(block.timestamp);
            return true;
        }
        // Define new reference to batch beginning
        self.indexLastGaugeDistributed = gIndex;
        self.tempTotalPotentialReward = _newTotalPotentialReward;
        return false;
    }

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
    function _gaugeDistribute(
        function (address) external view returns (uint64) getRewardPercentageToApply, 
        GaugeRootstockCollective gauge_,
        uint256 rewardsERC20_,
        uint256 rewardsCoinbase_,
        uint256 totalPotentialReward_,
        uint256 periodFinish_,
        uint256 cycleStart_,
        uint256 cycleDuration_,
        address gaugeToBuilder
    )
        internal
        returns (uint256)
    {
        uint256 _rewardShares = gauge_.rewardShares();
        // [N] = [N] * [N] / [N]
        uint256 _amountERC20 = (_rewardShares * rewardsERC20_) / totalPotentialReward_;
        // [N] = [N] * [N] / [N]
        uint256 _amountCoinbase = (_rewardShares * rewardsCoinbase_) / totalPotentialReward_;
        uint256 _backerRewardPercentage = getRewardPercentageToApply(gaugeToBuilder);
        return gauge_.notifyRewardAmountAndUpdateShares{ value: _amountCoinbase }(
            _amountERC20, _backerRewardPercentage, periodFinish_, cycleStart_, cycleDuration_
        );
    }
}