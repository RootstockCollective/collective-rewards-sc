// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { GaugeFactory } from "./gauge/GaugeFactory.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { Governed } from "./governance/Governed.sol";
import { BuilderRegistry } from "./BuilderRegistry.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { EpochLib } from "./libraries/EpochLib.sol";

/**
 * @title SponsorsManager
 * @notice Creates gauges, manages sponsors votes and distribute rewards
 */
contract SponsorsManager is Governed {
    // TODO: MAX_DISTRIBUTIONS_PER_BATCH constant?
    uint256 internal constant _MAX_DISTRIBUTIONS_PER_BATCH = 20;

    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error UnequalLengths();
    error GaugeExists();
    error GaugeDoesNotExist(address builder_);
    error NotEnoughStaking();
    error OnlyInDistributionWindow();
    error NotInDistributionPeriod();
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
    IERC20 public rewardToken;
    /// @notice gauge factory contract address
    GaugeFactory public gaugeFactory;
    /// @notice builder registry contract address
    BuilderRegistry public builderRegistry;
    /// @notice total allocation on all the gauges
    uint256 public totalAllocation;
    /// @notice rewards to distribute per sponsor emission [PREC]
    uint256 public rewardsPerShare;
    /// @notice index of tha last gauge distributed during a distribution period
    uint256 public indexLastGaugeDistributed;
    /// @notice true if distribution period started. Allocations remain blocked until it finishes
    bool public onDistributionPeriod;

    /// @notice gauge contract for a builder
    mapping(address builder => Gauge gauge) public builderToGauge;
    /// @notice array of all the gauges created
    Gauge[] public gauges;
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
     * @param rewardToken_ address of the token rewarded to builder and voters
     * @param stakingToken_ address of the staking token for builder and voters
     * @param gaugeFactory_ address of the GaugeFactory contract
     * @param builderRegistry_ address of the BuilderRegistry contract
     */
    function initialize(
        address changeExecutor_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        address builderRegistry_
    )
        external
        initializer
    {
        __Governed_init(changeExecutor_);
        rewardToken = IERC20(rewardToken_);
        stakingToken = IERC20(stakingToken_);
        gaugeFactory = GaugeFactory(gaugeFactory_);
        builderRegistry = BuilderRegistry(builderRegistry_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice creates a new gauge for a builder
     * @param builder_ builder address who can claim the rewards
     * @return gauge gauge contract
     */
    function createGauge(address builder_) external onlyGovernorOrAuthorizedChanger returns (Gauge gauge) {
        // TODO: only if the builder is whitelisted?
        if (address(builderToGauge[builder_]) != address(0)) revert GaugeExists();
        gauge = gaugeFactory.createGauge(builder_, address(rewardToken));
        builderToGauge[builder_] = gauge;
        gauges.push(gauge);
        emit GaugeCreated(builder_, address(gauge), msg.sender);
    }

    /**
     * @notice allocates votes for a gauge
     * @dev reverts if it is called during the distribution period
     * @param gauge_ address of the gauge where the votes will be allocated
     * @param allocation_ amount of votes to allocate
     */
    function allocate(Gauge gauge_, uint256 allocation_) external notInDistributionPeriod {
        (uint256 _newSponsorTotalAllocation, uint256 _newTotalAllocation) =
            _allocate(gauge_, allocation_, sponsorTotalAllocation[msg.sender], totalAllocation);

        _updateAllocation(msg.sender, _newSponsorTotalAllocation, _newTotalAllocation);
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
        uint256 _totalAllocation = totalAllocation;
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            (uint256 _newSponsorTotalAllocation, uint256 _newTotalAllocation) =
                _allocate(gauges_[i], allocations_[i], _sponsorTotalAllocation, _totalAllocation);
            _sponsorTotalAllocation = _newSponsorTotalAllocation;
            _totalAllocation = _newTotalAllocation;
        }
        _updateAllocation(msg.sender, _sponsorTotalAllocation, _totalAllocation);
    }

    /**
     * @notice transfers reward tokens from the sender to be distributed to the gauges
     * @dev reverts if it is called during the distribution period
     * @param amount_ amount of reward tokens to distribute
     */
    function notifyRewardAmount(uint256 amount_) external notInDistributionPeriod {
        // if there is no allocation let it revert by division zero
        // [PREC] = [N] * [PREC] / [N]
        rewardsPerShare += UtilsLib._divPrec(amount_, totalAllocation);

        emit NotifyReward(msg.sender, amount_);
        SafeERC20.safeTransferFrom(rewardToken, msg.sender, address(this), amount_);
    }

    /**
     * @notice starts the distribution period blocking all the allocations
     *  until all the gauges were distributed
     * @dev reverts if is called outside the distribution window
     *  reverts if it is called during the distribution period
     */
    function startDistribution() external onlyInDistributionWindow notInDistributionPeriod {
        onDistributionPeriod = true;
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
        uint256 _gaugeIndex = indexLastGaugeDistributed;
        uint256 _lastDistribution = Math.min(_gauges.length, _gaugeIndex + _MAX_DISTRIBUTIONS_PER_BATCH);
        uint256 _rewardsPerShare = rewardsPerShare;
        BuilderRegistry _builderRegistry = builderRegistry;

        // loop through all pending distributions
        while (_gaugeIndex < _lastDistribution) {
            _distribute(_gauges[_gaugeIndex], _rewardsPerShare, _builderRegistry);
            _gaugeIndex = UtilsLib._uncheckedInc(_gaugeIndex);
        }
        // all the gauges were distributed, so distribution period is finished
        if (_lastDistribution == _gauges.length) {
            indexLastGaugeDistributed = 0;
            rewardsPerShare = 0;
            onDistributionPeriod = false;
        } else {
            // Define new reference to batch beginning
            indexLastGaugeDistributed = _gaugeIndex;
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
     * @param rewardsPerShare_ cached reward per share
     * @param builderRegistry_ cached builder registry
     */
    function _distribute(Gauge gauge_, uint256 rewardsPerShare_, BuilderRegistry builderRegistry_) internal {
        uint256 _reward = UtilsLib._mulPrec(gauge_.totalAllocation(), rewardsPerShare_);
        uint256 _sponsorsAmount = builderRegistry_.applyBuilderKickback(gauge_.builder(), _reward);
        // [N] = [N] - [N]
        uint256 _builderAmount = _reward - _sponsorsAmount;
        if (_reward > 0) {
            rewardToken.approve(address(gauge_), _reward);
            gauge_.notifyRewardAmount(_builderAmount, _sponsorsAmount);
            emit DistributeReward(msg.sender, address(gauge_), _reward);
        }
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
