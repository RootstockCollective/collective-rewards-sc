// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "./BuilderRegistryRootstockCollective.sol";
import { ICollectiveRewardsCheckRootstockCollective } from
    "../interfaces/ICollectiveRewardsCheckRootstockCollective.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { BackersManagerLib } from "../libraries/BackersManagerLib.sol";
import { IGovernanceManagerRootstockCollective } from "../interfaces/IGovernanceManagerRootstockCollective.sol";

/**
 * @title BackersManagerRootstockCollective
 * @notice Creates gauges, manages backers votes and distribute rewards
 */
contract BackersManagerRootstockCollective is
    ICollectiveRewardsCheckRootstockCollective,
    BuilderRegistryRootstockCollective
{
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
    error PositiveAllocationOnHaltedGauge();
    error NoGaugesForDistribution();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    // event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    // event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    // event RewardDistributionStarted(address indexed sender_);
    // event RewardDistributed(address indexed sender_);
    // event RewardDistributionFinished(address indexed sender_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyInDistributionWindow() {
        if (block.timestamp >= endDistributionWindow(block.timestamp)) revert OnlyInDistributionWindow();
        _;
    }

    modifier notInDistributionPeriod() {
        if (backersManagerData.onDistributionPeriod) revert NotInDistributionPeriod();
        _;
    }

    /*
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
    */
   
    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------
    /// @notice address of the token used to stake
    IERC20 public stakingToken;
    /// @notice total amount of stakingToken allocated by a backer
    mapping(address backer => uint256 allocation) public backerTotalAllocation;

    BackersManagerLib.BackerData public backersManagerData;

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
     * @param rewardToken_ address of the token rewarded to builder and voters, only standard ERC20 MUST be used
     * @param stakingToken_ address of the staking token for builder and voters
     * @param gaugeFactory_ address of the GaugeFactoryRootstockCollective contract
     * @param rewardDistributor_ address of the rewardDistributor contract
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @param cycleStartOffset_ offset to add to the first cycle, used to set an specific day to start the cycles
     * @param rewardPercentageCooldown_ time that must elapse for a new reward percentage from a builder to be applied
     * @param distributionDuration_ duration of the distribution window
     */
    function initialize(
        IGovernanceManagerRootstockCollective governanceManager_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint32 distributionDuration_,
        uint128 rewardPercentageCooldown_
    )
        external
        initializer
    {
        __BuilderRegistryRootstockCollective_init(
            governanceManager_,
            gaugeFactory_,
            rewardDistributor_,
            cycleDuration_,
            cycleStartOffset_,
            distributionDuration_,
            rewardPercentageCooldown_
        );
        stakingToken = IERC20(stakingToken_);
        backersManagerData.rewardToken = rewardToken_;
        backersManagerData._periodFinish = cycleNext(block.timestamp);
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
    function allocate(GaugeRootstockCollective gauge_, uint256 allocation_) external notInDistributionPeriod {
        (uint256 _newbackerTotalAllocation, uint256 _newTotalPotentialReward) = _allocate(
            gauge_,
            allocation_,
            backerTotalAllocation[msg.sender],
            backersManagerData.totalPotentialReward,
            timeUntilNextCycle(block.timestamp)
        );

        _updateAllocation(msg.sender, _newbackerTotalAllocation, _newTotalPotentialReward);
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
    {
        uint256 _length = gauges_.length;
        if (_length != allocations_.length) revert UnequalLengths();
        // TODO: check length < MAX or let revert by out of gas?
        uint256 _backerTotalAllocation = backerTotalAllocation[msg.sender];
        uint256 _totalPotentialReward = backersManagerData.totalPotentialReward;
        uint256 _timeUntilNextCycle = timeUntilNextCycle(block.timestamp);
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            (uint256 _newbackerTotalAllocation, uint256 _newTotalPotentialReward) = _allocate(
                gauges_[i], allocations_[i], _backerTotalAllocation, _totalPotentialReward, _timeUntilNextCycle
            );
            _backerTotalAllocation = _newbackerTotalAllocation;
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
        if (getGaugesLength() == 0) revert NoGaugesForDistribution();
        if (msg.value > 0) {
            backersManagerData.rewardsCoinbase += msg.value;
            emit BackersManagerLib.NotifyReward(UtilsLib._COINBASE_ADDRESS, msg.sender, msg.value);
        }
        if (amount_ > 0) {
            backersManagerData.rewardsERC20 += amount_;
            emit BackersManagerLib.NotifyReward(backersManagerData.rewardToken, msg.sender, amount_);
            SafeERC20.safeTransferFrom(IERC20(backersManagerData.rewardToken), msg.sender, address(this), amount_);
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
        emit BackersManagerLib.RewardDistributionStarted(msg.sender);
        finished_ = _distribute();
        backersManagerData.onDistributionPeriod = !finished_;
    }

    /**
     * @notice continues pagination to distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     * @return finished_ true if distribution has finished
     */
    function distribute() external returns (bool finished_) {
        if (backersManagerData.onDistributionPeriod == false) revert BackersManagerLib.DistributionPeriodDidNotStart();
        finished_ = _distribute();
        backersManagerData.onDistributionPeriod = !finished_;
    }

    /**
     * @notice claims backer rewards from a batch of gauges
     * @param gauges_ array of gauges to claim
     */
    function claimBackerRewards(GaugeRootstockCollective[] memory gauges_) external {
        uint256 _length = gauges_.length;
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            // reverts if builder was not activated or approved by the community
            _validateWhitelisted(gauges_[i]);

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
        for (uint256 i = 0; i < _length; i = UtilsLib._uncheckedInc(i)) {
            if (gaugeToBuilder[gauges_[i]] == address(0)) revert GaugeDoesNotExist();
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
        if (isGaugeHalted(msg.sender)) return haltedGaugeLastPeriodFinish[GaugeRootstockCollective(msg.sender)];
        return backersManagerData._periodFinish;
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
     * @return newbackerTotalAllocation_ backer total allocation after new the allocation
     * @return newTotalPotentialReward_ total potential reward  after the new allocation
     */
    function _allocate(
        GaugeRootstockCollective gauge_,
        uint256 allocation_,
        uint256 backerTotalAllocation_,
        uint256 totalPotentialReward_,
        uint256 timeUntilNextCycle_
    )
        internal
        returns (uint256 newbackerTotalAllocation_, uint256 newTotalPotentialReward_)
    {
        // reverts if builder was not activated or approved by the community
        _validateWhitelisted(gauge_);

        (uint256 _allocationDeviation, uint256 _rewardSharesDeviation, bool _isNegative) =
            gauge_.allocate(msg.sender, allocation_, timeUntilNextCycle_);

        (newbackerTotalAllocation_, newTotalPotentialReward_) = BackersManagerLib
            ._allocate(
                this.isGaugeHalted,
                gauge_,
                allocation_,
                backerTotalAllocation_,
                totalPotentialReward_,
                _allocationDeviation,
                _rewardSharesDeviation,
                _isNegative
            );
    }

    /**
     * @notice internal function used to update allocation variables
     * @dev reverts if backer doesn't have enough staking token balance
     * @param backer_ address of the backer who allocates
     * @param newbackerTotalAllocation_ backer total allocation after new the allocation
     * @param newTotalPotentialReward_ total potential reward after the new allocation
     */
    function _updateAllocation(
        address backer_,
        uint256 newbackerTotalAllocation_,
        uint256 newTotalPotentialReward_
    )
        internal
    {
        backerTotalAllocation[backer_] = newbackerTotalAllocation_;
        backersManagerData.totalPotentialReward = newTotalPotentialReward_;

        if (newbackerTotalAllocation_ > stakingToken.balanceOf(backer_)) revert NotEnoughStaking();
    }

    /**
     * @notice distribute accumulated reward tokens to the gauges
     * @dev reverts if distribution period has not yet started
     *  This function is paginated and it finishes once all gauges distribution are completed,
     *  ending the distribution period and voting restrictions.
     * @return true if distribution has finished
     */
    function _distribute() internal returns (bool) {
        (uint256 _cycleStart, uint256 _cycleDuration) = getCycleStartAndDuration();
        // uint256 _newTotalPotentialReward = backersManagerData.tempTotalPotentialReward;
        uint256 gIndex = backersManagerData.indexLastGaugeDistributed;
        uint256 gLength = getGaugesLength();
        uint256 lDistribution = Math.min(gLength, gIndex + _MAX_DISTRIBUTIONS_PER_BATCH);


        BackersManagerLib.GaugeDistribute memory _gDistribute = BackersManagerLib.GaugeDistribute({
            _newTotalPotentialReward:backersManagerData.tempTotalPotentialReward,
            _gaugeIndex:gIndex,
            _gaugesLength:gLength,
            _lastDistribution:lDistribution,
            _rewardsERC20:backersManagerData.rewardsERC20,
            _rewardsCoinbase:backersManagerData.rewardsCoinbase,
            _totalPotentialReward:backersManagerData.totalPotentialReward,
            __periodFinish:backersManagerData._periodFinish,
            _cycleStart:_cycleStart,
            _cycleDuration:_cycleDuration
        });

        bool distributed = BackersManagerLib._distribute(
            backersManagerData,
            this.getGaugeAt,
            this.cycleNext,
            this.getRewardPercentageToApply,
            _gDistribute,
            gaugeToBuilder            
        );
        return distributed;
    }

    /**
     * @notice approves rewardTokens to a given gauge
     * @dev give full allowance when it is community approved and remove it when it is dewhitelisted
     * @param gauge_ gauge contract to approve rewardTokens
     * @param value_ amount of rewardTokens to approve
     */
    function _rewardTokenApprove(address gauge_, uint256 value_) internal override {
        IERC20(backersManagerData.rewardToken).approve(gauge_, value_);
    }

    /**
     * @notice removes halted gauge shares to not be accounted on the distribution anymore
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be halted
     */
    function _haltGaugeShares(GaugeRootstockCollective gauge_) internal override notInDistributionPeriod {
        // allocations are not considered for the reward's distribution
        backersManagerData.totalPotentialReward -= gauge_.rewardShares();
        haltedGaugeLastPeriodFinish[gauge_] = backersManagerData._periodFinish;
    }

    /**
     * @notice adds resumed gauge shares to be accounted on the distribution again
     * @dev reverts if it is executed in distribution period because changing the totalPotentialReward
     * produce a miscalculation of rewards
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGaugeShares(GaugeRootstockCollective gauge_) internal override notInDistributionPeriod {
        // gauges cannot be resumed before the distribution,
        // incentives can stay in the gauge because lastUpdateTime > lastTimeRewardApplicable
        if (backersManagerData._periodFinish <= block.timestamp) revert BeforeDistribution();
        // allocations are considered again for the reward's distribution
        // if there was a distribution we need to update the shares with the full cycle duration
        if (haltedGaugeLastPeriodFinish[gauge_] < backersManagerData._periodFinish) {
            (uint256 _cycleStart, uint256 _cycleDuration) = getCycleStartAndDuration();
            backersManagerData.totalPotentialReward += gauge_.notifyRewardAmountAndUpdateShares{ value: 0 }(
                0, 0, haltedGaugeLastPeriodFinish[gauge_], _cycleStart, _cycleDuration
            );
        } else {
            // halt and resume were in the same cycle, we don't update the shares
            backersManagerData.totalPotentialReward += gauge_.rewardShares();
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
