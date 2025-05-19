// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UpgradeableRootstockCollective } from "./governance/UpgradeableRootstockCollective.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BackersManagerRootstockCollective } from "./backersManager/BackersManagerRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "./interfaces/IGovernanceManagerRootstockCollective.sol";

/**
 * @title RewardDistributorRootstockCollective
 * @notice Accumulates all the rewards to be distributed for each cycle
 */
contract RewardDistributorRootstockCollective is UpgradeableRootstockCollective {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotFoundationTreasury();
    error CollectiveRewardsAddressesAlreadyInitialized();
    error CycleAlreadyFunded();

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyFoundationTreasury() {
        governanceManager.validateFoundationTreasury(msg.sender);
        _;
    }

    modifier onlyOncePerCycle() {
        uint256 _currentCycleStart = backersManager.cycleStart(block.timestamp);
        if (lastFundedCycleStart == _currentCycleStart) revert CycleAlreadyFunded();
        _;
        lastFundedCycleStart = _currentCycleStart;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of the token rewarded to builder and backers
    IERC20 public rewardToken;
    /// @notice BackersManagerRootstockCollective contract address
    BackersManagerRootstockCollective public backersManager;
    ///@notice default reward token amount
    uint256[] public defaultRewardTokenAmount;
    ///@notice default reward coinbase amount
    uint256 public defaultRewardCoinbaseAmount;
    uint256 public lastFundedCycleStart;

    // -----------------------------
    // ---------- V2 Storage ----------
    // -----------------------------

    /// @notice addresses of all valid rewards tokens
    address[] public rewardsTokens;

    /// @notice mapping of validated reward tokens
    mapping(address => bool) public rewardsTokensValid;

    /// @notice mapping of reward amounts of reward tokens
    mapping(address => uint256) public rewardsAmounts;

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
     * @notice contract initializer
     * @param usdrifRewardToken_ address of the token rewarded to builder and voters. Only tokens that adhere to the
     * ERC-20
     * standard are supported.
     * @notice For more info on supported tokens, see:
     * https://github.com/RootstockCollective/collective-rewards-sc/blob/main/README.md#Reward-token
     */
    function initializeV2(address usdrifRewardToken_) external reinitializer(2) {
        // make 2 rewardTokens true and add them to the array
        rewardsTokensValid[usdrifRewardToken_] = true;
        rewardsTokensValid[address(rewardToken)] = true;
        rewardsTokens.push(address(rewardToken));
        rewardsTokens.push(usdrifRewardToken_);
    }

    /**
     * @notice CollectiveRewards addresses initializer
     * @dev used to solve circular dependency, backersManager is initialized with this contract address
     *  it must be called ASAP after the initialize.
     * @param backersManager_ BackersManagerRootstockCollective contract address
     */
    function initializeCollectiveRewardsAddresses(address backersManager_) external {
        if (address(backersManager) != address(0)) revert CollectiveRewardsAddressesAlreadyInitialized();
        backersManager = BackersManagerRootstockCollective(backersManager_);
        rewardToken = IERC20(BackersManagerRootstockCollective(backersManager_).rewardToken());
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice sends rewards to backersManager contract to be distributed to the gauges
     * @dev reverts if is not called by foundation treasury address
     * @param amountsERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function sendRewards(
        uint256[] memory amountsERC20_,
        uint256 amountCoinbase_
    )
        external
        payable
        onlyFoundationTreasury
    {
        _sendRewards(amountsERC20_, amountCoinbase_);
    }

    /**
     * @notice sends rewards to backersManager contract and starts the distribution to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if is not in the distribution window
     * @param amountsERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function sendRewardsAndStartDistribution(
        uint256[] memory amountsERC20_,
        uint256 amountCoinbase_
    )
        external
        payable
        onlyFoundationTreasury
    {
        _sendRewards(amountsERC20_, amountCoinbase_);
        backersManager.startDistribution();
    }

    /**
     * @notice sets the default reward amounts
     * @dev reverts if is not called by foundation treasury address
     * @param tokenAmounts_ default amount of ERC20 reward token to send
     * @param coinbaseAmount_ default amount of Coinbase reward token to send
     */
    function setDefaultRewardAmounts(
        uint256[] memory tokenAmounts_,
        uint256 coinbaseAmount_
    )
        external
        payable
        onlyFoundationTreasury
    {
        defaultRewardTokenAmount = tokenAmounts_;
        defaultRewardCoinbaseAmount = coinbaseAmount_;
    }

    /**
     * @notice sends rewards to backersManager contract with default amounts
     * @dev reverts if is called more than once per cycle
     */
    function sendRewardsWithDefaultAmount() external payable onlyOncePerCycle {
        _sendRewards(defaultRewardTokenAmount, defaultRewardCoinbaseAmount);
    }

    /**
     * @notice sends rewards to backersManager contract with default amounts and starts the distribution
     * @dev reverts if is called more than once per cycle
     */
    function sendRewardsAndStartDistributionWithDefaultAmount() external payable onlyOncePerCycle {
        _sendRewards(defaultRewardTokenAmount, defaultRewardCoinbaseAmount);
        backersManager.startDistribution();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function to send rewards to backersManager contract
     * @param amountsERC20_ amount of ERC20 reward token to send
     * @param amountCoinbase_ amount of Coinbase reward token to send
     */
    function _sendRewards(uint256[] memory amountsERC20_, uint256 amountCoinbase_) internal {
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            IERC20(rewardsTokens[i]).approve(address(backersManager), amountsERC20_[i]);
        }
        backersManager.notifyRewardAmountERC20(rewardsTokens, amountsERC20_);
        backersManager.notifyRewardAmountCoinbase{ value: amountCoinbase_ }();
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
