// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { BuilderRegistry } from "./BuilderRegistry.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { IGovernanceManager } from "./interfaces/IGovernanceManager.sol";

/**
 * @title SponsorsManager
 * @notice Creates gauges, manages sponsors votes and distribute rewards
 */
contract SponsorsManager is BuilderRegistry {
    // TODO: MAX_DISTRIBUTIONS_PER_BATCH constant?
    uint256 internal constant _MAX_DISTRIBUTIONS_PER_BATCH = 20;

    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error UnequalLengths();
    error NotEnoughStaking();
    error OnlyInDistributionWindow();
    error NotInDistributionPeriod();
    error DistributionPeriodDidNotStart();
    error BeforeDistribution();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewAllocation(address indexed sponsor_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event RewardDistributionStarted(address indexed sender_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyInDistributionWindow() {
        if (block.timestamp >= endDistributionWindow(block.timestamp)) revert OnlyInDistributionWindow();
        _;
    }

    modifier notInDistributionPeriod() {
        if (onDistributionPeriod) revert NotInDistributionPeriod();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token used to stake
    IERC20 public stakingToken;
    /// @notice address of the token rewarded to builder and voters
    address public rewardToken;
    /// @notice total potential reward
    uint256 public totalPotentialReward;
    /// @notice on a paginated distribution we need to temporarily store the totalPotentialReward
    uint256 public tempTotalPotentialReward;
    /// @notice ERC20 rewards to distribute [N]
    uint256 public rewardsERC20;
    /// @notice Coinbase rewards to distribute [N]
    uint256 public rewardsCoinbase;
    /// @notice index of tha last gauge distributed during a distribution period
    uint256 public indexLastGaugeDistributed;
    /// @notice timestamp end of current rewards period
    uint256 internal _periodFinish;
    /// @notice true if distribution period started. Allocations remain blocked until it finishes
    bool public onDistributionPeriod;

    /// @notice total amount of stakingToken allocated by a sponsor
    mapping(address sponsor => uint256 allocation) public sponsorTotalAllocation;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param governanceManager_ contract with permissioned roles
     * @param rewardToken_ address of the token rewarded to builder and voters
     * @param stakingToken_ address of the staking token for builder and voters
     * @param gaugeFactory_ address of the GaugeFactory contract
     * @param rewardDistributor_ address of the rewardDistributor contract
     * @param epochDuration_ epoch time duration
     * @param epochStartOffset_ offset to add to the first epoch, used to set an specific day to start the epochs
     * @param kickbackCooldown_ time that must elapse for a new kickback from a builder to be applied
     */
    function initialize(
        IGovernanceManager governanceManager_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint32 epochDuration_,
        uint24 epochStartOffset_,
        uint128 kickbackCooldown_
    )
        external
        initializer
    {
        __BuilderRegistry_init(
            governanceManager_, gaugeFactory_, rewardDistributor_, epochDuration_, epochStartOffset_, kickbackCooldown_
        );
        rewardToken = rewardToken_;
        stakingToken = IERC20(stakingToken_);
        _periodFinish = epochNext(block.timestamp);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice allocates votes for a gauge
     * @dev reverts if it is called during the distribution period
     *  reverts if gauge does not have a builder associated
     * @param gauge_ address of the gauge where the votes will be allocated
     * @param allocation_ amount of votes to allocate
     */
    function allocate(Gauge gauge_, uint256 allocation_) external notInDistributionPeriod {
        (uint256 _newSponsorTotalAllocation, uint256 _newTotalPotentialReward) = _allocate(
            gauge_,
            allocation_,
            sponsorTotalAllocation[msg.sender],
            totalPotentialReward,
            timeUntilNextEpoch(block.timestamp)
        );

        _updateAllocation(msg.sender, _newSponsorTotalAllocation, _newTotalPotentialReward);
    }

    /**
     * @notice allocates votes for a batch of gauges
     * @dev reverts if it is called during the distribution period
     *  reverts if gauge does not have a builder associated
     * @param gauges_ array of gauges where the votes will be allocated
     * @param allocations_ array of amount of votes to allocate
     */
    function allocateBatch(
        Gauge[] calldata gauges_,
        uint256[] calldata allocations_
    )
        external
        notInDistributionPeriod
    {
        uint256 _length = gauges_.length;
        if (_length != allocations_.length) revert UnequalLengths();
        // TODO: check length < MAX or let revert by out of gas?
        uint256 _sponsorTotalAllocation = sponsorTotalAllocation[msg.sender];
        uint256 _totalPotentialReward = totalPotentialReward;
        uint256 _timeUntilNextEpoch = timeUntilNextEpoch(block.timestamp);
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            (uint256 _newSponsorTotalAllocation, uint256 _newTotalPotentialReward) = _allocate(
                gauges_[i], allocations_[i], _sponsorTotalAllocation, _totalPotentialReward, _timeUntilNextEpoch
            );
            _sponsorTotalAllocation = _newSponsorTotalAllocation;
            _totalPotentialReward = _newTotalPotentialReward;
        }
        _updateAllocation(msg.sender, _sponsorTotalAllocation, _totalPotentialReward);
    }

    /**
     * @notice transfers reward tokens from the sender to be distributed to the gauges
     * @dev reverts if it is called during the distribution period
     */
    function notifyRewardAmount(uint256 amount_) external payable notInDistributionPeriod {
        if (msg.value > 0) {
            rewardsCoinbase += msg.value;
            emit NotifyReward(UtilsLib._COINBASE_ADDRESS, msg.sender, msg.value);
        }
        if (amount_ > 0) {
            rewardsERC20 += amount_;
            emit NotifyReward(rewardToken, msg.sender, amount_);
            SafeERC20.safeTransferFrom(IERC20(rewardToken), msg.sender, address(this), amount_);
        }
    }

    /**
     * @notice starts the distribution period blocking all the allocations
     *  until all the gauges were distributed
     * @dev reverts if is called outside the distribution window
     *  reverts if it is called during the distribution period
     * @return finished_ true if distribution has finished
     */
    function startDistribution() external onlyInDistributionWindow notInDistributionPeriod returns (bool finished_) {
        emit RewardDistributionStarted(msg.sender);
        finished_ = _distribute();
        onDistributionPeriod = !finished_;
    }

    /**
     * @notice continues pagination to distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     * @return finished_ true if distribution has finished
     */
    function distribute() external returns (bool finished_) {
        if (onDistributionPeriod == false) revert DistributionPeriodDidNotStart();
        finished_ = _distribute();
        onDistributionPeriod = !finished_;
    }

    /**
     * @notice claims sponsor rewards from a batch of gauges
     * @param gauges_ array of gauges to claim
     */
    function claimSponsorRewards(Gauge[] memory gauges_) external {
        uint256 _length = gauges_.length;
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            // reverts if builder was not activated or approved by the community
            _validateGauge(gauges_[i]);

            gauges_[i].claimSponsorReward(msg.sender);
        }
    }

    /**
     * @notice returns timestamp end of current rewards period
     *  If it is called by a halted gauge returns the timestamp of the last period distributed
     *  This is important because unclaimed rewards must stop accumulating rewards and halted gauges
     *  are not updated on the distribution anymore
     */
    function periodFinish() external view returns (uint256) {
        if (isGaugeHalted(msg.sender)) return haltedGaugeLastPeriodFinish[Gauge(msg.sender)];
        return _periodFinish;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function used to allocate votes for a gauge or a batch of gauges
     * @param gauge_ address of the gauge where the votes will be allocated
     * @param allocation_ amount of votes to allocate
     * @param sponsorTotalAllocation_ current sponsor total allocation
     * @param totalPotentialReward_ current total potential reward
     * @param timeUntilNextEpoch_ time until next epoch
     * @return newSponsorTotalAllocation_ sponsor total allocation after new the allocation
     * @return newTotalPotentialReward_ total potential reward  after the new allocation
     */
    function _allocate(
        Gauge gauge_,
        uint256 allocation_,
        uint256 sponsorTotalAllocation_,
        uint256 totalPotentialReward_,
        uint256 timeUntilNextEpoch_
    )
        internal
        returns (uint256 newSponsorTotalAllocation_, uint256 newTotalPotentialReward_)
    {
        // reverts if builder was not activated or approved by the community
        _validateGauge(gauge_);

        (uint256 _allocationDeviation, uint256 _rewardSharesDeviation, bool _isNegative) =
            gauge_.allocate(msg.sender, allocation_, timeUntilNextEpoch_);

        // halted gauges are not taken on account for the rewards; newTotalPotentialReward_ == totalPotentialReward_
        if (isGaugeHalted(address(gauge_))) {
            if (_isNegative) {
                newSponsorTotalAllocation_ = sponsorTotalAllocation_ - _allocationDeviation;
            } else {
                newSponsorTotalAllocation_ = sponsorTotalAllocation_ + _allocationDeviation;
            }
            return (newSponsorTotalAllocation_, totalPotentialReward_);
        }

        if (_isNegative) {
            newSponsorTotalAllocation_ = sponsorTotalAllocation_ - _allocationDeviation;
            newTotalPotentialReward_ = totalPotentialReward_ - _rewardSharesDeviation;
        } else {
            newSponsorTotalAllocation_ = sponsorTotalAllocation_ + _allocationDeviation;
            newTotalPotentialReward_ = totalPotentialReward_ + _rewardSharesDeviation;
        }

        emit NewAllocation(msg.sender, address(gauge_), allocation_);
        return (newSponsorTotalAllocation_, newTotalPotentialReward_);
    }

    /**
     * @notice internal function used to update allocation variables
     * @dev reverts if sponsor doesn't have enough staking token balance
     * @param sponsor_ address of the sponsor who allocates
     * @param newSponsorTotalAllocation_ sponsor total allocation after new the allocation
     * @param newTotalPotentialReward_ total potential reward after the new allocation
     */
    function _updateAllocation(
        address sponsor_,
        uint256 newSponsorTotalAllocation_,
        uint256 newTotalPotentialReward_
    )
        internal
    {
        sponsorTotalAllocation[sponsor_] = newSponsorTotalAllocation_;
        totalPotentialReward = newTotalPotentialReward_;

        if (newSponsorTotalAllocation_ > stakingToken.balanceOf(sponsor_)) revert NotEnoughStaking();
    }

    /**
     * @notice distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     * @return true if distribution has finished
     */
    function _distribute() internal returns (bool) {
        uint256 _newTotalPotentialReward = tempTotalPotentialReward;
        uint256 _gaugeIndex = indexLastGaugeDistributed;
        uint256 _gaugesLength = getGaugesLength();
        uint256 _lastDistribution = Math.min(_gaugesLength, _gaugeIndex + _MAX_DISTRIBUTIONS_PER_BATCH);

        // cache variables read in the loop
        uint256 _rewardsERC20 = rewardsERC20;
        uint256 _rewardsCoinbase = rewardsCoinbase;
        uint256 _totalPotentialReward = totalPotentialReward;
        uint256 __periodFinish = _periodFinish;
        (uint256 _epochStart, uint256 _epochDuration) = getEpochStartAndDuration();
        // loop through all pending distributions
        while (_gaugeIndex < _lastDistribution) {
            _newTotalPotentialReward += _gaugeDistribute(
                Gauge(getGaugeAt(_gaugeIndex)),
                _rewardsERC20,
                _rewardsCoinbase,
                _totalPotentialReward,
                __periodFinish,
                _epochStart,
                _epochDuration
            );
            _gaugeIndex = UtilsLib._uncheckedInc(_gaugeIndex);
        }
        emit RewardDistributed(msg.sender);
        // all the gauges were distributed, so distribution period is finished
        if (_lastDistribution == _gaugesLength) {
            emit RewardDistributionFinished(msg.sender);
            indexLastGaugeDistributed = 0;
            rewardsERC20 = rewardsCoinbase = 0;
            onDistributionPeriod = false;
            tempTotalPotentialReward = 0;
            totalPotentialReward = _newTotalPotentialReward;
            _periodFinish = epochNext(block.timestamp);
            return true;
        }
        // Define new reference to batch beginning
        indexLastGaugeDistributed = _gaugeIndex;
        tempTotalPotentialReward = _newTotalPotentialReward;
        return false;
    }

    /**
     * @notice internal function used to distribute reward tokens to a gauge
     * @param gauge_ address of the gauge to distribute
     * @param rewardsERC20_ ERC20 rewards to distribute
     * @param rewardsCoinbase_ Coinbase rewards to distribute
     * @param totalPotentialReward_ cached total potential reward
     * @param periodFinish_ cached period finish
     * @param epochStart_ cached epoch start timestamp
     * @param epochDuration_ cached epoch duration
     * @return newGaugeRewardShares_ new gauge rewardShares, updated after the distribution
     */
    function _gaugeDistribute(
        Gauge gauge_,
        uint256 rewardsERC20_,
        uint256 rewardsCoinbase_,
        uint256 totalPotentialReward_,
        uint256 periodFinish_,
        uint256 epochStart_,
        uint256 epochDuration_
    )
        internal
        returns (uint256)
    {
        uint256 _rewardShares = gauge_.rewardShares();
        // [N] = [N] * [N] / [N]
        uint256 _amountERC20 = (_rewardShares * rewardsERC20_) / totalPotentialReward_;
        // [N] = [N] * [N] / [N]
        uint256 _amountCoinbase = (_rewardShares * rewardsCoinbase_) / totalPotentialReward_;
        uint256 _builderKickback = getKickbackToApply(gaugeToBuilder[gauge_]);
        return gauge_.notifyRewardAmountAndUpdateShares{ value: _amountCoinbase }(
            _amountERC20, _builderKickback, periodFinish_, epochStart_, epochDuration_
        );
    }

    /**
     * @notice approves rewardTokens to a given gauge
     * @dev give full allowance when it is whitelisted and remove it when it is dewhitelisted
     * @param gauge_ gauge contract to approve rewardTokens
     * @param value_ amount of rewardTokens to approve
     */
    function _rewardTokenApprove(address gauge_, uint256 value_) internal override {
        IERC20(rewardToken).approve(gauge_, value_);
    }

    /**
     * @notice removes halted gauge shares to not be accounted on the distribution anymore
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be halted
     */
    function _haltGaugeShares(Gauge gauge_) internal override notInDistributionPeriod {
        // allocations are not considered for the reward's distribution
        totalPotentialReward -= gauge_.rewardShares();
        haltedGaugeLastPeriodFinish[gauge_] = _periodFinish;
    }

    /**
     * @notice adds resumed gauge shares to be accounted on the distribution again
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGaugeShares(Gauge gauge_) internal override notInDistributionPeriod {
        // gauges cannot be resumed before the distribution,
        // incentives can stay in the gauge because lastUpdateTime > lastTimeRewardApplicable
        if (_periodFinish <= block.timestamp) revert BeforeDistribution();
        // allocations are considered again for the reward's distribution
        // if there was a distribution we need to update the shares with the full epoch duration
        if (haltedGaugeLastPeriodFinish[gauge_] < _periodFinish) {
            (uint256 _epochStart, uint256 _epochDuration) = getEpochStartAndDuration();
            totalPotentialReward += gauge_.notifyRewardAmountAndUpdateShares{ value: 0 }(
                0, 0, haltedGaugeLastPeriodFinish[gauge_], _epochStart, _epochDuration
            );
        } else {
            // halt and resume were in the same epoch, we don't update the shares
            totalPotentialReward += gauge_.rewardShares();
        }
        haltedGaugeLastPeriodFinish[gauge_] = 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
