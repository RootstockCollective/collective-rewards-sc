// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { IBackersManagerRootstockCollective } from "../interfaces/IBackersManagerRootstockCollective.sol";

/**
 * @title GaugeRootstockCollective
 * @notice For each project proposal a Gauge contract will be deployed.
 *  It receives all the rewards obtained for that project and allows the builder and voters to claim them.
 */
contract GaugeRootstockCollective is ReentrancyGuardUpgradeable {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotAuthorized();
    error NotBackersManager();
    error BuilderRewardsLocked();
    error GaugeHalted();
    error BeforeDistribution();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BackerRewardsClaimed(address indexed rewardToken_, address indexed backer_, uint256 amount_);
    event BuilderRewardsClaimed(address indexed rewardToken_, address indexed builder_, uint256 amount_);
    event NewAllocation(address indexed backer_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, uint256 builderAmount_, uint256 backersAmount_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyBackersManager() {
        if (msg.sender != address(backersManager)) revert NotBackersManager();
        _;
    }

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct RewardData {
        /// @notice current reward rate of rewardToken to distribute per second [PREC]
        uint256 rewardRate;
        /// @notice most recent stored value of rewardPerToken [PREC]
        uint256 rewardPerTokenStored;
        /// @notice missing rewards where there is not allocation [PREC]
        uint256 rewardMissing;
        /// @notice most recent timestamp contract has updated state
        uint256 lastUpdateTime;
        /// @notice amount of unclaimed token reward earned for the builder
        uint256 builderRewards;
        /// @notice cached rewardPerTokenStored for a backer based on their most recent action [PREC]
        mapping(address backer => uint256 rewardPerTokenPaid) backerRewardPerTokenPaid;
        /// @notice cached amount of rewardToken earned for a backer
        mapping(address backer => uint256 rewards) rewards;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token rewarded to builder and voters
    address public rewardToken;
    /// @notice BackersManagerRootstockCollective contract address
    IBackersManagerRootstockCollective public backersManager;
    /// @notice total amount of stakingToken allocated for rewards
    uint256 public totalAllocation;
    /// @notice cycle rewards shares, optimistically tracking the time weighted votes allocations for this gauge
    uint256 public rewardShares;
    /// @notice amount of stakingToken allocated by a backer
    mapping(address backer => uint256 allocation) public allocationOf;
    /// @notice rewards data to each token
    /// @dev address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
    mapping(address rewardToken => RewardData rewardData) public rewardData;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param rewardToken_ address of the token rewarded to builder and voters
     * @param backersManager_ address of the BackersManagerRootstockCollective contract
     */
    function initialize(address rewardToken_, address backersManager_) external initializer {
        __ReentrancyGuard_init();
        rewardToken = rewardToken_;
        backersManager = IBackersManagerRootstockCollective(backersManager_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice gets reward rate
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function rewardRate(address rewardToken_) public view returns (uint256) {
        return rewardData[rewardToken_].rewardRate;
    }

    /**
     * @notice gets reward per token stored
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function rewardPerTokenStored(address rewardToken_) public view returns (uint256) {
        return rewardData[rewardToken_].rewardPerTokenStored;
    }

    /**
     * @notice gets reward missing
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function rewardMissing(address rewardToken_) public view returns (uint256) {
        return rewardData[rewardToken_].rewardMissing;
    }

    /**
     * @notice gets last update time
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function lastUpdateTime(address rewardToken_) public view returns (uint256) {
        return rewardData[rewardToken_].lastUpdateTime;
    }

    /**
     * @notice gets builder rewards
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function builderRewards(address rewardToken_) public view returns (uint256) {
        return rewardData[rewardToken_].builderRewards;
    }

    /**
     * @notice gets backer reward per token paid
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function backerRewardPerTokenPaid(address rewardToken_, address backer_) public view returns (uint256) {
        return rewardData[rewardToken_].backerRewardPerTokenPaid[backer_];
    }

    /**
     * @notice gets amount of rewardToken earned for a backer
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param backer_ address of the backer
     */
    function rewards(address rewardToken_, address backer_) public view returns (uint256) {
        return rewardData[rewardToken_].rewards[backer_];
    }

    /**
     * @notice gets the last time the reward is applicable, now or when the cycle finished
     * @return lastTimeRewardApplicable minimum between current timestamp or periodFinish
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return _lastTimeRewardApplicable(backersManager.periodFinish());
    }

    /**
     * @notice gets the current reward rate per unit of stakingToken allocated
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function rewardPerToken(address rewardToken_) public view returns (uint256) {
        return _rewardPerToken(rewardToken_, backersManager.periodFinish());
    }

    /**
     * @notice gets total amount of rewards to distribute for the current rewards period
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function left(address rewardToken_) external view returns (uint256) {
        RewardData storage _rewardData = rewardData[rewardToken_];
        // [N] = ([N] - [N]) * [PREC] / [PREC]
        return UtilsLib._mulPrec(backersManager.periodFinish() - block.timestamp, _rewardData.rewardRate);
    }

    /**
     * @notice gets `backer_` rewards missing to claim
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param backer_ address who earned the rewards
     */
    function earned(address rewardToken_, address backer_) public view returns (uint256) {
        return _earned(rewardToken_, backer_, backersManager.periodFinish());
    }

    /**
     * @notice claim rewards for a `backer_` address
     * @dev reverts if is not called by the `backer_` or the backersManager
     * @param backer_ address who receives the rewards
     */
    function claimBackerReward(address backer_) public {
        claimBackerReward(rewardToken, backer_);
        claimBackerReward(UtilsLib._COINBASE_ADDRESS, backer_);
    }

    /**
     * @notice claim rewards for a `backer_` address
     * @dev reverts if is not called by the `backer_` or the backersManager
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param backer_ address who receives the rewards
     */
    function claimBackerReward(address rewardToken_, address backer_) public {
        if (msg.sender != backer_ && msg.sender != address(backersManager)) revert NotAuthorized();

        RewardData storage _rewardData = rewardData[rewardToken_];

        _updateRewards(rewardToken_, backer_, backersManager.periodFinish());

        uint256 _reward = _rewardData.rewards[backer_];
        if (_reward > 0) {
            _rewardData.rewards[backer_] = 0;
            _transferRewardToken(rewardToken_, backer_, _reward);
            emit BackerRewardsClaimed(rewardToken_, backer_, _reward);
        }
    }

    /**
     * @notice claim rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
     *  reverts if builder is not operational
     * @dev rewards are transferred to the builder reward receiver
     */
    function claimBuilderReward() public {
        claimBuilderReward(rewardToken);
        claimBuilderReward(UtilsLib._COINBASE_ADDRESS);
    }

    /**
     * @notice claim rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
     * @dev rewards are transferred to the builder reward receiver
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function claimBuilderReward(address rewardToken_) public {
        address _builder = backersManager.gaugeToBuilder(address(this));
        address _rewardReceiver = backersManager.builderRewardReceiver(_builder);
        if (backersManager.isBuilderPaused(_builder)) revert BuilderRewardsLocked();
        if (msg.sender != _builder && msg.sender != _rewardReceiver) revert NotAuthorized();

        RewardData storage _rewardData = rewardData[rewardToken_];

        uint256 _reward = _rewardData.builderRewards;
        if (_reward > 0) {
            _rewardData.builderRewards = 0;
            _transferRewardToken(rewardToken_, _rewardReceiver, _reward);
            emit BuilderRewardsClaimed(rewardToken_, _rewardReceiver, _reward);
        }
    }

    /**
     * @notice moves builder rewards to another address
     *  It is triggered only when the builder is KYC revoked
     * @dev reverts if caller is not the backersManager contract
     * @param to_ address who receives the rewards
     */
    function moveBuilderUnclaimedRewards(address to_) external onlyBackersManager {
        _moveBuilderUnclaimedRewards(rewardToken, to_);
        _moveBuilderUnclaimedRewards(UtilsLib._COINBASE_ADDRESS, to_);
    }

    /**
     * @notice allocates stakingTokens
     * @dev reverts if caller is not the backersManager contract
     * @param backer_ address of user who allocates tokens
     * @param allocation_ amount of tokens to allocate
     * @param timeUntilNextCycle_ time until next cycle
     * @return allocationDeviation_ deviation between current allocation and the new one
     * @return rewardSharesDeviation_  deviation between current reward shares and the new one
     * @return isNegative_ true if new allocation is lesser than the current one
     */
    function allocate(
        address backer_,
        uint256 allocation_,
        uint256 timeUntilNextCycle_
    )
        external
        onlyBackersManager
        returns (uint256 allocationDeviation_, uint256 rewardSharesDeviation_, bool isNegative_)
    {
        uint256 _periodFinish = backersManager.periodFinish();
        // if backers quit before cycle finish we need to store the remaining rewards on first allocation
        // to add it on the next reward distribution
        if (totalAllocation == 0) {
            _updateRewardMissing(rewardToken, _periodFinish);
            _updateRewardMissing(UtilsLib._COINBASE_ADDRESS, _periodFinish);
        }

        _updateRewards(rewardToken, backer_, _periodFinish);
        _updateRewards(UtilsLib._COINBASE_ADDRESS, backer_, _periodFinish);

        // to avoid dealing with signed integers we add allocation if the new one is bigger than the previous one
        uint256 _previousAllocation = allocationOf[backer_];
        if (allocation_ > _previousAllocation) {
            allocationDeviation_ = allocation_ - _previousAllocation;
            rewardSharesDeviation_ = allocationDeviation_ * timeUntilNextCycle_;
            totalAllocation += allocationDeviation_;
            rewardShares += rewardSharesDeviation_;
        } else {
            allocationDeviation_ = _previousAllocation - allocation_;
            // avoid underflow because rewardShares may not be correctly updated if the distribution was skipped
            rewardSharesDeviation_ = Math.min(rewardShares, allocationDeviation_ * timeUntilNextCycle_);
            totalAllocation -= allocationDeviation_;
            rewardShares -= rewardSharesDeviation_;
            isNegative_ = true;
        }
        allocationOf[backer_] = allocation_;

        emit NewAllocation(backer_, allocation_);
        return (allocationDeviation_, rewardSharesDeviation_, isNegative_);
    }

    /**
     * @notice transfers reward tokens to this contract to incentivize backers
     * @dev reverts if Gauge is halted
     *  reverts if distribution for the cycle has not finished
     * @param amount_ amount of reward tokens
     */
    function incentivizeWithRewardToken(uint256 amount_) external {
        // Halted gauges cannot receive rewards because periodFinish is fixed at the last distribution.
        // If new rewards are received, lastUpdateTime will be greater than periodFinish, making it impossible to
        // calculate rewardPerToken
        if (backersManager.isGaugeHalted(address(this))) revert GaugeHalted();
        // Gauges cannot be incentivized before the distribution of the cycle finishes
        if (backersManager.periodFinish() <= block.timestamp) revert BeforeDistribution();

        _notifyRewardAmount(
            rewardToken,
            0, /*builderAmount_*/
            amount_,
            backersManager.periodFinish(),
            backersManager.timeUntilNextCycle(block.timestamp)
        );

        SafeERC20.safeTransferFrom(IERC20(rewardToken), msg.sender, address(this), amount_);
    }

    /**
     * @notice transfers coinbase to this contract to incentivize backers
     * @dev reverts if Gauge is halted
     *  reverts if distribution for the cycle has not finished
     */
    function incentivizeWithCoinbase() external payable {
        // Halted gauges cannot receive rewards because periodFinish is fixed at the last distribution.
        // If new rewards are received, lastUpdateTime will be greater than periodFinish, making it impossible to
        // calculate rewardPerToken
        if (backersManager.isGaugeHalted(address(this))) revert GaugeHalted();
        // Gauges cannot be incentivized before the distribution of the cycle finishes
        if (backersManager.periodFinish() <= block.timestamp) revert BeforeDistribution();

        _notifyRewardAmount(
            UtilsLib._COINBASE_ADDRESS,
            0, /*builderAmount_*/
            msg.value,
            backersManager.periodFinish(),
            backersManager.timeUntilNextCycle(block.timestamp)
        );
    }

    /**
     * @notice called on the reward distribution. Transfers reward tokens from backerManger to this contract
     * @dev reverts if caller is not the backersManager contract
     * @param amountERC20_ amount of ERC20 rewards
     * @param builderRewardPercentage_  builder reward percentage percentage
     * @param periodFinish_ timestamp end of current rewards period
     * @param cycleStart_ Collective Rewards cycle start timestamp
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @return newGaugeRewardShares_ new gauge rewardShares, updated after the distribution
     */
    function notifyRewardAmountAndUpdateShares(
        uint256 amountERC20_,
        uint256 builderRewardPercentage_,
        uint256 periodFinish_,
        uint256 cycleStart_,
        uint256 cycleDuration_
    )
        external
        payable
        onlyBackersManager
        returns (uint256 newGaugeRewardShares_)
    {
        uint256 _backerAmountERC20 = UtilsLib._mulPrec(builderRewardPercentage_, amountERC20_);
        uint256 _backerAmountCoinbase = UtilsLib._mulPrec(builderRewardPercentage_, msg.value);
        uint256 _timeUntilNextCycle = UtilsLib._calcTimeUntilNextCycle(cycleStart_, cycleDuration_, block.timestamp);
        _notifyRewardAmount(
            rewardToken, amountERC20_ - _backerAmountERC20, _backerAmountERC20, periodFinish_, _timeUntilNextCycle
        );
        _notifyRewardAmount(
            UtilsLib._COINBASE_ADDRESS,
            msg.value - _backerAmountCoinbase,
            _backerAmountCoinbase,
            periodFinish_,
            _timeUntilNextCycle
        );

        newGaugeRewardShares_ = totalAllocation * cycleDuration_;
        rewardShares = newGaugeRewardShares_;

        SafeERC20.safeTransferFrom(IERC20(rewardToken), msg.sender, address(this), amountERC20_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice gets the last time the reward is applicable, now or when the cycle finished
     * @param periodFinish_ timestamp end of current rewards period
     * @return lastTimeRewardApplicable minimum between current timestamp or periodFinish
     */
    function _lastTimeRewardApplicable(uint256 periodFinish_) internal view returns (uint256) {
        return Math.min(block.timestamp, periodFinish_);
    }

    /**
     * @notice gets the current reward rate per unit of stakingToken allocated
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param periodFinish_ timestamp end of current rewards period
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function _rewardPerToken(address rewardToken_, uint256 periodFinish_) internal view returns (uint256) {
        RewardData storage _rewardData = rewardData[rewardToken_];

        uint256 _lastUpdateTime = _rewardData.lastUpdateTime;
        uint256 __lastTimeRewardApplicable = _lastTimeRewardApplicable(periodFinish_);
        if (totalAllocation == 0 || _lastUpdateTime >= __lastTimeRewardApplicable) {
            // [PREC]
            return _rewardData.rewardPerTokenStored;
        }

        // [PREC] = (([N] - [N]) * [PREC]) / [N]
        uint256 _rewardPerTokenCurrent =
            ((__lastTimeRewardApplicable - _lastUpdateTime) * _rewardData.rewardRate) / totalAllocation;
        // [PREC] = [PREC] + [PREC]
        return _rewardData.rewardPerTokenStored + _rewardPerTokenCurrent;
    }

    /**
     * @notice gets `backer_` rewards missing to claim
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param backer_ address who earned the rewards
     * @param periodFinish_ timestamp end of current rewards period
     */
    function _earned(address rewardToken_, address backer_, uint256 periodFinish_) internal view returns (uint256) {
        RewardData storage _rewardData = rewardData[rewardToken_];

        // [N] = ([N] * ([PREC] - [PREC]) / [PREC])
        uint256 _currentReward = UtilsLib._mulPrec(
            allocationOf[backer_],
            _rewardPerToken(rewardToken_, periodFinish_) - _rewardData.backerRewardPerTokenPaid[backer_]
        );
        // [N] = [N] + [N]
        return _rewardData.rewards[backer_] + _currentReward;
    }

    /**
     * @notice transfers reward tokens to this contract
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param builderAmount_ amount of rewards for the builder
     * @param backersAmount_ amount of rewards for the backers
     * @param periodFinish_ timestamp end of current rewards period
     * @param timeUntilNextCycle_ time until next cycle
     */
    function _notifyRewardAmount(
        address rewardToken_,
        uint256 builderAmount_,
        uint256 backersAmount_,
        uint256 periodFinish_,
        uint256 timeUntilNextCycle_
    )
        internal
    {
        RewardData storage _rewardData = rewardData[rewardToken_];
        // cache storage variables used multiple times
        uint256 _rewardRate = _rewardData.rewardRate;
        uint256 _leftover = 0;

        // if period finished there is not remaining reward
        if (block.timestamp < periodFinish_) {
            // [PREC] = [N] * [PREC]
            _leftover = (timeUntilNextCycle_) * _rewardRate;
        }

        // if there are no allocations we need to update rewardMissing to avoid losing the previous rewards
        if (totalAllocation == 0) {
            _updateRewardMissing(rewardToken_, periodFinish_);
        }

        // [PREC] = ([N] * [PREC] + [PREC] + [PREC]) / [N]
        _rewardRate =
            (backersAmount_ * UtilsLib._PRECISION + _rewardData.rewardMissing + _leftover) / timeUntilNextCycle_;

        _rewardData.builderRewards += builderAmount_;
        _rewardData.rewardPerTokenStored = _rewardPerToken(rewardToken_, periodFinish_);
        _rewardData.lastUpdateTime = block.timestamp;
        _rewardData.rewardMissing = 0;
        _rewardData.rewardRate = _rewardRate;

        emit NotifyReward(rewardToken_, builderAmount_, backersAmount_);
    }

    /**
     * @notice update rewards variables when a backer interacts
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param backer_ address of the backers
     * @param periodFinish_ timestamp end of current rewards period
     */
    function _updateRewards(address rewardToken_, address backer_, uint256 periodFinish_) internal {
        RewardData storage _rewardData = rewardData[rewardToken_];

        _rewardData.rewardPerTokenStored = _rewardPerToken(rewardToken_, periodFinish_);
        _rewardData.lastUpdateTime = _lastTimeRewardApplicable(periodFinish_);
        _rewardData.rewards[backer_] = _earned(rewardToken_, backer_, periodFinish_);
        _rewardData.backerRewardPerTokenPaid[backer_] = _rewardData.rewardPerTokenStored;
    }

    /**
     * @notice update reward missing variable
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param periodFinish_ timestamp end of current rewards period
     */
    function _updateRewardMissing(address rewardToken_, uint256 periodFinish_) internal {
        RewardData storage _rewardData = rewardData[rewardToken_];
        uint256 _lastUpdateTime = _rewardData.lastUpdateTime;
        uint256 __lastTimeRewardApplicable = _lastTimeRewardApplicable(periodFinish_);
        if (_lastUpdateTime >= __lastTimeRewardApplicable) {
            return;
        }
        // [PREC] = [PREC] + ([N] - [N]) * [PREC]
        _rewardData.rewardMissing += (__lastTimeRewardApplicable - _lastUpdateTime) * _rewardData.rewardRate;
    }

    /**
     * @notice transfers reward token
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param to_ address who receives the tokens
     * @param amount_ amount of tokens to send
     */
    function _transferRewardToken(address rewardToken_, address to_, uint256 amount_) internal nonReentrant {
        if (rewardToken_ == UtilsLib._COINBASE_ADDRESS) {
            Address.sendValue(payable(to_), amount_);
        } else {
            SafeERC20.safeTransfer(IERC20(rewardToken_), to_, amount_);
        }
    }

    /**
     * @notice moves builder rewards to another address
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param to_ address who receives the rewards
     */
    function _moveBuilderUnclaimedRewards(address rewardToken_, address to_) internal {
        uint256 _rewardTokenAmount = rewardData[rewardToken_].builderRewards;
        if (_rewardTokenAmount > 0) {
            rewardData[rewardToken_].builderRewards = 0;
            _transferRewardToken(rewardToken_, to_, _rewardTokenAmount);
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
