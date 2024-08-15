// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SponsorsManager } from "../SponsorsManager.sol";
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
    error InvalidRewardAmount();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event SponsorRewardsClaimed(address indexed sponsor_, uint256 amount_);
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
    // ---------- Storage ----------
    // -----------------------------

    /// @notice builder address
    address public immutable builder;
    /// @notice address of the token rewarded to builder and voters
    address public immutable rewardToken;
    /// @notice SponsorsManager contract address
    SponsorsManager public immutable sponsorsManager;
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
    mapping(address rewardToken => uint256 builderRewards) public builderRewards;
    /// @notice historical rewards accumulated.Used to calculate the normalization factors
    ///  address(uint160(uint256(keccak256("COINBASE_ADDRESS")))) is used for coinbase
    mapping(address rewardToken => uint256 historicalRewards) public historicalRewards;

    /// @notice amount of stakingToken allocated by a sponsor
    mapping(address sponsor => uint256 allocation) public allocationOf;
    /// @notice cached rewardPerTokenStored for a sponsor based on their most recent action [PREC]
    mapping(address sponsor => uint256 rewardPerTokenPaid) public sponsorRewardPerTokenPaid;
    /// @notice cached amount of rewardToken earned for a sponsor
    mapping(address sponsor => uint256 rewards) public rewards;

    /**
     * @notice constructor
     * @param builder_ address of the builder
     * @param rewardToken_ address of the token rewarded to builder and voters
     * @param sponsorsManager_ address of the SponsorsManager contract
     */
    constructor(address builder_, address rewardToken_, address sponsorsManager_) {
        builder = builder_;
        rewardToken = rewardToken_;
        sponsorsManager = SponsorsManager(sponsorsManager_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice gets the last time the reward is applicable, now or when the epoch finished
     * @return lastTimeRewardApplicable minimum between current timestamp or periodFinish
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /**
     * @notice gets the current ERC20 reward rate per unit of stakingToken allocated
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function rewardPerTokenERC20() external view returns (uint256) {
        return _rewardPerToken(rewardToken);
    }

    /**
     * @notice gets the current Coinbase reward rate per unit of stakingToken allocated
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function rewardPerTokenCoinbase() external view returns (uint256) {
        return _rewardPerToken(UtilsLib._COINBASE_ADDRESS);
    }

    /**
     * @notice gets total amount of ERC20 rewards to distribute for the current rewards period
     */
    function leftERC20() external view returns (uint256) {
        return _left(rewardToken);
    }

    /**
     * @notice gets total amount of Coinbase rewards to distribute for the current rewards period
     */
    function leftCoinbase() external view returns (uint256) {
        return _left(UtilsLib._COINBASE_ADDRESS);
    }

    /**
     * @notice gets `sponsor_` ERC20 rewards missing to claim
     * @param sponsor_ address who earned the rewards
     */
    function earnedERC20(address sponsor_) public view returns (uint256) {
        return _earned(rewardToken, sponsor_);
    }

    /**
     * @notice gets `sponsor_` Coinbase rewards missing to claim
     * @param sponsor_ address who earned the rewards
     */
    function earnedCoinbase(address sponsor_) public view returns (uint256) {
        return _earned(UtilsLib._COINBASE_ADDRESS, sponsor_);
    }

    /**
     * @notice claim ERC20 rewards for a `sponsor_` address
     * @dev reverts if is not called by the `sponsor_` or the sponsorsManager
     * @param sponsor_ address who receives the rewards
     */
    function claimSponsorRewardERC20(address sponsor_) external {
        if (msg.sender != sponsor_ && msg.sender != address(sponsorsManager)) revert NotAuthorized();
        _updateRewards(sponsor_);

        uint256 _reward = rewards[sponsor_];
        if (_reward > 0) {
            uint256 _nf = _calcNF(UtilsLib._COINBASE_ADDRESS);
            rewards[sponsor_] = 0;
            Address.sendValue(payable(sponsor_), UtilsLib._mulPrec(_reward, _nf));
            SafeERC20.safeTransfer(IERC20(rewardToken), sponsor_, _reward);
            emit SponsorRewardsClaimed(sponsor_, _reward);
        }
    }

    /**
     * @notice claim ERC20 rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
     * @dev rewards are transferred to the builder reward receiver
     */
    function claimBuilderRewardERC20(address builder_) external {
        _claimBuilderReward(rewardToken, builder_);
    }

    /**
     * @notice claim Coinbase rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
     * @dev rewards are transferred to the builder reward receiver
     */
    function claimBuilderRewardCoinbase(address builder_) external {
        _claimBuilderReward(UtilsLib._COINBASE_ADDRESS, builder_);
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
        if (allocation_ >= _previousAllocation) {
            allocationDeviation_ = allocation_ - _previousAllocation;
            totalAllocation += allocationDeviation_;
        } else {
            allocationDeviation_ = _previousAllocation - allocation_;
            totalAllocation -= allocationDeviation_;
            isNegative_ = true;
        }
        allocationOf[sponsor_] = allocation_;

        emit NewAllocation(sponsor_, allocation_);
        return (allocationDeviation_, isNegative_);
    }

    /**
     * @notice called on the ERC20 reward distribution. Transfers ERC20 reward tokens from sponsorManger to this
     * contract
     * @dev reverts if caller si not the sponsorsManager contract
     * @param builderAmount_ amount of rewards for the builder
     * @param sponsorsAmount_ amount of rewards for the sponsors
     */
    function notifyRewardAmountERC20(uint256 builderAmount_, uint256 sponsorsAmount_) external {
        _notifyRewardAmount(rewardToken, builderAmount_, sponsorsAmount_);
        SafeERC20.safeTransferFrom(IERC20(rewardToken), msg.sender, address(this), builderAmount_ + sponsorsAmount_);
    }

    /**
     * @notice called on the Coinbase reward distribution. Transfers ERC20 reward tokens from sponsorManger to this
     * contract
     * @dev reverts if caller si not the sponsorsManager contract
     * @param builderAmount_ amount of rewards for the builder
     * @param sponsorsAmount_ amount of rewards for the sponsors
     */
    function notifyRewardAmountCoinbase(uint256 builderAmount_, uint256 sponsorsAmount_) external payable {
        if (builderAmount_ + sponsorsAmount_ != msg.value) revert InvalidRewardAmount();
        builderRewards[UtilsLib._COINBASE_ADDRESS] += builderAmount_;
        historicalRewards[UtilsLib._COINBASE_ADDRESS] += sponsorsAmount_;
        emit NotifyReward(UtilsLib._COINBASE_ADDRESS, builderAmount_, sponsorsAmount_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice gets the current reward rate per unit of stakingToken allocated
     * @return rewardPerToken rewardToken:stakingToken ratio [PREC]
     */
    function _rewardPerToken(address rewardToken_) internal view returns (uint256) {
        uint256 _nf = _calcNF(rewardToken_);
        if (totalAllocation == 0) {
            // [PREC] = [PREC] * [PREC] / [PREC]
            return UtilsLib._mulPrec(rewardPerTokenStored, _nf);
        }
        // [PREC] = (([N] - [N]) * [PREC]) / [N]
        // TODO: could be lastUpdateTime > lastTimeRewardApplicable()??
        uint256 _rewardPerTokenCurrent =
            ((lastTimeRewardApplicable() - lastUpdateTime) * UtilsLib._mulPrec(rewardRate, _nf)) / totalAllocation;
        // [PREC] = [PREC] + [PREC]
        return UtilsLib._mulPrec(rewardPerTokenStored, _nf) + _rewardPerTokenCurrent;
    }

    /**
     * @notice gets total amount of rewards to distribute for the current rewards period
     */
    function _left(address rewardToken_) internal view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _nf = _calcNF(rewardToken_);
        // [N] = ([N] - [N]) * [PREC] / [PREC]
        return UtilsLib._mulPrec(periodFinish - block.timestamp, UtilsLib._mulPrec(rewardRate, _nf));
    }

    /**
     * @notice gets `sponsor_` rewards missing to claim
     * @param sponsor_ address who earned the rewards
     */
    function _earned(address rewardToken_, address sponsor_) internal view returns (uint256) {
        uint256 _nf = _calcNF(rewardToken_);
        // [N] = ([N] * ([PREC] - [PREC]) / [PREC])
        uint256 _currentReward = UtilsLib._mulPrec(
            allocationOf[sponsor_],
            _rewardPerToken(rewardToken_) - UtilsLib._mulPrec(sponsorRewardPerTokenPaid[sponsor_], _nf)
        );
        // [N] = [N] + [N]
        return UtilsLib._mulPrec(rewards[sponsor_], _nf) + _currentReward;
    }

    /**
     * @notice claim rewards for a builder
     * @dev reverts if is not called by the builder or reward receiver
     * @dev rewards are transferred to the builder reward receiver
     */
    function _claimBuilderReward(address rewardToken_, address builder_) internal {
        address _rewardReceiver = sponsorsManager.builderRegistry().getRewardReceiver(builder_);
        if (msg.sender != builder_ && msg.sender != _rewardReceiver) revert NotAuthorized();

        uint256 _reward = builderRewards[rewardToken_];
        if (_reward > 0) {
            builderRewards[rewardToken_] = 0;
            _transferRewardToken(rewardToken_, _rewardReceiver, _reward);
            emit BuilderRewardsClaimed(rewardToken_, _rewardReceiver, _reward);
        }
    }

    /**
     * @notice called on the reward distribution. Transfers reward tokens from sponsorManger to this contract
     * @dev reverts if caller si not the sponsorsManager contract
     * @param builderAmount_ amount of rewards for the builder
     * @param sponsorsAmount_ amount of rewards for the sponsors
     */
    function _notifyRewardAmount(
        address rewardToken_,
        uint256 builderAmount_,
        uint256 sponsorsAmount_
    )
        internal
        onlySponsorsManager
    {
        // update rewardPerToken storage
        rewardPerTokenStored = _rewardPerToken(rewardToken_);
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

        builderRewards[rewardToken_] += builderAmount_;

        lastUpdateTime = block.timestamp;
        _periodFinish = block.timestamp + _timeUntilNext;
        rewardMissing = 0;
        historicalRewards[rewardToken_] += sponsorsAmount_;

        // update cached variables on storage
        periodFinish = _periodFinish;
        rewardRate = _rewardRate;

        emit NotifyReward(rewardToken_, builderAmount_, sponsorsAmount_);
    }

    function _updateRewards(address sponsor_) internal {
        rewardPerTokenStored = _rewardPerToken(rewardToken);
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[sponsor_] = _earned(rewardToken, sponsor_);
        sponsorRewardPerTokenPaid[sponsor_] = rewardPerTokenStored;
    }

    function _transferRewardToken(address rewardToken_, address to_, uint256 amount_) internal {
        if (rewardToken_ == UtilsLib._COINBASE_ADDRESS) {
            Address.sendValue(payable(to_), amount_);
        } else {
            SafeERC20.safeTransfer(IERC20(rewardToken_), to_, amount_);
        }
    }

    function _calcNF(address target_) internal view returns (uint256 nf_) {
        if (target_ == rewardToken) return UtilsLib._PRECISION;
        // TODO: if == 0 revert?
        if (historicalRewards[rewardToken] > 0) {
            return UtilsLib._divPrec(historicalRewards[target_], historicalRewards[rewardToken]);
        }
        return 0;
    }
}
