// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { BuilderRegistry } from "./BuilderRegistry.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { EpochLib } from "./libraries/EpochLib.sol";

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
        if (block.timestamp >= EpochLib._endDistributionWindow(block.timestamp)) revert OnlyInDistributionWindow();
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
    uint256 public periodFinish;
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
     * @param changeExecutor_ See Governed doc
     * @param kycApprover_ See BuilderRegistry doc
     * @param rewardToken_ address of the token rewarded to builder and voters
     * @param stakingToken_ address of the staking token for builder and voters
     * @param gaugeFactory_ address of the GaugeFactory contract
     * @param kickbackCooldown_ time that must elapse for a new kickback from a builder to be applied
     */
    function initialize(
        address changeExecutor_,
        address kycApprover_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        uint256 kickbackCooldown_
    )
        external
        initializer
    {
        __BuilderRegistry_init(changeExecutor_, kycApprover_, gaugeFactory_, kickbackCooldown_);
        rewardToken = rewardToken_;
        stakingToken = IERC20(stakingToken_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice allocates votes for a gauge
     * @dev reverts if it is called during the distribution period
     * @param gauge_ address of the gauge where the votes will be allocated
     * @param allocation_ amount of votes to allocate
     */
    function allocate(Gauge gauge_, uint256 allocation_) external notInDistributionPeriod {
        (uint256 _newSponsorTotalAllocation, uint256 _newTotalPotentialReward) =
            _allocate(gauge_, allocation_, sponsorTotalAllocation[msg.sender], totalPotentialReward);

        _updateAllocation(msg.sender, _newSponsorTotalAllocation, _newTotalPotentialReward);
    }

    /**
     * @notice allocates votes for a batch of gauges
     * @dev reverts if it is called during the distribution period
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
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            (uint256 _newSponsorTotalAllocation, uint256 _newTotalPotentialReward) =
                _allocate(gauges_[i], allocations_[i], _sponsorTotalAllocation, _totalPotentialReward);
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
     */
    function startDistribution() external onlyInDistributionWindow notInDistributionPeriod {
        onDistributionPeriod = true;
        emit RewardDistributionStarted(msg.sender);
        distribute();
    }

    /**
     * @notice distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     */
    function distribute() public {
        if (onDistributionPeriod == false) revert DistributionPeriodDidNotStart();
        Gauge[] memory _gauges = gauges;
        uint256 _newTotalPotentialReward = tempTotalPotentialReward;
        uint256 _gaugeIndex = indexLastGaugeDistributed;
        uint256 _lastDistribution = Math.min(_gauges.length, _gaugeIndex + _MAX_DISTRIBUTIONS_PER_BATCH);

        // cache variables read in the loop
        uint256 _rewardsERC20 = rewardsERC20;
        uint256 _rewardsCoinbase = rewardsCoinbase;
        uint256 _totalPotentialReward = totalPotentialReward;
        // loop through all pending distributions
        while (_gaugeIndex < _lastDistribution) {
            _newTotalPotentialReward +=
                _distribute(_gauges[_gaugeIndex], _rewardsERC20, _rewardsCoinbase, _totalPotentialReward);
            _gaugeIndex = UtilsLib._uncheckedInc(_gaugeIndex);
        }
        emit RewardDistributed(msg.sender);
        // all the gauges were distributed, so distribution period is finished
        if (_lastDistribution == _gauges.length) {
            emit RewardDistributionFinished(msg.sender);
            indexLastGaugeDistributed = 0;
            rewardsERC20 = rewardsCoinbase = 0;
            onDistributionPeriod = false;
            tempTotalPotentialReward = 0;
            totalPotentialReward = _newTotalPotentialReward;
            periodFinish = EpochLib._epochNext(block.timestamp);
        } else {
            // Define new reference to batch beginning
            indexLastGaugeDistributed = _gaugeIndex;
            tempTotalPotentialReward = _newTotalPotentialReward;
        }
    }

    /**
     * @notice claims sponsor rewards from a batch of gauges
     * @param gauges_ array of gauges to claim
     */
    function claimSponsorRewards(Gauge[] memory gauges_) external {
        uint256 _length = gauges_.length;
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            gauges_[i].claimSponsorReward(msg.sender);
        }
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
     * @return newSponsorTotalAllocation_ sponsor total allocation after new the allocation
     * @return newTotalPotentialReward_ total potential reward  after the new allocation
     */
    function _allocate(
        Gauge gauge_,
        uint256 allocation_,
        uint256 sponsorTotalAllocation_,
        uint256 totalPotentialReward_
    )
        internal
        returns (uint256 newSponsorTotalAllocation_, uint256 newTotalPotentialReward_)
    {
        // TODO: validate gauge exists, is whitelisted, is not paused
        uint256 _timeUntilNext = EpochLib._epochNext(block.timestamp) - block.timestamp;
        (uint256 _allocationDeviation, bool _isNegative) = gauge_.allocate(msg.sender, allocation_);
        if (_isNegative) {
            newSponsorTotalAllocation_ = sponsorTotalAllocation_ - _allocationDeviation;
            newTotalPotentialReward_ = totalPotentialReward_ - (_allocationDeviation * _timeUntilNext);
        } else {
            newSponsorTotalAllocation_ = sponsorTotalAllocation_ + _allocationDeviation;
            newTotalPotentialReward_ = totalPotentialReward_ + (_allocationDeviation * _timeUntilNext);
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
     * @notice internal function used to distribute reward tokens to a gauge
     * @param gauge_ address of the gauge to distribute
     * @param rewardsERC20_ ERC20 rewards to distribute
     * @param rewardsCoinbase_ Coinbase rewards to distribute
     * @param totalPotentialReward_ cached total potential reward
     * @return newGaugeRewardShares_ new gauge rewardShares, updated after the distribution
     */
    function _distribute(
        Gauge gauge_,
        uint256 rewardsERC20_,
        uint256 rewardsCoinbase_,
        uint256 totalPotentialReward_
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
        IERC20(rewardToken).approve(address(gauge_), _amountERC20);
        return gauge_.notifyRewardAmountAndUpdateShares{ value: _amountCoinbase }(_amountERC20, _builderKickback);
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
