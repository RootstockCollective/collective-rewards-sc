// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Upgradeable } from "./governance/Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SponsorsManager } from "./SponsorsManager.sol";
import { EpochLib } from "./libraries/EpochLib.sol";

/**
 * @title RewardDistributor
 * @notice Accumulates all the rewards to be distributed for each epoch
 */
contract RewardDistributor is Upgradeable {
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
    address public foundationTreasury;
    /// @notice address of the token rewarded to builder and sponsors
    IERC20 public rewardToken;
    /// @notice SponsorsManager contract address
    SponsorsManager public sponsorsManager;
    /// @notice tracks amount of reward tokens distributed per epoch
    mapping(uint256 epochTimestampStart => uint256 amount) public rewardTokenAmountPerEpoch;
    /// @notice tracks amount of coinbase distributed per epoch
    mapping(uint256 epochTimestampStart => uint256 amount) public rewardCoinbaseAmountPerEpoch;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param changeExecutor_ See Governed doc
     * @param foundationTreasury_ foundation treasury address
     * @param sponsorsManager_ SponsorsManager contract address
     */
    function initialize(
        address changeExecutor_,
        address foundationTreasury_,
        address sponsorsManager_
    )
        external
        initializer
    {
        __Upgradeable_init(changeExecutor_);
        foundationTreasury = foundationTreasury_;
        sponsorsManager = SponsorsManager(sponsorsManager_);
        rewardToken = IERC20(SponsorsManager(sponsorsManager_).rewardToken());
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice sends reward tokens to sponsorsManager contract to be distributed to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if reward token balance is insufficient
     * @param amountERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function sendRewardToken(uint256 amountERC20_, uint256 amountCoinbase_) external payable onlyFoundationTreasury {
        _sendRewardToken(amountERC20_, amountCoinbase_);
    }

    /**
     * @notice sends reward tokens to sponsorsManager contract and starts the distribution to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if reward token balance is insufficient
     *  reverts if is not in the distribution window
     * @param amountERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function sendRewardTokenAndStartDistribution(
        uint256 amountERC20_,
        uint256 amountCoinbase_
    )
        external
        payable
        onlyFoundationTreasury
    {
        _sendRewardToken(amountERC20_, amountCoinbase_);
        sponsorsManager.startDistribution();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function to send reward tokens to sponsorsManager contract
     * @param amountERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function _sendRewardToken(uint256 amountERC20_, uint256 amountCoinbase_) internal {
        // TODO: review if we need this
        rewardTokenAmountPerEpoch[EpochLib._epochStart(block.timestamp)] += amountERC20_;
        rewardCoinbaseAmountPerEpoch[EpochLib._epochStart(block.timestamp)] += amountCoinbase_;
        rewardToken.approve(address(sponsorsManager), amountERC20_);
        sponsorsManager.notifyRewardAmount{ value: amountCoinbase_ }(amountERC20_);
    }

    /**
     * @notice receives coinbase to distribute for rewards
     */
    receive() external payable { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
