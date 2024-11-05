// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UpgradeableRootstockCollective } from "./governance/UpgradeableRootstockCollective.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SponsorsManager } from "./SponsorsManager.sol";
import { IGovernanceManagerRootstockCollective } from "./interfaces/IGovernanceManagerRootstockCollective.sol";

/**
 * @title RewardDistributor
 * @notice Accumulates all the rewards to be distributed for each cycle
 */
contract RewardDistributor is UpgradeableRootstockCollective {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotFoundationTreasury();
    error CollectiveRewardsAddressesAlreadyInitialized();

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyFoundationTreasury() {
        governanceManager.validateFoundationTreasury(msg.sender);
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
    /// @notice tracks amount of reward tokens distributed per cycle
    mapping(uint256 cycleTimestampStart => uint256 amount) public rewardTokenAmountPerCycle;
    /// @notice tracks amount of coinbase distributed per cycle
    mapping(uint256 cycleTimestampStart => uint256 amount) public rewardCoinbaseAmountPerCycle;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @dev initializeCollectiveRewardsAddresses() must be called ASAP after this initialization
     * @param governanceManager_ contract with permissioned roles
     */
    function initialize(IGovernanceManagerRootstockCollective governanceManager_) external initializer {
        __Upgradeable_init(governanceManager_);
    }

    /**
     * @notice CollectiveRewards addresses initializer
     * @dev used to solve circular dependency, sponsorsManager is initialized with this contract address
     *  it must be called ASAP after the initialize.
     * @param sponsorsManager_ SponsorsManager contract address
     */
    function initializeCollectiveRewardsAddresses(address sponsorsManager_) external {
        if (address(sponsorsManager) != address(0)) revert CollectiveRewardsAddressesAlreadyInitialized();
        sponsorsManager = SponsorsManager(sponsorsManager_);
        rewardToken = IERC20(SponsorsManager(sponsorsManager_).rewardToken());
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice sends rewards to sponsorsManager contract to be distributed to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if rewards balance is insufficient
     * @param amountERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function sendRewards(uint256 amountERC20_, uint256 amountCoinbase_) external payable onlyFoundationTreasury {
        _sendRewards(amountERC20_, amountCoinbase_);
    }

    /**
     * @notice sends rewards to sponsorsManager contract and starts the distribution to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if rewards balance is insufficient
     *  reverts if is not in the distribution window
     * @param amountERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function sendRewardsAndStartDistribution(
        uint256 amountERC20_,
        uint256 amountCoinbase_
    )
        external
        payable
        onlyFoundationTreasury
    {
        _sendRewards(amountERC20_, amountCoinbase_);
        sponsorsManager.startDistribution();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function to send rewards to sponsorsManager contract
     * @param amountERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function _sendRewards(uint256 amountERC20_, uint256 amountCoinbase_) internal {
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
