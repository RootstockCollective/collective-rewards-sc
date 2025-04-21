// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "../builderRegistry/BuilderRegistryRootstockCollective.sol";
import { ICollectiveRewardsCheckRootstockCollective } from
    "../interfaces/ICollectiveRewardsCheckRootstockCollective.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { CycleTimeKeeperRootstockCollective } from "./CycleTimeKeeperRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../interfaces/IGovernanceManagerRootstockCollective.sol";

/**
 * @title BackersManagerRootstockCollective
 * @notice Creates gauges, manages backers votes and distribute rewards
 */
contract BackersManagerRootstockCollective is
    CycleTimeKeeperRootstockCollective,
    ICollectiveRewardsCheckRootstockCollective,
    ERC165Upgradeable
{

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
    error NotAuthorized();
    error BackerOptedOutRewards();
    error AlreadyOptedInRewards();
    error BackerHasAllocations();
    error InvalidAddress();
    error RewardTokenNotApproved();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event RewardDistributionStarted(address indexed sender_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);
    event BackerRewardsOptedOut(address indexed backer_);
    event BackerRewardsOptedIn(address indexed backer_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyInDistributionWindow() {
        if (block.timestamp >= endDistributionWindow(block.timestamp)) {
            revert OnlyInDistributionWindow();
        }
        _;
    }

    modifier notInDistributionPeriod() {
        if (onDistributionPeriod) revert NotInDistributionPeriod();
        _;
    }

    modifier onlyBackerOrKycApprover(address account_) {
        if (msg.sender != account_ && msg.sender != governanceManager.kycApprover()) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyBuilderRegistry() {
        if (msg.sender != address(builderRegistry)) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyOptedInBacker() {
        if (rewardsOptedOut[msg.sender]) {
            revert BackerOptedOutRewards();
        }
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice gap to preserve storage layout after removing builder registry from the inheritance tree
    uint256[64] private __gapUpgrade;
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

    /// @notice total amount of stakingToken allocated by a backer
    mapping(address backer => uint256 allocation) public backerTotalAllocation;
    /// @notice address of the builder registry contract
    BuilderRegistryRootstockCollective public builderRegistry;
    /// @notice Tracks whether a backer has opted out from rewards, disabling the allocation to builders if true
    mapping(address backer => bool hasOptedOut) public rewardsOptedOut;

    // -----------------------------
    // ---------- V3 Storage ----------
    // -----------------------------

    uint256 public maxDistributionsPerBatch;

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
     * @param rewardToken_ address of the token rewarded to builder and voters. Only tokens that adhere to the ERC-20
     * standard are supported.
     * @notice For more info on supported tokens, see:
     * https://github.com/RootstockCollective/collective-rewards-sc/blob/main/README.md#Reward-token
     * @param stakingToken_ address of the staking token for builder and voters
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @param cycleStartOffset_ offset to add to the first cycle, used to set an specific day to start the cycles
     * @param distributionDuration_ duration of the distribution window
     */
    function initialize(
        IGovernanceManagerRootstockCollective governanceManager_,
        address rewardToken_,
        address stakingToken_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint32 distributionDuration_
    )
        external
        initializer
    {
        __CycleTimeKeeperRootstockCollective_init(
            governanceManager_, cycleDuration_, cycleStartOffset_, distributionDuration_
        );
        rewardToken = rewardToken_;
        stakingToken = IERC20(stakingToken_);
        _periodFinish = cycleNext(block.timestamp);
    }

    /**
     * @notice contract version 2 initializer
     * @param builderRegistry_ address of the builder registry contract
     */
    function initializeV2(BuilderRegistryRootstockCollective builderRegistry_) external reinitializer(2) {
        if (address(builderRegistry_) == address(0)) revert InvalidAddress();

        builderRegistry = builderRegistry_;
    }

    /**
     * @notice contract version 3 initializer
     * @param maxDistributionsPerBatch_ maximum number of distributions allowed per batch
     */
    function initializeV3(uint256 maxDistributionsPerBatch_) external reinitializer(3) {
        maxDistributionsPerBatch = maxDistributionsPerBatch_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId_) public view override returns (bool) {
        return interfaceId_ == type(ICollectiveRewardsCheckRootstockCollective).interfaceId
            || super.supportsInterface(interfaceId_);
    }

    /**
     * @notice returns true if can withdraw, remaining balance should exceed the current allocation
     * @dev user token balance should already account for the update, meaning the check
     * is applied AFTER the withdraw accounting has become effective.
     * @param targetAddress_ address who wants to withdraw stakingToken
     * param value_ amount of stakingToken to withdraw, not used on current version
     */
    function canWithdraw(address targetAddress_, uint256 /*value_*/ ) external view returns (bool) {
        uint256 _allocation = backerTotalAllocation[targetAddress_];
        if (_allocation == 0) return true;

        return stakingToken.balanceOf(targetAddress_) >= _allocation;
    }

    /**
     * @notice allocates votes for a gauge
     * @dev reverts if it is called during the distribution period
     *  reverts if gauge does not have a builder associated
     * @param gauge_ address of the gauge where the votes will be allocated
     * @param allocation_ amount of votes to allocate
     */
    function allocate(
        GaugeRootstockCollective gauge_,
        uint256 allocation_
    )
        external
        notInDistributionPeriod
        onlyOptedInBacker
    {
        (uint256 _newBackerTotalAllocation, uint256 _newTotalPotentialReward) = _allocate(
            gauge_,
            allocation_,
            backerTotalAllocation[msg.sender],
            totalPotentialReward,
            timeUntilNextCycle(block.timestamp),
            builderRegistry
        );

        _updateAllocation(msg.sender, _newBackerTotalAllocation, _newTotalPotentialReward);
    }

    /**
     * @notice allocates votes for a batch of gauges
     * @dev reverts if it is called during the distribution period
     *  reverts if gauge does not have a builder associated
     * @param gauges_ array of gauges where the votes will be allocated
     * @param allocations_ array of amount of votes to allocate
     */
    function allocateBatch(
        GaugeRootstockCollective[] calldata gauges_,
        uint256[] calldata allocations_
    )
        external
        notInDistributionPeriod
        onlyOptedInBacker
    {
        uint256 _length = gauges_.length;
        if (_length != allocations_.length) revert UnequalLengths();
        uint256 _backerTotalAllocation = backerTotalAllocation[msg.sender];
        uint256 _totalPotentialReward = totalPotentialReward;
        uint256 _timeUntilNextCycle = timeUntilNextCycle(block.timestamp);
        BuilderRegistryRootstockCollective _builderRegistry = builderRegistry;
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            (uint256 _newBackerTotalAllocation, uint256 _newTotalPotentialReward) = _allocate(
                gauges_[i],
                allocations_[i],
                _backerTotalAllocation,
                _totalPotentialReward,
                _timeUntilNextCycle,
                _builderRegistry
            );
            _backerTotalAllocation = _newBackerTotalAllocation;
            _totalPotentialReward = _newTotalPotentialReward;
        }
        _updateAllocation(msg.sender, _backerTotalAllocation, _totalPotentialReward);
    }

    /**
     * @notice transfers reward tokens from the sender to be distributed to the gauges
     * @dev reverts if it is called during the distribution period
     *  reverts if there are no gauges available for the distribution
     */
    function notifyRewardAmount(uint256 amount_) external payable notInDistributionPeriod {
        if (builderRegistry.getGaugesLength() == 0) revert NoGaugesForDistribution();
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
     * @notice claims backer rewards from a batch of gauges
     * @param gauges_ array of gauges to claim
     */
    function claimBackerRewards(GaugeRootstockCollective[] memory gauges_) external {
        uint256 _length = gauges_.length;
        BuilderRegistryRootstockCollective _builderRegistry = builderRegistry;
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            // reverts if builder was not activated or gauge is not assigned to builder
            _builderRegistry.validateWhitelisted(gauges_[i]);

            gauges_[i].claimBackerReward(msg.sender);
        }
    }

    /**
     * @notice claims backer rewards from a batch of gauges
     * @param gauges_ array of gauges to claim
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function claimBackerRewards(address rewardToken_, GaugeRootstockCollective[] memory gauges_) external {
        uint256 _length = gauges_.length;
        BuilderRegistryRootstockCollective _builderRegistry = builderRegistry;
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            if (_builderRegistry.gaugeToBuilder(gauges_[i]) == address(0)) {
                revert BuilderRegistryRootstockCollective.GaugeDoesNotExist();
            }
            gauges_[i].claimBackerReward(rewardToken_, msg.sender);
        }
    }

    /**
     * @notice returns timestamp end of current rewards period
     *  If it is called by a halted gauge returns the timestamp of the last period distributed
     *  This is important because unclaimed rewards must stop accumulating rewards and halted gauges
     *  are not updated on the distribution anymore
     */
    function periodFinish() external view returns (uint256) {
        if (builderRegistry.isGaugeHalted(msg.sender)) {
            return builderRegistry.haltedGaugeLastPeriodFinish(GaugeRootstockCollective(msg.sender));
        }
        return _periodFinish;
    }

    /**
     * @notice Allows a backer to opt out of rewards, preventing them from allocating votes
     *         and claiming rewards in the future.
     *         This action can only be performed by the backer themselves or by the foundation.
     */
    function optOutRewards(address backer_) external onlyBackerOrKycApprover(backer_) {
        if (backerTotalAllocation[backer_] != 0) {
            revert BackerHasAllocations();
        }
        if (rewardsOptedOut[backer_]) {
            revert BackerOptedOutRewards();
        }
        rewardsOptedOut[backer_] = true;
        emit BackerRewardsOptedOut(backer_);
    }

    /**
     * @notice Enables a backer to opt in for rewards, allowing them to allocate votes and claim rewards.
     *         Backers are opted in by default; only those who have opted out can choose to opt in again.
     *         This action can be performed only by the backer themselves or by the foundation.
     */
    function optInRewards(address backer_) external onlyBackerOrKycApprover(backer_) {
        if (!rewardsOptedOut[backer_]) {
            revert AlreadyOptedInRewards();
        }
        rewardsOptedOut[backer_] = false;
        emit BackerRewardsOptedIn(backer_);
    }

    /**
     * @notice This method allows ongoing v1 proposals to be executed after the BackersManager upgrade to v2, by keeping
     * compatibility with the v1 interface.
     */
    function communityApproveBuilder(address builder_)
        external
        onlyValidChanger
        returns (GaugeRootstockCollective gauge_)
    {
        return builderRegistry.communityApproveBuilder(builder_);
    }

    /**
     * @notice Updates the maximum number of distributions allowed per batch.
     * @dev reverts if not called by the upgrader
     * @dev permission will be delegated from upgrader to different role once the GovernanceManagerRootStockCollective contract is upgraded
     */
    function updateMaxDistributionsPerBatch(uint256 maxDistributionsPerBatch_)
        external
    {
        if (msg.sender != governanceManager.upgrader()) {
            revert NotAuthorized();
        }
        maxDistributionsPerBatch = maxDistributionsPerBatch_;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function used to allocate votes for a gauge or a batch of gauges
     * @param gauge_ address of the gauge where the votes will be allocated
     * @param allocation_ amount of votes to allocate
     * @param backerTotalAllocation_ current backer total allocation
     * @param totalPotentialReward_ current total potential reward
     * @param timeUntilNextCycle_ time until next cycle
     * @param builderRegistry_ address of the builder registry contract, passed as parameter to avoid storage reads
     * @return newBackerTotalAllocation_ backer total allocation after new the allocation
     * @return newTotalPotentialReward_ total potential reward  after the new allocation
     */
    function _allocate(
        GaugeRootstockCollective gauge_,
        uint256 allocation_,
        uint256 backerTotalAllocation_,
        uint256 totalPotentialReward_,
        uint256 timeUntilNextCycle_,
        BuilderRegistryRootstockCollective builderRegistry_
    )
        internal
        returns (uint256 newBackerTotalAllocation_, uint256 newTotalPotentialReward_)
    {
        // reverts if builder was not activated or approved by the community
        builderRegistry_.validateWhitelisted(gauge_);

        (uint256 _allocationDeviation, uint256 _rewardSharesDeviation, bool _isNegative) =
            gauge_.allocate(msg.sender, allocation_, timeUntilNextCycle_);

        // halted gauges are not taken into account for the rewards; newTotalPotentialReward_ == totalPotentialReward_
        if (builderRegistry_.isGaugeHalted(address(gauge_))) {
            if (!_isNegative) {
                revert PositiveAllocationOnHaltedGauge();
            }
            newBackerTotalAllocation_ = backerTotalAllocation_ - _allocationDeviation;
            return (newBackerTotalAllocation_, totalPotentialReward_);
        }

        if (_isNegative) {
            newBackerTotalAllocation_ = backerTotalAllocation_ - _allocationDeviation;
            newTotalPotentialReward_ = totalPotentialReward_ - _rewardSharesDeviation;
        } else {
            newBackerTotalAllocation_ = backerTotalAllocation_ + _allocationDeviation;
            newTotalPotentialReward_ = totalPotentialReward_ + _rewardSharesDeviation;
        }

        emit NewAllocation(msg.sender, address(gauge_), allocation_);
        return (newBackerTotalAllocation_, newTotalPotentialReward_);
    }

    /**
     * @notice internal function used to update allocation variables
     * @dev reverts if backer doesn't have enough staking token balance
     * @param backer_ address of the backer who allocates
     * @param newBackerTotalAllocation_ backer total allocation after new the allocation
     * @param newTotalPotentialReward_ total potential reward after the new allocation
     */
    function _updateAllocation(
        address backer_,
        uint256 newBackerTotalAllocation_,
        uint256 newTotalPotentialReward_
    )
        internal
    {
        backerTotalAllocation[backer_] = newBackerTotalAllocation_;
        totalPotentialReward = newTotalPotentialReward_;

        if (newBackerTotalAllocation_ > stakingToken.balanceOf(backer_)) revert NotEnoughStaking();
    }

    /**
     * @notice distribute accumulated reward tokens to the gauges
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     * @return true if distribution has finished
     */
    function _distribute() internal returns (bool) {
        uint256 _newTotalPotentialReward = tempTotalPotentialReward;
        uint256 _gaugeIndex = indexLastGaugeDistributed;
        BuilderRegistryRootstockCollective _builderRegistry = builderRegistry;
        uint256 _gaugesLength = _builderRegistry.getGaugesLength();
        uint256 _lastDistribution = Math.min(_gaugesLength, _gaugeIndex + maxDistributionsPerBatch);

        // cache variables read in the loop
        uint256 _rewardsERC20 = rewardsERC20;
        uint256 _rewardsCoinbase = rewardsCoinbase;
        uint256 _totalPotentialReward = totalPotentialReward;
        uint256 __periodFinish = _periodFinish;
        (uint256 _cycleStart, uint256 _cycleDuration) = getCycleStartAndDuration();

        // no rewards to distribute since there are no allocations
        if (_totalPotentialReward == 0) {
            _finishDistribution();
            return true;
        }

        // loop through all pending distributions
        while (_gaugeIndex < _lastDistribution) {
            _newTotalPotentialReward += _gaugeDistribute(
                GaugeRootstockCollective(_builderRegistry.getGaugeAt(_gaugeIndex)),
                _rewardsERC20,
                _rewardsCoinbase,
                _totalPotentialReward,
                __periodFinish,
                _cycleStart,
                _cycleDuration
            );
            _gaugeIndex = UtilsLib._uncheckedInc(_gaugeIndex);
        }
        emit RewardDistributed(msg.sender);

        // all the gauges were distributed, so distribution period is finished
        if (_lastDistribution == _gaugesLength) {
            _finishDistribution();
            totalPotentialReward = _newTotalPotentialReward;
            rewardsERC20 = rewardsCoinbase = 0;
            return true;
        }

        // Define new reference to batch beginning
        indexLastGaugeDistributed = _gaugeIndex;
        tempTotalPotentialReward = _newTotalPotentialReward;
        return false;
    }

    function _finishDistribution() internal {
        emit RewardDistributionFinished(msg.sender);
        indexLastGaugeDistributed = 0;
        tempTotalPotentialReward = 0;
        _periodFinish = cycleNext(block.timestamp);
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
        GaugeRootstockCollective gauge_,
        uint256 rewardsERC20_,
        uint256 rewardsCoinbase_,
        uint256 totalPotentialReward_,
        uint256 periodFinish_,
        uint256 cycleStart_,
        uint256 cycleDuration_
    )
        internal
        returns (uint256)
    {
        uint256 _rewardShares = gauge_.rewardShares();
        // [N] = [N] * [N] / [N]
        uint256 _amountERC20 = (_rewardShares * rewardsERC20_) / totalPotentialReward_;
        // [N] = [N] * [N] / [N]
        uint256 _amountCoinbase = (_rewardShares * rewardsCoinbase_) / totalPotentialReward_;
        uint256 _backerRewardPercentage =
            builderRegistry.getRewardPercentageToApply(builderRegistry.gaugeToBuilder(gauge_));
        return gauge_.notifyRewardAmountAndUpdateShares{ value: _amountCoinbase }(
            _amountERC20, _backerRewardPercentage, periodFinish_, cycleStart_, cycleDuration_
        );
    }

    /**
     * @notice approves rewardTokens to a given gauge
     * @dev give full allowance when it is community approved and remove it when it is dewhitelisted
     * reverts if the reward token contract returns false on the approval
     * @param gauge_ gauge contract to approve rewardTokens
     * @param value_ amount of rewardTokens to approve
     */
    function rewardTokenApprove(address gauge_, uint256 value_) external onlyBuilderRegistry {
        if(!IERC20(rewardToken).approve(gauge_, value_)) {
            revert RewardTokenNotApproved();
        }
        
    }

    /**
     * @notice removes halted gauge shares to not be accounted on the distribution anymore
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be halted
     */
    function haltGaugeShares(GaugeRootstockCollective gauge_) external onlyBuilderRegistry notInDistributionPeriod {
        // allocations are not considered for the reward's distribution
        totalPotentialReward -= gauge_.rewardShares();
        builderRegistry.setHaltedGaugeLastPeriodFinish(gauge_, _periodFinish);
    }

    /**
     * @notice adds resumed gauge shares to be accounted on the distribution again
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be resumed
     */
    function resumeGaugeShares(GaugeRootstockCollective gauge_) external onlyBuilderRegistry notInDistributionPeriod {
        // gauges cannot be resumed before the distribution,
        // incentives can stay in the gauge because lastUpdateTime > lastTimeRewardApplicable
        if (_periodFinish <= block.timestamp) revert BeforeDistribution();
        // allocations are considered again for the reward's distribution
        // if there was a distribution we need to update the shares with the full cycle duration
        BuilderRegistryRootstockCollective _builderRegistry = builderRegistry;
        if (_builderRegistry.haltedGaugeLastPeriodFinish(gauge_) < _periodFinish) {
            (uint256 _cycleStart, uint256 _cycleDuration) = getCycleStartAndDuration();
            totalPotentialReward += gauge_.notifyRewardAmountAndUpdateShares{ value: 0 }(
                0, 0, _builderRegistry.haltedGaugeLastPeriodFinish(gauge_), _cycleStart, _cycleDuration
            );
        } else {
            // halt and resume were in the same cycle, we don't update the shares
            totalPotentialReward += gauge_.rewardShares();
        }
        _builderRegistry.setHaltedGaugeLastPeriodFinish(gauge_, 0);
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
