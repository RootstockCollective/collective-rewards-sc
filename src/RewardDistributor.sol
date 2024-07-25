// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin-contracts-5.0.2/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin-contracts-5.0.2/token/ERC20/utils/SafeERC20.sol";
import { SponsorsManager } from "./SponsorsManager.sol";
import { EpochLib } from "./libraries/EpochLib.sol";

/**
 * @title RewardDistributor
 * @notice Accumulates all the rewards to be distributed for each epoch
 */
contract RewardDistributor {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotFoundationTreasury();

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyFoundationTreasury() {
        if (msg.sender != foundationTreasury) revert NotFoundationTreasury();
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice foundation treasury address
    address public immutable foundationTreasury;
    /// @notice address of the token rewarded to builder and sponsors
    IERC20 public immutable rewardToken;
    /// @notice SponsorsManager contract address
    SponsorsManager public immutable sponsorsManager;
    /// @notice tracks amount of reward tokens distributed per epoch
    mapping(uint256 epochTimestampStart => uint256 amount) public rewardTokenAmountPerEpoch;

    /**
     * @notice constructor
     * @param foundationTreasury_ foundation treasury address
     * @param rewardToken_ address of the token rewarded to builder and sponsors
     * @param sponsorsManager_ SponsorsManager contract address
     */
    constructor(address foundationTreasury_, address rewardToken_, address sponsorsManager_) {
        foundationTreasury = foundationTreasury_;
        rewardToken = IERC20(rewardToken_);
        sponsorsManager = SponsorsManager(sponsorsManager_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice sends reward tokens to sponsorsManager contract to be distributed to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if reward token balance is insufficient
     */
    function sendRewardToken(uint256 amount_) external onlyFoundationTreasury {
        _sendRewardToken(amount_);
    }

    /**
     * @notice sends reward tokens to sponsorsManager contract and starts the distribution to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if reward token balance is insufficient
     *  reverts if is not in the distribution window
     */
    function sendRewardTokenAndStartDistribution(uint256 amount_) external onlyFoundationTreasury {
        _sendRewardToken(amount_);
        sponsorsManager.startDistribution();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function to send reward tokens to sponsorsManager contract
     */
    function _sendRewardToken(uint256 amount_) internal {
        // TODO: review if we need this
        rewardTokenAmountPerEpoch[EpochLib.epochStart(block.timestamp)] += amount_;
        rewardToken.approve(address(sponsorsManager), amount_);
        sponsorsManager.notifyRewardAmount(amount_);
    }
}
