// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IGauge } from "../interfaces/gauges/IGauge.sol";
import { IVoter } from "../interfaces/IVoter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { TimeLibrary } from "../libraries/TimeLibrary.sol";

/// @title Velodrome V2 Gauge
/// @author veldorome.finance, @franciscotobar, @antomor
/// @notice Gauge contract for distribution of emissions by address
contract Gauge is IGauge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc IGauge
    address public immutable rewardToken;
    /// @inheritdoc IGauge
    address public immutable voter;

    uint256 internal constant DURATION = 7 days; // rewards are released over 7 days
    uint256 internal constant PRECISION = 10 ** 18;

    /// @inheritdoc IGauge
    uint256 public periodFinish;
    /// @inheritdoc IGauge
    uint256 public rewardRate;
    /// @inheritdoc IGauge
    uint256 public lastUpdateTime;
    /// @inheritdoc IGauge
    uint256 public rewardPerTokenStored;
    /// @inheritdoc IGauge
    uint256 public totalSupply;
    /// @inheritdoc IGauge
    mapping(address => uint256) public balanceOf;
    /// @inheritdoc IGauge
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @inheritdoc IGauge
    mapping(address => uint256) public rewards;
    /// @inheritdoc IGauge
    mapping(uint256 => uint256) public rewardRateByEpoch;

    /// @inheritdoc IGauge
    mapping(uint256 => uint256) public totalSupplyByEpoch;

    constructor(address _rewardToken, address _voter) {
        rewardToken = _rewardToken;
        //TODO check if its necessary for this approoach.
        voter = _voter;
    }

    /// @inheritdoc IGauge
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) / totalSupply;
    }

    /// @inheritdoc IGauge
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /// @inheritdoc IGauge
    function getReward(address _account) external nonReentrant {
        address sender = msg.sender;
        if (sender != _account && sender != voter) revert NotAuthorized();

        _updateRewards(_account);

        uint256 reward = rewards[_account];
        if (reward > 0) {
            rewards[_account] = 0;
            IERC20(rewardToken).safeTransfer(_account, reward);
            emit ClaimRewards(_account, reward);
        }
    }

    /// @inheritdoc IGauge
    function earned(address _account) public view returns (uint256) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / PRECISION
            + rewards[_account];
    }

    /// @inheritdoc IGauge
    function deposit(uint256 _amount, address _recipient) external {
        address _sender = msg.sender;
        if (_sender != voter) revert NotVoter();
        _depositFor(_amount, _recipient);
    }

    function _depositFor(uint256 _amount, address _recipient) internal nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (!IVoter(voter).isAlive(address(this))) revert NotAlive();

        address sender = msg.sender;
        _updateRewards(_recipient);

        balanceOf[_recipient] += _amount;

        totalSupply += _amount;
        uint256 timestamp = block.timestamp;
        totalSupplyByEpoch[TimeLibrary.epochStart(timestamp)] = totalSupply;

        emit Deposit(sender, _recipient, _amount);
    }

    /// @inheritdoc IGauge
    function withdraw(uint256 _amount, address _recipient) external {
        address _sender = msg.sender;
        if (_sender != voter) revert NotVoter();
        _withdrawFor(_amount, _recipient);
    }

    function _withdrawFor(uint256 _amount, address _recipient) internal nonReentrant {
        _updateRewards(_recipient);

        totalSupply -= _amount;
        uint256 timestamp = block.timestamp;
        totalSupplyByEpoch[TimeLibrary.epochStart(timestamp)] = totalSupply;

        balanceOf[_recipient] -= _amount;

        emit Withdraw(_recipient, _amount);
    }

    function _updateRewards(address _account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    /// @inheritdoc IGauge
    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    /// @inheritdoc IGauge
    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        address sender = msg.sender;
        if (sender != voter) revert NotVoter();
        if (_amount == 0) revert ZeroAmount();
        _notifyRewardAmount(sender, _amount);
    }

    function _notifyRewardAmount(address sender, uint256 _amount) internal {
        rewardPerTokenStored = rewardPerToken();
        uint256 timestamp = block.timestamp;
        uint256 timeUntilNext = TimeLibrary.epochNext(timestamp) - timestamp;

        IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
        if (timestamp >= periodFinish) {
            rewardRate = _amount / timeUntilNext;
        } else {
            uint256 _remaining = periodFinish - timestamp;
            uint256 _leftover = _remaining * rewardRate;
            rewardRate = (_amount + _leftover) / timeUntilNext;
        }
        rewardRateByEpoch[TimeLibrary.epochStart(timestamp)] = rewardRate;
        if (rewardRate == 0) revert ZeroRewardRate();

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > balance / timeUntilNext) revert RewardRateTooHigh();

        lastUpdateTime = timestamp;
        periodFinish = timestamp + timeUntilNext;
        emit NotifyReward(sender, _amount);
    }
}
