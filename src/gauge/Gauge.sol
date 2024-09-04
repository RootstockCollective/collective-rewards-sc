// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { EpochLib } from "../libraries/EpochLib.sol";
import { ISponsorsManager } from "../interfaces/ISponsorsManager.sol";

/**
 * @title Gauge
 * @notice For each project proposal a Gauge contract will be deployed.
 *  It receives all the rewards obtained for that project and allows the builder and voters to claim them.
 */
contract Gauge is ReentrancyGuardUpgradeable {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotAuthorized();
    error NotSponsorsManager();
    error InvalidRewardAmount();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event SponsorRewardsClaimed(address indexed rewardToken_, address indexed sponsor_, uint256 amount_);
    event BuilderRewardsClaimed(address indexed rewardToken_, address indexed builder_, uint256 amount_);
    event NewAllocation(address indexed sponsor_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, uint256 builderAmount_, uint256 sponsorsAmount_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlySponsorsManager() {
        if (msg.sender != address(sponsorsManager)) revert NotSponsorsManager();
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
        /// @notice cached rewardPerTokenStored for a sponsor based on their most recent action [PREC]
        mapping(address sponsor => uint256 rewardPerTokenPaid) sponsorRewardPerTokenPaid;
        /// @notice cached amount of rewardToken earned for a sponsor
        mapping(address sponsor => uint256 rewards) rewards;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token rewarded to builder and voters
    address public rewardToken;
    /// @notice SponsorsManager contract address
    ISponsorsManager public sponsorsManager;
    /// @notice total amount of stakingToken allocated for rewards
    uint256 public totalAllocation;
    /// @notice epoch rewards shares, optimistically tracking the time weighted votes allocations for this gauge
    uint256 public rewardShares;
    /// @notice amount of stakingToken allocated by a sponsor
    mapping(address sponsor => uint256 allocation) public allocationOf;
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
     * @param sponsorsManager_ address of the SponsorsManager contract
     */
    function initialize(address rewardToken_, address sponsorsManager_) external initializer {
        __ReentrancyGuard_init();
        rewardToken = rewardToken_;
        sponsorsManager = ISponsorsManager(sponsorsManager_);
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
     * @notice gets sponsor reward per token paid
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function sponsorRewardPerTokenPaid(address rewardToken_, address sponsor_) public view returns (uint256) {
        return rewardData[rewardToken_].sponsorRewardPerTokenPaid[sponsor_];
    }

    /**
     * @notice gets amount of rewardToken earned for a sponsor
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param sponsor_ address of the sponsor
     */
    function rewards(address rewardToken_, address sponsor_) public view returns (uint256) {
        return rewardData[rewardToken_].rewards[sponsor_];
    }

    /**
     * @notice gets the last time the reward is applicable, now or when the epoch finished
     * @return lastTimeRewardApplicable minimum between current timestamp or periodFinish
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, sponsorsManager.periodFinish());
    }

    /**
     * @notice gets the current reward rate per unit of stakingToken allocated
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function rewardPerToken(address rewardToken_) public view returns (uint256) {
        RewardData storage _rewardData = rewardData[rewardToken_];

        if (totalAllocation == 0) {
            // [PREC]
            return _rewardData.rewardPerTokenStored;
        }
        // [PREC] = (([N] - [N]) * [PREC]) / [N]
        // TODO: could be lastUpdateTime > lastTimeRewardApplicable()??
        uint256 _rewardPerTokenCurrent =
            ((lastTimeRewardApplicable() - _rewardData.lastUpdateTime) * _rewardData.rewardRate) / totalAllocation;
        // [PREC] = [PREC] + [PREC]
        return _rewardData.rewardPerTokenStored + _rewardPerTokenCurrent;
    }

    /**
     * @notice gets total amount of rewards to distribute for the current rewards period
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function left(address rewardToken_) external view returns (uint256) {
        RewardData storage _rewardData = rewardData[rewardToken_];
        uint256 _periodFinish = sponsorsManager.periodFinish();
        if (block.timestamp >= _periodFinish) return 0;
        // [N] = ([N] - [N]) * [PREC] / [PREC]
        return UtilsLib._mulPrec(_periodFinish - block.timestamp, _rewardData.rewardRate);
    }

    /**
     * @notice gets `sponsor_` rewards missing to claim
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param sponsor_ address who earned the rewards
     */
    function earned(address rewardToken_, address sponsor_) public view returns (uint256) {
        RewardData storage _rewardData = rewardData[rewardToken_];

        // [N] = ([N] * ([PREC] - [PREC]) / [PREC])
        uint256 _currentReward = UtilsLib._mulPrec(
            allocationOf[sponsor_], rewardPerToken(rewardToken_) - _rewardData.sponsorRewardPerTokenPaid[sponsor_]
        );
        // [N] = [N] + [N]
        return _rewardData.rewards[sponsor_] + _currentReward;
    }

    /**
     * @notice claim rewards for a `sponsor_` address
     * @dev reverts if is not called by the `sponsor_` or the sponsorsManager
     * @param sponsor_ address who receives the rewards
     */
    function claimSponsorReward(address sponsor_) public {
        claimSponsorReward(rewardToken, sponsor_);
        claimSponsorReward(UtilsLib._COINBASE_ADDRESS, sponsor_);
    }

    /**
     * @notice claim rewards for a `sponsor_` address
     * @dev reverts if is not called by the `sponsor_` or the sponsorsManager
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param sponsor_ address who receives the rewards
     */
    function claimSponsorReward(address rewardToken_, address sponsor_) public {
        if (msg.sender != sponsor_ && msg.sender != address(sponsorsManager)) revert NotAuthorized();

        RewardData storage _rewardData = rewardData[rewardToken_];

        _updateRewards(rewardToken_, sponsor_);

        uint256 _reward = _rewardData.rewards[sponsor_];
        if (_reward > 0) {
            _rewardData.rewards[sponsor_] = 0;
            _transferRewardToken(rewardToken_, sponsor_, _reward);
            emit SponsorRewardsClaimed(rewardToken_, sponsor_, _reward);
        }
    }

    /**
     * @notice claim rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
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
        address _builder = sponsorsManager.gaugeToBuilder(address(this));
        address _rewardReceiver = sponsorsManager.builderRewardReceiver(_builder);
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
     * @notice allocates stakingTokens
     * @dev reverts if caller is not the sponsorsManager contract
     * @param sponsor_ address of user who allocates tokens
     * @param allocation_ amount of tokens to allocate
     * @return allocationDeviation_ deviation between current allocation and the new one
     * @return isNegative_ true if new allocation is lesser than the current one
     */
    function allocate(
        address sponsor_,
        uint256 allocation_
    )
        external
        onlySponsorsManager
        returns (uint256 allocationDeviation_, bool isNegative_)
    {
        // if sponsors quit before epoch finish we need to store the remaining rewards on first allocation
        // to add it on the next reward distribution
        if (totalAllocation == 0) {
            _upadateRewardMissing(rewardToken);
            _upadateRewardMissing(UtilsLib._COINBASE_ADDRESS);
        }

        _updateRewards(rewardToken, sponsor_);
        _updateRewards(UtilsLib._COINBASE_ADDRESS, sponsor_);

        // to do not deal with signed integers we add allocation if the new one is bigger than the previous one
        uint256 _previousAllocation = allocationOf[sponsor_];
        uint256 _timeUntilNext = EpochLib._epochNext(block.timestamp) - block.timestamp;
        if (allocation_ >= _previousAllocation) {
            allocationDeviation_ = allocation_ - _previousAllocation;
            totalAllocation += allocationDeviation_;
            rewardShares += allocationDeviation_ * _timeUntilNext;
        } else {
            allocationDeviation_ = _previousAllocation - allocation_;
            totalAllocation -= allocationDeviation_;
            rewardShares -= allocationDeviation_ * _timeUntilNext;
            isNegative_ = true;
        }
        allocationOf[sponsor_] = allocation_;

        emit NewAllocation(sponsor_, allocation_);
        return (allocationDeviation_, isNegative_);
    }

    /**
     * @notice transfers reward tokens to this contract
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param builderAmount_ amount of rewards for the builder
     * @param sponsorsAmount_ amount of rewards for the sponsors
     */
    function notifyRewardAmount(
        address rewardToken_,
        uint256 builderAmount_,
        uint256 sponsorsAmount_
    )
        external
        payable
    {
        _notifyRewardAmount(rewardToken_, builderAmount_, sponsorsAmount_);
        if (rewardToken_ == UtilsLib._COINBASE_ADDRESS) {
            if (builderAmount_ + sponsorsAmount_ != msg.value) revert InvalidRewardAmount();
        } else {
            SafeERC20.safeTransferFrom(
                IERC20(rewardToken_), msg.sender, address(this), builderAmount_ + sponsorsAmount_
            );
        }
    }

    /**
     * @notice called on the reward distribution. Transfers reward tokens from sponsorManger to this contract
     * @dev reverts if caller is not the sponsorsManager contract
     * @param amountERC20_ amount of ERC20 rewards
     * @param builderKickback_  builder kickback percetange
     * @return newGaugeRewardShares_ new gauge rewardShares, updated after the distribution
     */
    function notifyRewardAmountAndUpdateShares(
        uint256 amountERC20_,
        uint256 builderKickback_
    )
        external
        payable
        onlySponsorsManager
        returns (uint256 newGaugeRewardShares_)
    {
        uint256 _sponsorAmountERC20 = UtilsLib._mulPrec(builderKickback_, amountERC20_);
        uint256 _sponsorAmountCoinbase = UtilsLib._mulPrec(builderKickback_, msg.value);
        _notifyRewardAmount(rewardToken, amountERC20_ - _sponsorAmountERC20, _sponsorAmountERC20);
        _notifyRewardAmount(UtilsLib._COINBASE_ADDRESS, msg.value - _sponsorAmountCoinbase, _sponsorAmountCoinbase);

        newGaugeRewardShares_ = totalAllocation * EpochLib._WEEK;
        rewardShares = newGaugeRewardShares_;

        SafeERC20.safeTransferFrom(IERC20(rewardToken), msg.sender, address(this), amountERC20_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice transfers reward tokens to this contract
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param builderAmount_ amount of rewards for the builder
     * @param sponsorsAmount_ amount of rewards for the sponsors
     */
    function _notifyRewardAmount(address rewardToken_, uint256 builderAmount_, uint256 sponsorsAmount_) internal {
        RewardData storage _rewardData = rewardData[rewardToken_];
        // cache storage variables used multiple times
        uint256 _rewardRate = _rewardData.rewardRate;
        uint256 _timeUntilNext = EpochLib._epochNext(block.timestamp) - block.timestamp;
        uint256 _leftover = 0;

        // if period finished there is not remaining reward
        if (block.timestamp < sponsorsManager.periodFinish()) {
            // [PREC] = [N] * [PREC]
            _leftover = (_timeUntilNext) * _rewardRate;
        }

        // [PREC] = ([N] * [PREC] + [PREC] + [PREC]) / [N]
        _rewardRate = (sponsorsAmount_ * UtilsLib._PRECISION + _rewardData.rewardMissing + _leftover) / _timeUntilNext;

        _rewardData.builderRewards += builderAmount_;
        _rewardData.rewardPerTokenStored = rewardPerToken(rewardToken_);
        _rewardData.lastUpdateTime = block.timestamp;
        _rewardData.rewardMissing = 0;
        _rewardData.rewardRate = _rewardRate;

        emit NotifyReward(rewardToken_, builderAmount_, sponsorsAmount_);
    }

    /**
     * @notice update rewards variables when a sponsor interacts
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     * @param sponsor_ address of the sponsors
     */
    function _updateRewards(address rewardToken_, address sponsor_) internal {
        RewardData storage _rewardData = rewardData[rewardToken_];

        _rewardData.rewardPerTokenStored = rewardPerToken(rewardToken_);
        _rewardData.lastUpdateTime = lastTimeRewardApplicable();
        _rewardData.rewards[sponsor_] = earned(rewardToken_, sponsor_);
        _rewardData.sponsorRewardPerTokenPaid[sponsor_] = _rewardData.rewardPerTokenStored;
    }

    /**
     * @notice update reward missing variable
     * @param rewardToken_ address of the token rewarded
     *  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase address
     */
    function _upadateRewardMissing(address rewardToken_) internal {
        RewardData storage _rewardData = rewardData[rewardToken_];
        // [PREC] = [PREC] + ([N] - [N]) * [PREC]
        _rewardData.rewardMissing +=
            ((lastTimeRewardApplicable() - _rewardData.lastUpdateTime) * _rewardData.rewardRate);
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
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
