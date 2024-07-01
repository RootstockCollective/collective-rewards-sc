// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { EpochLib } from "../libraries/EpochLib.sol";

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
    error ZeroRewardRate();
    error RewardRateTooHigh();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event SponsorRewardsClaimed(address indexed sponsor_, uint256 amount_);
    event Allocated(address indexed from, address indexed sponsor_, uint256 allocation_);
    event Deallocated(address indexed sponsor_, uint256 allocation_);
    event NotifyReward(uint256 amount_);

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
    // @notice address of the SponsorsManager contract
    address public immutable sponsorsManager;
    /// @notice total amount of stakingToken allocated for rewards
    uint256 public totalAllocation;
    /// @notice current reward rate of rewardToken to distribute per second
    uint256 public rewardRate;
    /// @notice most recent stored value of rewardPerToken
    uint256 public rewardPerTokenStored;
    /// @notice most recent timestamp contract has updated state
    uint256 public lastUpdateTime;
    // @notice timestamp end of current rewards period
    uint256 public periodFinish;

    /// @notice amount of stakingToken allocated by a sponsor
    mapping(address sponsor => uint256 allocation) public allocationOf;
    /// @notice cached rewardPerTokenStored for a sponsor based on their most recent action
    mapping(address sponsor => uint256 rewardPerTokenPaid) public sponsorRewardPerTokenPaid;
    /// @notice cached amount of rewardToken earned for a sponsor
    mapping(address sponsor => uint256 rewards) public rewards;
    /// @notice view to see rewardRate given the timestamp of the start of the epoch
    mapping(uint256 epoch => uint256 rewardRate) public rewardRateByEpoch;
    /// @notice view to see the totalAllocation given the timestamp of the start of the epoch
    mapping(uint256 epoch => uint256 totalSupply) public totalAllocationByEpoch;

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
     * @notice gets rewards for an `sponsor_` address
     * @dev reverts if is not called by the `sponsor_` or the sponsorsManager
     * @param sponsor_ address who receives the rewards
     */
    function getSponsorReward(address sponsor_) external onlySponsorsManager {
        if (msg.sender != sponsor_) revert NotAuthorized();

        _updateRewards(sponsor_);

        uint256 reward = rewards[sponsor_];
        if (reward > 0) {
            rewards[sponsor_] = 0;
            SafeERC20.safeTransfer(rewardToken, sponsor_, reward);
            emit SponsorRewardsClaimed(sponsor_, reward);
        }
    }

    /**
     * @notice gets `sponsor_` rewards missing to claim
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
     */
    function allocate(address sponsor_, uint256 allocation_) external onlySponsorsManager {
        // TODO: 0 values check are needed?
        _updateRewards(sponsor_);

        allocationOf[sponsor_] += allocation_;
        totalAllocation += allocation_;
        totalAllocationByEpoch[EpochLib.epochStart(block.timestamp)] = totalAllocation;

        SafeERC20.safeTransferFrom(rewardToken, msg.sender, address(this), allocation_);

        emit Allocated(msg.sender, sponsor_, allocation_);
    }

    /**
     * @notice deallocates stakingTokens
     * @dev reverts if caller si not the sponsorsManager contract
     * @param sponsor_ address of user who deallocates tokens
     * @param allocation_ amount of tokens to deallocate
     */
    function deallocate(address sponsor_, uint256 allocation_) external onlySponsorsManager {
        // TODO: cannot be called by the sponsor?
        // TODO: 0 values check are needed?
        _updateRewards(sponsor_);

        allocationOf[sponsor_] -= allocation_;
        totalAllocation -= allocation_;
        totalAllocationByEpoch[EpochLib.epochStart(block.timestamp)] = totalAllocation;

        SafeERC20.safeTransfer(rewardToken, sponsor_, allocation_);

        emit Deallocated(sponsor_, allocation_);
    }

    /**
     * @notice called on the reward distribution. Transfers reward tokens from sponsorManger to this contract
     * @dev reverts if caller si not the sponsorsManager contract
     * @param amount_ amount of reward tokens to distribute
     */
    function notifyRewardAmount(uint256 amount_) external onlySponsorsManager {
        // TODO: 0 amount_ check is needed?

        // update rewardPerToken storage
        rewardPerTokenStored = rewardPerToken();
        uint256 _timeUntilNext = EpochLib.epochNext(block.timestamp) - block.timestamp;
        uint256 _leftover = 0;
        // cache storage variables used multiple times
        uint256 _periodFinish = periodFinish;
        uint256 _rewardRate = rewardRate;

        // if period finished there is not remaining reward
        if (block.timestamp < _periodFinish) {
            // [PREC] = [N] * [PREC]
            _leftover = _periodFinish - block.timestamp * _rewardRate;
        }

        // [PREC] = [N] * [PREC] + [PREC]
        _rewardRate = UtilsLib._divPrec(amount_, _timeUntilNext) + _leftover;

        rewardRateByEpoch[EpochLib.epochStart(block.timestamp)] = _rewardRate;
        if (_rewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        // [PREC] = [N] * [PREC] / [N]
        uint256 _balanceRate = UtilsLib._divPrec(rewardToken.balanceOf(address(this)), _timeUntilNext);
        if (rewardRate > _balanceRate) revert RewardRateTooHigh();

        lastUpdateTime = block.timestamp;
        _periodFinish = block.timestamp + _timeUntilNext;

        // update cached variables on storage
        periodFinish = _periodFinish;
        rewardRate = _rewardRate;

        SafeERC20.safeTransferFrom(rewardToken, msg.sender, address(this), amount_);
        emit NotifyReward(amount_);
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
