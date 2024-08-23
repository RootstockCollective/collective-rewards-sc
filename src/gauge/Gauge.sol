// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { EpochLib } from "../libraries/EpochLib.sol";
import { BuilderRegistry } from "../BuilderRegistry.sol";

/**
 * @title Gauge
 * @notice For each project proposal a Gauge contract will be deployed.
 *  It receives all the rewards obtained for that project and allows the builder and voters to claim them.
 */
contract Gauge {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotAuthorized();
    error NotSponsorsManager();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event SponsorRewardsClaimed(address indexed sponsor_, uint256 amount_);
    event BuilderRewardsClaimed(address indexed builder_, uint256 amount_);
    event NewAllocation(address indexed sponsor_, uint256 allocation_);
    event NotifyReward(uint256 builderAmount_, uint256 sponsorsAmount_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlySponsorsManager() {
        if (msg.sender != sponsorsManager) revert NotSponsorsManager();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token rewarded to builder and voters
    IERC20 public immutable rewardToken;
    /// @notice SponsorsManager contract address
    address public immutable sponsorsManager;
    /// @notice total amount of stakingToken allocated for rewards
    uint256 public totalAllocation;
    /// @notice current reward rate of rewardToken to distribute per second [PREC]
    uint256 public rewardRate;
    /// @notice most recent stored value of rewardPerToken [PREC]
    uint256 public rewardPerTokenStored;
    /// @notice missing rewards where there is not allocation [PREC]
    uint256 public rewardMissing;
    /// @notice most recent timestamp contract has updated state
    uint256 public lastUpdateTime;
    /// @notice timestamp end of current rewards period
    uint256 public periodFinish;
    /// @notice amount of unclaimed token reward earned for the builder
    uint256 public builderRewards;
    /// @notice epoch rewards shares, optimistically tracking the time weighted votes allocations for this gauge
    uint256 public rewardShares;

    /// @notice amount of stakingToken allocated by a sponsor
    mapping(address sponsor => uint256 allocation) public allocationOf;
    /// @notice cached rewardPerTokenStored for a sponsor based on their most recent action [PREC]
    mapping(address sponsor => uint256 rewardPerTokenPaid) public sponsorRewardPerTokenPaid;
    /// @notice cached amount of rewardToken earned for a sponsor
    mapping(address sponsor => uint256 rewards) public rewards;

    /**
     * @notice constructor
     * @param rewardToken_ address of the token rewarded to builder and voters
     * @param sponsorsManager_ address of the SponsorsManager contract
     */
    constructor(address rewardToken_, address sponsorsManager_) {
        rewardToken = IERC20(rewardToken_);
        sponsorsManager = sponsorsManager_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice gets the current reward rate per unit of stakingToken allocated
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalAllocation == 0) {
            // [PREC]
            return rewardPerTokenStored;
        }
        // [PREC] = (([N] - [N]) * [PREC]) / [N]
        // TODO: could be lastUpdateTime > lastTimeRewardApplicable()??
        uint256 _rewardPerTokenCurrent = ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate) / totalAllocation;
        // [PREC] = [PREC] + [PREC]
        return rewardPerTokenStored + _rewardPerTokenCurrent;
    }

    /**
     * @notice gets the last time the reward is applicable, now or when the epoch finished
     * @return lastTimeRewardApplicable minimum between current timestamp or periodFinish
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /**
     * @notice gets total amount of rewards to distribute for the current rewards period
     */
    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        // [N] = ([N] - [N]) * [PREC] / [PREC]
        return UtilsLib._mulPrec(periodFinish - block.timestamp, rewardRate);
    }

    /**
     * @notice claim rewards for a `sponsor_` address
     * @dev reverts if is not called by the `sponsor_` or the sponsorsManager
     * @param sponsor_ address who receives the rewards
     */
    function claimSponsorReward(address sponsor_) external {
        if (msg.sender != sponsor_ && msg.sender != sponsorsManager) revert NotAuthorized();

        _updateRewards(sponsor_);

        uint256 _reward = rewards[sponsor_];
        if (_reward > 0) {
            rewards[sponsor_] = 0;
            SafeERC20.safeTransfer(rewardToken, sponsor_, _reward);
            emit SponsorRewardsClaimed(sponsor_, _reward);
        }
    }

    /**
     * @notice claim rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
     * @dev rewards are transferred to the builder reward receiver
     */
    function claimBuilderReward() external {
        address _builder = BuilderRegistry(sponsorsManager).gaugeToBuilder(Gauge(address(this)));
        address _rewardReceiver = BuilderRegistry(sponsorsManager).builderRewardReceiver(_builder);
        if (msg.sender != _builder && msg.sender != _rewardReceiver) revert NotAuthorized();

        uint256 _reward = builderRewards;
        if (_reward > 0) {
            builderRewards = 0;
            SafeERC20.safeTransfer(rewardToken, _rewardReceiver, _reward);
            emit BuilderRewardsClaimed(_rewardReceiver, builderRewards);
        }
    }

    /**
     * @notice gets `sponsor_` rewards missing to claim
     * @param sponsor_ address who earned the rewards
     */
    function earned(address sponsor_) public view returns (uint256) {
        // [N] = ([N] * ([PREC] - [PREC]) / [PREC])
        uint256 _currentReward =
            UtilsLib._mulPrec(allocationOf[sponsor_], rewardPerToken() - sponsorRewardPerTokenPaid[sponsor_]);
        // [N] = [N] + [N]
        return rewards[sponsor_] + _currentReward;
    }

    /**
     * @notice allocates stakingTokens
     * @dev reverts if caller si not the sponsorsManager contract
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
            // [PREC] = [PREC] + ([N] - [N]) * [PREC]
            rewardMissing += ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate);
        }

        _updateRewards(sponsor_);

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
     * @notice called on the reward distribution. Transfers reward tokens from sponsorManger to this contract
     * @dev reverts if caller si not the sponsorsManager contract
     * @param builderAmount_ amount of rewards for the builder
     * @param sponsorsAmount_ amount of rewards for the sponsors
     * @return newGaugeRewardShares_ new gauge rewardShares, updated after the distribution
     */
    function notifyRewardAmount(
        uint256 builderAmount_,
        uint256 sponsorsAmount_
    )
        external
        onlySponsorsManager
        returns (uint256 newGaugeRewardShares_)
    {
        // update rewardPerToken storage
        rewardPerTokenStored = rewardPerToken();
        uint256 _timeUntilNext = EpochLib._epochNext(block.timestamp) - block.timestamp;
        uint256 _leftover = 0;
        // cache storage variables used multiple times
        uint256 _periodFinish = periodFinish;
        uint256 _rewardRate = rewardRate;

        // if period finished there is not remaining reward
        if (block.timestamp < _periodFinish) {
            // [PREC] = [N] * [PREC]
            _leftover = (_periodFinish - block.timestamp) * _rewardRate;
        }

        // [PREC] = ([N] * [PREC] + [PREC] + [PREC]) / [N]
        _rewardRate = (sponsorsAmount_ * UtilsLib._PRECISION + rewardMissing + _leftover) / _timeUntilNext;

        builderRewards += builderAmount_;

        lastUpdateTime = block.timestamp;
        _periodFinish = block.timestamp + _timeUntilNext;
        rewardMissing = 0;
        newGaugeRewardShares_ = totalAllocation * EpochLib._WEEK;

        // update cached variables on storage
        periodFinish = _periodFinish;
        rewardRate = _rewardRate;
        rewardShares = newGaugeRewardShares_;

        SafeERC20.safeTransferFrom(rewardToken, msg.sender, address(this), builderAmount_ + sponsorsAmount_);

        emit NotifyReward(builderAmount_, sponsorsAmount_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    function _updateRewards(address sponsor_) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[sponsor_] = earned(sponsor_);
        sponsorRewardPerTokenPaid[sponsor_] = rewardPerTokenStored;
    }
}
