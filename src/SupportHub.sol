// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BuilderGaugeFactory } from "./builder/BuilderGaugeFactory.sol";
import { BuilderGauge } from "./builder/BuilderGauge.sol";
import { Governed } from "./governance/Governed.sol";
import { BuilderRegistry } from "./BuilderRegistry.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { EpochLib } from "./libraries/EpochLib.sol";

/**
 * @title SupportHub
 * @notice Creates builder gauges, manages supporters supports and distribute rewards
 */
contract SupportHub is Governed {
    // TODO: MAX_DISTRIBUTIONS_PER_BATCH constant?
    uint256 internal constant MAX_DISTRIBUTIONS_PER_BATCH = 20;

    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error UnequalLengths();
    error BuilderGaugeExists();
    error BuilderGaugeDoesNotExist(address builder_);
    error NotEnoughStaking();
    error OnlyInDistributionWindow();
    error NotInDistributionPeriod();
    error DistributionPeriodDidNotStart();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderGaugeCreated(address indexed builder_, address indexed builderGauge_, address creator_);
    event NewAllocation(address indexed supporter_, address indexed builderGauge_, uint256 allocation_);
    event NotifyReward(address indexed sender_, uint256 amount_);
    event DistributeReward(address indexed sender_, address indexed builderGauge_, uint256 amount_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyInDistributionWindow() {
        if (block.timestamp >= EpochLib.endDistributionWindow(block.timestamp)) revert OnlyInDistributionWindow();
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
    /// @notice address of the token rewarded to builder and supportrs
    IERC20 public rewardToken;
    /// @notice builderGauge factory contract address
    BuilderGaugeFactory public builderGaugeFactory;
    /// @notice builder registry contract address
    BuilderRegistry public builderRegistry;
    /// @notice total allocation on all the builderGauges
    uint256 public totalAllocation;
    /// @notice rewards to distribute per supporter emission [PREC]
    uint256 public rewardsPerShare;
    /// @notice index of tha last builderGauge distributed during a distribution period
    uint256 public indexLastGaugeDistributed;
    /// @notice true if distribution period started. Allocations remain blocked until it finishes
    bool public onDistributionPeriod;

    /// @notice builderGauge contract for a builder
    mapping(address builder => BuilderGauge builderGauge) public builderToGauge;
    /// @notice array of all the builderGauges created
    BuilderGauge[] public builderGauges;
    /// @notice total amount of stakingToken allocated by a supporter
    mapping(address supporter => uint256 allocation) public supporterTotalAllocation;

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
     * @param rewardToken_ address of the token rewarded to builder and supportrs
     * @param stakingToken_ address of the staking token for builder and supportrs
     * @param builderGaugeFactory_ address of the BuilderGaugeFactory contract
     * @param builderRegistry_ address of the BuilderRegistry contract
     */
    function initialize(
        address changeExecutor_,
        address rewardToken_,
        address stakingToken_,
        address builderGaugeFactory_,
        address builderRegistry_
    )
        external
        initializer
    {
        __Governed_init(changeExecutor_);
        rewardToken = IERC20(rewardToken_);
        stakingToken = IERC20(stakingToken_);
        builderGaugeFactory = BuilderGaugeFactory(builderGaugeFactory_);
        builderRegistry = BuilderRegistry(builderRegistry_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice creates a new builder builderGauge for a builder
     * @param builder_ builder address who can claim the rewards
     * @return builderGauge builder builderGauge contract
     */
    function createBuilderGauge(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        returns (BuilderGauge builderGauge)
    {
        // TODO: only if the builder is whitelisted?
        if (address(builderToGauge[builder_]) != address(0)) revert BuilderGaugeExists();
        builderGauge = builderGaugeFactory.createBuilderGauge(builder_, address(rewardToken));
        builderToGauge[builder_] = builderGauge;
        builderGauges.push(builderGauge);
        emit BuilderGaugeCreated(builder_, address(builderGauge), msg.sender);
    }

    /**
     * @notice allocates supports for a builderGauge
     * @dev reverts if it is called during the distribution period
     * @param builderGauge_ address of the builderGauge where the supports will be allocated
     * @param allocation_ amount of supports to allocate
     */
    function allocate(BuilderGauge builderGauge_, uint256 allocation_) external notInDistributionPeriod {
        (uint256 _newSponsorTotalAllocation, uint256 _newTotalAllocation) =
            _allocate(builderGauge_, allocation_, supporterTotalAllocation[msg.sender], totalAllocation);

        _updateAllocation(msg.sender, _newSponsorTotalAllocation, _newTotalAllocation);
    }

    /**
     * @notice allocates supports for a batch of builderGauges
     * @dev reverts if it is called during the distribution period
     * @param builderGauges_ array of builderGauges where the supports will be allocated
     * @param allocations_ array of amount of supports to allocate
     */
    function allocateBatch(
        BuilderGauge[] calldata builderGauges_,
        uint256[] calldata allocations_
    )
        external
        notInDistributionPeriod
    {
        uint256 _length = builderGauges_.length;
        if (_length != allocations_.length) revert UnequalLengths();
        // TODO: check length < MAX or let revert by out of gas?
        uint256 _sponsorTotalAllocation = supporterTotalAllocation[msg.sender];
        uint256 _totalAllocation = totalAllocation;
        for (uint256 i = 0; i < _length; i = UtilsLib.unchecked_inc(i)) {
            (uint256 _newSponsorTotalAllocation, uint256 _newTotalAllocation) =
                _allocate(builderGauges_[i], allocations_[i], _sponsorTotalAllocation, _totalAllocation);
            _sponsorTotalAllocation = _newSponsorTotalAllocation;
            _totalAllocation = _newTotalAllocation;
        }
        _updateAllocation(msg.sender, _sponsorTotalAllocation, _totalAllocation);
    }

    /**
     * @notice transfers reward tokens from the sender to be distributed to the builderGauges
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
     *  until all the builderGauges were distributed
     * @dev reverts if is called outside the distribution window
     *  reverts if it is called during the distribution period
     */
    function startDistribution() external onlyInDistributionWindow notInDistributionPeriod {
        onDistributionPeriod = true;
        distribute();
    }

    /**
     * @notice distribute accumulated reward tokens to the builderGauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all builderGauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     */
    function distribute() public {
        if (onDistributionPeriod == false) revert DistributionPeriodDidNotStart();
        BuilderGauge[] memory _gauges = builderGauges;
        uint256 _gaugeIndex = indexLastGaugeDistributed;
        uint256 _lastDistribution = Math.min(_gauges.length, _gaugeIndex + MAX_DISTRIBUTIONS_PER_BATCH);
        uint256 _rewardsPerShare = rewardsPerShare;
        BuilderRegistry _builderRegistry = builderRegistry;

        // loop through all pending distributions
        while (_gaugeIndex < _lastDistribution) {
            _distribute(_gauges[_gaugeIndex], _rewardsPerShare, _builderRegistry);
            _gaugeIndex = UtilsLib.unchecked_inc(_gaugeIndex);
        }
        // all the builderGauges were distributed, so distribution period is finished
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
     * @notice claims supporter rewards from a batch of builderGauges
     * @param builderGauges_ array of builderGauges to claim
     */
    function claimSponsorRewards(BuilderGauge[] memory builderGauges_) external {
        uint256 _length = builderGauges_.length;
        for (uint256 i = 0; i < _length; i = UtilsLib.unchecked_inc(i)) {
            builderGauges_[i].claimSponsorReward(msg.sender);
        }
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function used to allocate supports for a builderGauge or a batch of builderGauges
     * @param builderGauge_ address of the builderGauge where the supports will be allocated
     * @param allocation_ amount of supports to allocate
     * @param supporterTotalAllocation_ current supporter total allocation
     * @param totalAllocation_ current total allocation
     * @return newSponsorTotalAllocation supporter total allocation after new the allocation
     * @return newTotalAllocation total allocation after the new allocation
     */
    function _allocate(
        BuilderGauge builderGauge_,
        uint256 allocation_,
        uint256 supporterTotalAllocation_,
        uint256 totalAllocation_
    )
        internal
        returns (uint256 newSponsorTotalAllocation, uint256 newTotalAllocation)
    {
        // TODO: validate builderGauge exists, is whitelisted, is not paused
        (uint256 _allocationDeviation, bool _isNegative) = builderGauge_.allocate(msg.sender, allocation_);
        if (_isNegative) {
            newSponsorTotalAllocation = supporterTotalAllocation_ - _allocationDeviation;
            newTotalAllocation = totalAllocation_ - _allocationDeviation;
        } else {
            newSponsorTotalAllocation = supporterTotalAllocation_ + _allocationDeviation;
            newTotalAllocation = totalAllocation_ + _allocationDeviation;
        }
        emit NewAllocation(msg.sender, address(builderGauge_), allocation_);
        return (newSponsorTotalAllocation, newTotalAllocation);
    }

    /**
     * @notice internal function used to update allocation variables
     * @dev reverts if supporter doesn't have enough staking token balance
     * @param supporter_ address of the supporter who allocates
     * @param newSponsorTotalAllocation_ supporter total allocation after new the allocation
     * @param newTotalAllocation_ total allocation after the new allocation
     */
    function _updateAllocation(
        address supporter_,
        uint256 newSponsorTotalAllocation_,
        uint256 newTotalAllocation_
    )
        internal
    {
        supporterTotalAllocation[supporter_] = newSponsorTotalAllocation_;
        totalAllocation = newTotalAllocation_;

        if (newSponsorTotalAllocation_ > stakingToken.balanceOf(supporter_)) revert NotEnoughStaking();
    }

    /**
     * @notice internal function used to distribute reward tokens to a builderGauge
     * @param builderGauge_ address of the builderGauge to distribute
     * @param rewardsPerShare_ cached reward per share
     * @param builderRegistry_ cached builder registry
     */
    function _distribute(
        BuilderGauge builderGauge_,
        uint256 rewardsPerShare_,
        BuilderRegistry builderRegistry_
    )
        internal
    {
        uint256 _reward = UtilsLib._mulPrec(builderGauge_.totalAllocation(), rewardsPerShare_);
        uint256 _sponsorsAmount = builderRegistry_.applyBuilderKickback(builderGauge_.builder(), _reward);
        // [N] = [N] - [N]
        uint256 _builderAmount = _reward - _sponsorsAmount;
        if (_reward > 0) {
            rewardToken.approve(address(builderGauge_), _reward);
            builderGauge_.notifyRewardAmount(_builderAmount, _sponsorsAmount);
            emit DistributeReward(msg.sender, address(builderGauge_), _reward);
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
