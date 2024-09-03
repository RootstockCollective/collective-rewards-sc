// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Upgradeable } from "../governance/Upgradeable.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";

/**
 * @title SimplfiedRewardDistributor
 * @notice Simplified version for the MVP.
 *  Accumulates all the rewards and distribute them equally to all the builders for each epoch
 */
contract SimplifiedRewardDistributor is Upgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token rewarded to builders
    IERC20 public rewardToken;
    /// @notice map of builders reward receiver
    mapping(address builder => address payable rewardReceiver) public builderRewardReceiver;
    // @notice array of whitelisted builders
    EnumerableSet.AddressSet internal _whitelistedBuilders;

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
     */
    function initialize(address changeExecutor_, address rewardToken_) external initializer {
        __ReentrancyGuard_init();
        __Upgradeable_init(changeExecutor_);
        rewardToken = IERC20(rewardToken_);
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice whitelist builder
     * @dev reverts if is builder is already whitelisted
     * @param builder_ address of the builder
     * @param rewardReceiver_ address of the builder reward receiver
     */
    function whitelistBuilder(
        address builder_,
        address payable rewardReceiver_
    )
        external
        onlyGovernorOrAuthorizedChanger
    {
        builderRewardReceiver[builder_] = rewardReceiver_;
        _whitelistedBuilders.add(builder_);
    }

    /**
     * @notice remove builder from whitelist
     * @dev reverts if is builder is not whitelisted
     * @param builder_ address of the builder
     */
    function removeWhitelistedBuilder(address builder_) external onlyGovernorOrAuthorizedChanger {
        builderRewardReceiver[builder_] = payable(0);
        _whitelistedBuilders.remove(builder_);
    }

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

    /**
     * @notice get length of whitelisted builders array
     */
    function getWhitelistedBuildersLength() external view returns (uint256) {
        return _whitelistedBuilders.length();
    }

    /**
     * @notice get whitelisted builder from array
     */
    function getWhitelistedBuilder(uint256 index_) external view returns (address) {
        return _whitelistedBuilders.at(index_);
    }

    /**
     * @notice return true is builder is whitelisted
     */
    function isWhitelisted(address builder_) external view returns (bool) {
        return _whitelistedBuilders.contains(builder_);
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
        uint256 _buildersLength = _whitelistedBuilders.length();
        uint256 _rewardTokenPayment = rewardTokenAmount_ / _buildersLength;
        uint256 _coinbasePayment = coinbaseAmount_ / _buildersLength;
        for (uint256 i = 0; i < _buildersLength; i = UtilsLib._uncheckedInc(i)) {
            address payable _rewardReceiver = builderRewardReceiver[_whitelistedBuilders.at(i)];
            if (_rewardTokenPayment > 0) {
                SafeERC20.safeTransfer(rewardToken, _rewardReceiver, _rewardTokenPayment);
            }
            if (_coinbasePayment > 0) {
                Address.sendValue(_rewardReceiver, _coinbasePayment);
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
