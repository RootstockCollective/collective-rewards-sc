// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SimplifiedBuilderRegistry } from "./SimplifiedBuilderRegistry.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";

/**
 * @title SimplfiedRewardDistributor
 * @notice Simplified version for the MVP.
 *  Accumulates all the rewards and distribute them equally to all the builders for each epoch
 */
contract SimplifiedRewardDistributor is SimplifiedBuilderRegistry, ReentrancyGuardUpgradeable {
    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token rewarded to builders
    IERC20 public rewardToken;

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
     * @param rewardToken_ address of the token rewarded to builders
     * @param kycApprover_ account responsible of approving Builder's Know you Costumer policies and Legal requirements
     */
    function initialize(address changeExecutor_, address rewardToken_, address kycApprover_) external initializer {
        __ReentrancyGuard_init();
        ___SimplifiedBuilderRegistry_init(changeExecutor_, kycApprover_);
        rewardToken = IERC20(rewardToken_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice distributes all the reward tokens and coinbase equally to all the whitelisted builders
     */
    function distribute() external payable {
        _distribute(rewardToken.balanceOf(address(this)), address(this).balance);
    }

    /**
     * @notice distributes all the reward tokens equally to all the whitelisted builders
     */
    function distributeRewardToken() external {
        _distribute(rewardToken.balanceOf(address(this)), 0);
    }

    /**
     * @notice distributes all the coinbase rewards equally to all the whitelisted builders
     */
    function distributeCoinbase() external payable {
        _distribute(0, address(this).balance);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice distributes reward tokens and coinbase equally to all the whitelisted builders
     * @dev reverts if there is not enough reward token or coinbase balance
     * @param rewardTokenAmount_ amount of reward token to distribute
     * @param coinbaseAmount_ total amount of coinbase to be distribute between builders
     */
    function _distribute(uint256 rewardTokenAmount_, uint256 coinbaseAmount_) internal nonReentrant {
        uint256 _buildersLength = whitelistedBuilders.length;
        uint256 _rewardTokenPayment = rewardTokenAmount_ / _buildersLength;
        uint256 _coinbasePayment = coinbaseAmount_ / _buildersLength;
        for (uint256 i = 0; i < _buildersLength; i = UtilsLib.unchecked_inc(i)) {
            address payable rewardReceiver = builderRewardReceiver[whitelistedBuilders[i]];
            if (_rewardTokenPayment > 0) {
                SafeERC20.safeTransfer(rewardToken, rewardReceiver, _rewardTokenPayment);
            }
            if (_coinbasePayment > 0) {
                Address.sendValue(rewardReceiver, _coinbasePayment);
            }
        }
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
