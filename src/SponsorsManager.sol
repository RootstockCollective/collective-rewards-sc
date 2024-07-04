// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { GaugeFactory } from "./gauge/GaugeFactory.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";

contract SponsorsManager {
    /// @notice Rewards are released over 7 days
    // TODO: DURATION & MAX_DISTRIBUTIONS_PER_BATCH constant?
    uint256 internal constant DURATION = 7 days;
    uint256 internal constant MAX_DISTRIBUTIONS_PER_BATCH = 20;

    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error UnequalLengths();
    error GaugeExists();
    error GaugeDoesNotExist(address builder_);
    error NotEnoughStaking();
    error OnDistributionPeriod();
    error DistributionPeriodDidNotStart();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
    event NewAllocation(address indexed sponsor_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed sender_, uint256 amount_);
    event DistributeReward(address indexed sender_, address indexed gauge_, uint256 amount_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier nonOnDistributionPeriod() {
        if (onDistributionPeriod) revert OnDistributionPeriod();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token used to stake
    IERC20 public immutable stakingToken;
    /// @notice address of the token rewarded to builder and voters
    IERC20 public immutable rewardToken;
    // @notice address of gauge factory contract
    GaugeFactory public immutable gaugeFactory;
    // @notice total allocation on all the gauges
    uint256 public totalAllocation;
    /// @notice accumulated distributions per sponsor emission [PREC]
    uint256 public rate;
    /// @notice index of tha last gauge distributed during a distribution period
    uint256 public indexLastGaugeDistributed;
    // @notice true if distribution period started. Allocations and gauge creations remains blocked until finish
    bool public onDistributionPeriod;

    /// @notice gauge contract for a builder
    mapping(address builder => Gauge gauge) public gauges;
    /// @notice array of all the gauges created
    Gauge[] public gaugesArray;
    /// @notice total amount of stakingToken allocated by a sponsor
    mapping(address sponsor => uint256 allocation) public sponsorTotalAllocation;
    /// @notice accumulated distributions for a gauge [PREC]
    mapping(Gauge gauge => uint256 rate) internal gaugeRate;

    constructor(address rewardToken_, address stakingToken_, address gaugeFactory_) {
        rewardToken = IERC20(rewardToken_);
        stakingToken = IERC20(stakingToken_);
        gaugeFactory = GaugeFactory(gaugeFactory_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice creates a new gauge for a builder
     * @dev reverts if it is called during the distribution period
     * @param builder_ builder address who can claim the rewards
     * @return gauge gauge contract
     */
    function createGauge(address builder_) external nonOnDistributionPeriod returns (Gauge gauge) {
        if (address(gauges[builder_]) != address(0)) revert GaugeExists();
        gauge = gaugeFactory.createGauge(builder_, address(rewardToken));
        gauges[builder_] = gauge;
        gaugesArray.push(gauge);
        emit GaugeCreated(builder_, address(gauge), msg.sender);
    }

    /**
     * @notice allocates staking tokens for a gauge
     * @dev reverts if it is called during the distribution period
     * @param gauge_ address of the gauge where the tokens will be allocated
     * @param allocation_ amount of tokens to allocate
     */
    function allocate(Gauge gauge_, uint256 allocation_) external nonOnDistributionPeriod {
        (uint256 _newSponsorTotalAllocation, uint256 _newTotalAllocation) =
            _allocate(gauge_, allocation_, sponsorTotalAllocation[msg.sender], totalAllocation);

        _updateAllocation(msg.sender, _newSponsorTotalAllocation, _newTotalAllocation);
    }

    /**
     * @notice allocates staking tokens for a batch of gauges
     * @dev reverts if it is called during the distribution period
     * @param gauges_ array of gauges where the tokens will be allocated
     * @param allocations_ array of amount of tokens to allocate
     */
    function allocateBatch(
        Gauge[] calldata gauges_,
        uint256[] calldata allocations_
    )
        external
        nonOnDistributionPeriod
    {
        uint256 _length = gauges_.length;
        if (_length != allocations_.length) revert UnequalLengths();
        // TODO: check length < MAX or let revert by out of gas?
        uint256 _sponsorTotalAllocation = sponsorTotalAllocation[msg.sender];
        uint256 _totalAllocation = totalAllocation;
        for (uint256 i = 0; i < _length; i = UtilsLib.unchecked_inc(i)) {
            (uint256 _newSponsorTotalAllocation, uint256 _newTotalAllocation) =
                _allocate(gauges_[i], allocations_[i], _sponsorTotalAllocation, _totalAllocation);
            _sponsorTotalAllocation = _newSponsorTotalAllocation;
            _totalAllocation = _newTotalAllocation;
        }
        _updateAllocation(msg.sender, _sponsorTotalAllocation, _totalAllocation);
    }

    /**
     * @notice transfers reward tokens from the sender to be distributed to the gauges
     * @dev starts the distribution period blocking all the allocations and gauge creations
     *  until all the gauges were distributed
     * @param amount_ amount of reward tokens to distribute
     */
    function notifyRewardAmount(uint256 amount_) external {
        // TODO: this function should revert if is not called by treasury or rewardManager
        // because it will start the distribution period blocking new allocations

        onDistributionPeriod = true;
        // if there is no allocation let it revert by division zero
        // [PREC] = [N] * [PREC] / [N]
        rate += UtilsLib._divPrec(amount_, totalAllocation);

        emit NotifyReward(msg.sender, amount_);
        SafeERC20.safeTransferFrom(rewardToken, msg.sender, address(this), amount_);
    }

    /**
     * @notice distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This functions is paginated and finish one the distribution period all the gauges
     *  were distributed
     */
    function _distribute() external {
        if (onDistributionPeriod == false) revert DistributionPeriodDidNotStart();
        Gauge[] memory _gaugesArray = gaugesArray;
        uint256 _gaugeIndex = indexLastGaugeDistributed;
        uint256 _lastDistribution = Math.min(_gaugesArray.length, _gaugeIndex + MAX_DISTRIBUTIONS_PER_BATCH);
        // loop through all pending distributions
        while (_gaugeIndex < _lastDistribution) {
            _distribute(_gaugesArray[_gaugeIndex]);
            _gaugeIndex = UtilsLib.unchecked_inc(_gaugeIndex);
        }
        // all the gauges were distributed, so distribution period is finished
        if (_lastDistribution == _gaugesArray.length) {
            indexLastGaugeDistributed = 0;
            onDistributionPeriod = false;
        } else {
            // Define new reference to batch beginning
            indexLastGaugeDistributed = _gaugeIndex;
        }
    }

    /**
     * @notice claims rewards form a batch of gauges
     * @param gauges_ array of gauges to claim
     */
    function claimRewards(Gauge[] memory gauges_) external {
        uint256 _length = gauges_.length;
        for (uint256 i = 0; i < _length; i = UtilsLib.unchecked_inc(i)) {
            gauges_[i].getSponsorReward(msg.sender);
        }
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function used to allocate staking tokens for a gauge or a batch of gauges
     * @param gauge_ address of the gauge where the tokens will be allocated
     * @param allocation_ amount of tokens to allocate
     * @param sponsorTotalAllocation_ current sponsor total allocation
     * @param totalAllocation_ current total allocation
     * @return newSponsorTotalAllocation sponsor total allocation after new the allocation
     * @return newTotalAllocation total allocation after the new allocation
     */
    function _allocate(
        Gauge gauge_,
        uint256 allocation_,
        uint256 sponsorTotalAllocation_,
        uint256 totalAllocation_
    )
        internal
        returns (uint256 newSponsorTotalAllocation, uint256 newTotalAllocation)
    {
        // TODO: validate gauge exists, is whitelisted, is not paused
        (uint256 _allocationDeviation, bool _isNegative) = gauge_.allocate(msg.sender, allocation_);
        if (_isNegative) {
            newSponsorTotalAllocation = sponsorTotalAllocation_ - _allocationDeviation;
            newTotalAllocation = totalAllocation_ - _allocationDeviation;
        } else {
            newSponsorTotalAllocation = sponsorTotalAllocation_ + _allocationDeviation;
            newTotalAllocation = totalAllocation_ + _allocationDeviation;
        }
        emit NewAllocation(msg.sender, address(gauge_), allocation_);
        return (newSponsorTotalAllocation, newTotalAllocation);
    }

    /**
     * @notice internal function used to update allocation variables
     * @dev reverts if sponsor doesn't have enough staking token balance
     * @param sponsor_ address of the sponsor who allocates
     * @param newSponsorTotalAllocation_ sponsor total allocation after new the allocation
     * @param newTotalAllocation_ total allocation after the new allocation
     */
    function _updateAllocation(
        address sponsor_,
        uint256 newSponsorTotalAllocation_,
        uint256 newTotalAllocation_
    )
        internal
    {
        sponsorTotalAllocation[sponsor_] = newSponsorTotalAllocation_;
        totalAllocation = newTotalAllocation_;

        if (newSponsorTotalAllocation_ > stakingToken.balanceOf(sponsor_)) revert NotEnoughStaking();
    }

    /**
     * @notice internal function used to distribute reward tokens to a gauge
     * @param gauge_ address of the gauge to distribute
     */
    function _distribute(Gauge gauge_) internal {
        uint256 _claimable = _updateFor(gauge_);
        if (_claimable > gauge_.left() && _claimable > DURATION) {
            rewardToken.approve(address(gauge_), _claimable);
            gauge_.notifyRewardAmount(_claimable);
            emit DistributeReward(msg.sender, address(gauge_), _claimable);
        }
    }

    /**
     * @notice gets how many reward tokens can be claimed for a gauge
     * @param gauge_ address of the gauge
     * @return claimable amount of reward tokens to claim
     */
    function _updateFor(Gauge gauge_) internal returns (uint256 claimable) {
        uint256 _gaugeAllocation = gauge_.totalAllocation();
        if (_gaugeAllocation > 0) {
            // cache rate variable used multiple times
            uint256 _rate = rate;
            // calculate delta between gauge previous rate and the current one
            uint256 _delta = _rate - gaugeRate[gauge_];
            // if there are tokens to claim
            if (_delta > 0) {
                // update gauge with the current rate
                gaugeRate[gauge_] = _rate;
                // [N] = [N] * [PREC] / [PREC]
                claimable = UtilsLib._mulPrec(_gaugeAllocation, _delta);
                // TODO: review this
                // if (isAlive[_gauge]) {
                //     claimable[gauge_] += _share;
                // } else {
                // TODO: transfer to treasury or keep here?
                //SafeERC20.safeTransfer(rewardToken, minter, _share);
                // send rewards back to Minter so they're not stuck in Voter
                // }
            }
        } else {
            // new gauges are set to the default global state
            gaugeRate[gauge_] = rate;
        }
    }
}
