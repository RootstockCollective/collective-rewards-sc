// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { BuilderRegistryRootstockCollective } from "../builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "../backersManager/BackersManagerRootstockCollective.sol";

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
    error GaugeHalted();
    error BeforeDistribution();
    error NotEnoughAmount();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BackerRewardsClaimed(address indexed rewardToken_, address indexed backer_, uint256 amount_);
    event BuilderRewardsClaimed(address indexed rewardToken_, address indexed builder_, uint256 amount_);
    event NotifyReward(address indexed rewardToken_, uint256 builderAmount_, uint256 backersAmount_);
    event RewardSharesUpdated(uint256 rewardShares_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyAuthorizedContract() {
        if (msg.sender != address(builderRegistry) && msg.sender != address(backersManager)) revert NotAuthorized();
        _;
    }

    /**
     * @notice prevents spamming of incentives mechanism with low values to introduce errors
     * @dev 100 should cover any potential rounding errors
     */
    modifier minIncentiveAmount(uint256 amount_) {
        if (amount_ < UtilsLib.MIN_AMOUNT_INCENTIVES) revert NotEnoughAmount();
        _;
    }

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct RewardData {
        /// @notice current reward rate of reward token to distribute per second [PREC]
        uint256 rewardRate;
        /// @notice most recent stored value of rewardPerToken [PREC]
        uint256 rewardPerTokenStored;
        /// @notice missing rewards where there is not allocation [PREC]
        uint256 rewardMissing;
        /// @notice most recent timestamp contract has updated state
        uint256 lastUpdateTime;
        /// @notice amount of unclaimed reward token earned for the builder
        uint256 builderRewards;
        /// @notice cached rewardPerTokenStored for a backer based on their most recent action [PREC]
        mapping(address backer => uint256 rewardPerTokenPaid) backerRewardPerTokenPaid;
        /// @notice cached amount of reward token earned for a backer
        mapping(address backer => uint256 rewards) rewards;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of rif token rewarded to builder and backers
    address public rifToken;
    /// @notice BackersManagerRootstockCollective contract address
    BackersManagerRootstockCollective public backersManager;
    /// @notice total amount of stakingToken allocated for rewards
    uint256 public totalAllocation;
    /// @notice cycle rewards shares, optimistically tracking the time weighted votes allocations for this gauge
    uint256 public rewardShares;
    /// @notice amount of stakingToken allocated by a backer
    mapping(address backer => uint256 allocation) public allocationOf;
    /// @notice rewards data to each token
    /// @dev address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
    mapping(address rifToken => RewardData rewardData) public rewardData;
    /// @notice BuilderRegistryRootstockCollective contract address
    BuilderRegistryRootstockCollective public builderRegistry;

    // -----------------------------
    // -------- V3 Storage ---------
    // -----------------------------

    /// @notice address of usdRif token rewarded to builder and backers
    address public usdrifToken;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param rifToken_ address of the token rewarded to builder and voters. Only tokens that adhere to the ERC-20
     * standard are supported.
     * @param usdrifToken_ address of the USDRIF token rewarded to builder and voters. Only tokens that adhere to the
     * ERC-20 standard are supported.
     * @notice For more info on supported tokens, see:
     * https://github.com/RootstockCollective/collective-rewards-sc/blob/main/README.md#Reward-token
     * @param builderRegistry_ address of the builder registry contract
     */
    function initialize(address rifToken_, address usdrifToken_, address builderRegistry_) external initializer {
        __ReentrancyGuard_init();
        rifToken = rifToken_;
        usdrifToken = usdrifToken_;

        builderRegistry = BuilderRegistryRootstockCollective(builderRegistry_);
        backersManager = BackersManagerRootstockCollective(builderRegistry.backersManager());
    }

    /**
     * @notice contract initializer
     * @param usdrifToken_ address of the token rewarded to builder and voters. Only tokens that adhere to the
     * ERC-20
     * standard are supported.
     * @notice For more info on supported tokens, see:
     * https://github.com/RootstockCollective/collective-rewards-sc/blob/main/README.md#Reward-token
     */
    function initializeV3(address usdrifToken_) external reinitializer(3) {
        __ReentrancyGuard_init();
        usdrifToken = usdrifToken_;
    }

    // NOTE: This contract previously included an `initializeV2()` function using `reinitializer(2)`
    // to set the `builderRegistry` from `backersManager.builderRegistry()` during an upgrade to version 2.
    // The function has been removed since the upgrade was already executed and it's no longer necessary.

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice gets reward rate
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function rewardRate(address rewardToken_) external view returns (uint256) {
        return rewardData[rewardToken_].rewardRate;
    }

    /**
     * @notice gets reward per token stored
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function rewardPerTokenStored(address rewardToken_) external view returns (uint256) {
        return rewardData[rewardToken_].rewardPerTokenStored;
    }

    /**
     * @notice gets reward missing
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function rewardMissing(address rewardToken_) external view returns (uint256) {
        return rewardData[rewardToken_].rewardMissing;
    }

    /**
     * @notice gets last update time
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function lastUpdateTime(address rewardToken_) external view returns (uint256) {
        return rewardData[rewardToken_].lastUpdateTime;
    }

    /**
     * @notice gets builder rewards
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function builderRewards(address rewardToken_) external view returns (uint256) {
        return rewardData[rewardToken_].builderRewards;
    }

    /**
     * @notice gets backer reward per token paid
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function backerRewardPerTokenPaid(address rewardToken_, address backer_) external view returns (uint256) {
        return rewardData[rewardToken_].backerRewardPerTokenPaid[backer_];
    }

    /**
     * @notice gets the estimated amount of rifToken left to earn for a backer in current cycle
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     * @param backer_ address of the backer
     */
    function estimatedBackerRewards(address rewardToken_, address backer_) external view returns (uint256) {
        // No allocations or a new cycle started without a distribution
        if (totalAllocation == 0 || backersManager.periodFinish() <= block.timestamp) {
            return 0;
        }
        // [N] = [N] * [N] / [N]
        return (_left(rewardToken_) * allocationOf[backer_]) / totalAllocation;
    }

    /**
     * @notice gets amount of rifToken earned for a backer
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     * @param backer_ address of the backer
     */
    function rewards(address rewardToken_, address backer_) external view returns (uint256) {
        return rewardData[rewardToken_].rewards[backer_];
    }

    /**
     * @notice gets the last time the reward is applicable, now or when the cycle finished
     * @return lastTimeRewardApplicable minimum between current timestamp or periodFinish
     */
    function lastTimeRewardApplicable() external view returns (uint256) {
        return _lastTimeRewardApplicable(backersManager.periodFinish());
    }

    /**
     * @notice gets the current reward rate per unit of stakingToken allocated
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function rewardPerToken(address rewardToken_) external view returns (uint256) {
        return _rewardPerToken(rewardToken_, backersManager.periodFinish());
    }

    /**
     * @notice gets total amount of rewards to distribute for the current rewards period
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function left(address rewardToken_) external view returns (uint256) {
        return _left(rewardToken_);
    }

    /**
     * @notice gets `backer_` rewards missing to claim
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     * @param backer_ address who earned the rewards
     */
    function earned(address rewardToken_, address backer_) external view returns (uint256) {
        return _earned(rewardToken_, backer_, backersManager.periodFinish());
    }

    /**
     * @notice claim rewards for a `backer_` address
     * @dev reverts if is not called by the `backer_` or the backersManager
     * @param backer_ address who receives the rewards
     */
    function claimBackerReward(address backer_) external {
        claimBackerReward(rifToken, backer_);
        claimBackerReward(usdrifToken, backer_);
        claimBackerReward(UtilsLib._NATIVE_ADDRESS, backer_);
    }

    /**
     * @notice claim rewards for a `backer_` address
     * @dev reverts if is not called by the `backer_` or the backersManager
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
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
    function claimBuilderReward() external {
        claimBuilderReward(rifToken);
        claimBuilderReward(usdrifToken);
        claimBuilderReward(UtilsLib._NATIVE_ADDRESS);
    }

    /**
     * @notice claim rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
     * @dev rewards are transferred to the builder reward receiver
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function claimBuilderReward(address rewardToken_) public {
        address _rewardReceiver = builderRegistry.canClaimBuilderReward(msg.sender);

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
    function moveBuilderUnclaimedRewards(address to_) external onlyAuthorizedContract {
        _moveBuilderUnclaimedRewards(rifToken, to_);
        _moveBuilderUnclaimedRewards(usdrifToken, to_);
        _moveBuilderUnclaimedRewards(UtilsLib._NATIVE_ADDRESS, to_);
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
        onlyAuthorizedContract
        returns (uint256 allocationDeviation_, uint256 rewardSharesDeviation_, bool isNegative_)
    {
        uint256 _periodFinish = backersManager.periodFinish();
        // if backers quit before cycle finish we need to store the remaining rewards on first allocation
        // to add it on the next reward distribution
        if (totalAllocation == 0) {
            _updateRewardMissing(rifToken, _periodFinish);
            _updateRewardMissing(usdrifToken, _periodFinish);
            _updateRewardMissing(UtilsLib._NATIVE_ADDRESS, _periodFinish);
        }

        _updateRewards(rifToken, backer_, _periodFinish);
        _updateRewards(usdrifToken, backer_, _periodFinish);
        _updateRewards(UtilsLib._NATIVE_ADDRESS, backer_, _periodFinish);

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
        return (allocationDeviation_, rewardSharesDeviation_, isNegative_);
    }

    // NOTE: incentivize functions should be generalized into one which takes the address of the corresponding reward
    // function
    /**
     * @notice transfers RIF tokens to this contract to incentivize backers
     * @dev reverts if Gauge is halted
     *  reverts if distribution for the cycle has not finished
     * @param amount_ amount of RIF tokens
     */
    function incentivizeWithRifToken(uint256 amount_) external {
        _incentivizeWithRewardToken(amount_, rifToken);
    }

    /**
     * @notice transfers USDRIF tokens to this contract to incentivize backers
     * @dev reverts if Gauge is halted
     *  reverts if distribution for the cycle has not finished
     * @param amount_ amount of USDRIF tokens
     */
    function incentivizeWithUsdrifToken(uint256 amount_) external {
        _incentivizeWithRewardToken(amount_, usdrifToken);
    }

    /**
     * @notice transfers native tokens to this contract to incentivize backers
     * @dev reverts if Gauge is halted
     *  reverts if distribution for the cycle has not finished
     */
    function incentivizeWithNative() external payable minIncentiveAmount(msg.value) {
        // Halted gauges cannot receive rewards because periodFinish is fixed at the last distribution.
        // If new rewards are received, lastUpdateTime will be greater than periodFinish, making it impossible to
        // calculate rewardPerToken
        if (builderRegistry.isGaugeHalted(address(this))) revert GaugeHalted();
        // Gauges cannot be incentivized before the distribution of the cycle finishes
        if (backersManager.periodFinish() <= block.timestamp) revert BeforeDistribution();

        _notifyRewardAmount(
            UtilsLib._NATIVE_ADDRESS,
            0, /*builderAmount_*/
            msg.value,
            backersManager.periodFinish(),
            backersManager.timeUntilNextCycle(block.timestamp),
            false /*resetRewardMissing_*/
        );
    }

    /**
     * @notice called on the reward distribution. Transfers reward tokens from backerManger to this contract
     * @dev reverts if caller is not the backersManager contract
     * @param amountRif_ amount of ERC20 RIF rewards
     * @param amountUsdrif_ amount of ERC20 USDRIF rewards
     * @param backerRewardPercentage_  backers reward percentage
     * @param periodFinish_ timestamp end of current rewards period
     * @param cycleStart_ Collective Rewards cycle start timestamp
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @return newGaugeRewardShares_ new gauge rewardShares, updated after the distribution
     */
    function notifyRewardAmountAndUpdateShares(
        uint256 amountRif_,
        uint256 amountUsdrif_,
        uint256 backerRewardPercentage_,
        uint256 periodFinish_,
        uint256 cycleStart_,
        uint256 cycleDuration_
    )
        external
        payable
        onlyAuthorizedContract
        returns (uint256 newGaugeRewardShares_)
    {
        uint256 _backerAmountRif = UtilsLib._mulPrec(backerRewardPercentage_, amountRif_);
        uint256 _backerAmountUsdrif = UtilsLib._mulPrec(backerRewardPercentage_, amountUsdrif_);
        uint256 _backerAmountNative = UtilsLib._mulPrec(backerRewardPercentage_, msg.value);
        uint256 _timeUntilNextCycle = UtilsLib._calcTimeUntilNextCycle(cycleStart_, cycleDuration_, block.timestamp);
        // On a distribution, we include any reward missing into the new reward rate and reset it
        bool _resetRewardMissing = true;
        _notifyRewardAmount(
            rifToken,
            amountRif_ - _backerAmountRif,
            _backerAmountRif,
            periodFinish_,
            _timeUntilNextCycle,
            _resetRewardMissing
        );
        _notifyRewardAmount(
            usdrifToken,
            amountUsdrif_ - _backerAmountUsdrif,
            _backerAmountUsdrif,
            periodFinish_,
            _timeUntilNextCycle,
            _resetRewardMissing
        );
        _notifyRewardAmount(
            UtilsLib._NATIVE_ADDRESS,
            msg.value - _backerAmountNative,
            _backerAmountNative,
            periodFinish_,
            _timeUntilNextCycle,
            _resetRewardMissing
        );

        newGaugeRewardShares_ = totalAllocation * cycleDuration_;
        rewardShares = newGaugeRewardShares_;

        SafeERC20.safeTransferFrom(IERC20(rifToken), msg.sender, address(this), amountRif_);
        SafeERC20.safeTransferFrom(IERC20(usdrifToken), msg.sender, address(this), amountUsdrif_);

        emit RewardSharesUpdated(rewardShares);
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
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
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
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
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
     * @notice gets total amount of rewards to distribute for the current rewards period
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     */
    function _left(address rewardToken_) internal view returns (uint256) {
        // [N] = ([N] - [N]) * [PREC] / [PREC]
        return UtilsLib._mulPrec(backersManager.periodFinish() - block.timestamp, rewardData[rewardToken_].rewardRate);
    }

    /**
     * @notice transfers reward tokens to this contract
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     * @param builderAmount_ amount of rewards for the builder
     * @param backersAmount_ amount of rewards for the backers
     * @param periodFinish_ timestamp end of current rewards period
     * @param timeUntilNextCycle_ time until next cycle
     * @param resetRewardMissing_ true if reward missing accounted for new rewardRate, and be reset
     */
    function _notifyRewardAmount(
        address rewardToken_,
        uint256 builderAmount_,
        uint256 backersAmount_,
        uint256 periodFinish_,
        uint256 timeUntilNextCycle_,
        bool resetRewardMissing_
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

        // [PREC] = ([N] * [PREC] + [PREC])
        uint256 _rateNumerator = backersAmount_ * UtilsLib._PRECISION + _leftover;
        if (resetRewardMissing_) {
            // [PREC] += [PREC]
            _rateNumerator += _rewardData.rewardMissing;
            // As rewardMissing are now accounted on the rate, we can reset them
            _rewardData.rewardMissing = 0;
        }

        // [PREC] = [PREC] / [N]
        _rewardRate = _rateNumerator / timeUntilNextCycle_;

        _rewardData.builderRewards += builderAmount_;
        _rewardData.rewardPerTokenStored = _rewardPerToken(rewardToken_, periodFinish_);
        _rewardData.lastUpdateTime = block.timestamp;
        _rewardData.rewardRate = _rewardRate;

        emit NotifyReward(rewardToken_, builderAmount_, backersAmount_);
    }

    /**
     * @notice update rewards variables when a backer interacts
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
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
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
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
     * @notice transfers reward tokens
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     * @param to_ address who receives the tokens
     * @param amount_ amount of tokens to send
     */
    function _transferRewardToken(address rewardToken_, address to_, uint256 amount_) internal nonReentrant {
        if (rewardToken_ == UtilsLib._NATIVE_ADDRESS) {
            Address.sendValue(payable(to_), amount_);
        } else {
            SafeERC20.safeTransfer(IERC20(rewardToken_), to_, amount_);
        }
    }

    /**
     * @notice moves builder rewards to another address
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for native tokens address
     * @param to_ address who receives the rewards
     */
    function _moveBuilderUnclaimedRewards(address rewardToken_, address to_) internal {
        uint256 _rewardTokenAmount = rewardData[rewardToken_].builderRewards;
        if (_rewardTokenAmount > 0) {
            rewardData[rewardToken_].builderRewards = 0;
            _transferRewardToken(rewardToken_, to_, _rewardTokenAmount);
        }
    }

    function _incentivizeWithRewardToken(uint256 amount_, address rewardToken_) internal minIncentiveAmount(amount_) {
        // Halted gauges cannot receive rewards because periodFinish is fixed at the last distribution.
        // If new rewards are received, lastUpdateTime will be greater than periodFinish, making it impossible to
        // calculate rewardPerToken
        if (builderRegistry.isGaugeHalted(address(this))) revert GaugeHalted();
        // Gauges cannot be incentivized before the distribution of the cycle finishes
        if (backersManager.periodFinish() <= block.timestamp) revert BeforeDistribution();

        if (
            IERC20(rewardToken_).balanceOf(msg.sender) < amount_
                || IERC20(rewardToken_).allowance(msg.sender, address(this)) < amount_
        ) {
            revert NotEnoughAmount();
        }

        _notifyRewardAmount(
            rewardToken_,
            0, /*builderAmount_*/
            amount_,
            backersManager.periodFinish(),
            backersManager.timeUntilNextCycle(block.timestamp),
            false /*resetRewardMissing_*/
        );

        SafeERC20.safeTransferFrom(IERC20(rewardToken_), msg.sender, address(this), amount_);
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
