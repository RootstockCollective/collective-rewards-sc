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
    error CollectiveRewardsAddressesNotInitialized();
    error UsdrifTokenAlreadyInitialized();
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
        lastFundedCycleStart = _currentCycleStart;
        _;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice address of rif token rewarded to builder and backers
    IERC20 public rifToken;
    /// @notice BackersManagerRootstockCollective contract address
    BackersManagerRootstockCollective public backersManager;
    ///@notice default RIF amount to be distributed per cycle
    uint256 public defaultRifAmount;
    ///@notice default native amount to be distributed per cycle
    uint256 public defaultNativeAmount;
    uint256 public lastFundedCycleStart;

    // -----------------------------
    // -------- Storage V3 ---------
    // -----------------------------

    /// @notice address of the usdrif token rewarded to builder and backers
    IERC20 public usdrifToken;
    ///@notice default USDRIF amount to be distributed per cycle
    uint256 public defaultUsdrifAmount;

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
     * @dev used to solve circular dependency, backersManager is initialized with this contract address
     *  it must be called ASAP after the initialize.
     * @param backersManager_ BackersManagerRootstockCollective contract address
     */
    function initializeCollectiveRewardsAddresses(address backersManager_) external {
        if (address(backersManager) != address(0)) revert CollectiveRewardsAddressesAlreadyInitialized();
        backersManager = BackersManagerRootstockCollective(backersManager_);
        rifToken = IERC20(BackersManagerRootstockCollective(backersManager_).rifToken());
        usdrifToken = IERC20(BackersManagerRootstockCollective(backersManager_).usdrifToken());
    }

    /**
     * @notice contract initializer
     * @dev used to upgrade the live contracts to V3 and set the usdrifToken based on the BackersManager
     * @dev TODO: After upgrading the live contracts to V3, this function can be deleted and the usdrifToken can be set
     * directly with initializeCollectiveRewardsAddresses
     */
    function initializeV3() external reinitializer(3) {
        if (address(usdrifToken) != address(0)) revert UsdrifTokenAlreadyInitialized();
        BackersManagerRootstockCollective _backersManager = backersManager;
        if (address(_backersManager) == address(0)) revert CollectiveRewardsAddressesNotInitialized();
        usdrifToken = IERC20(_backersManager.usdrifToken());
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice sends rewards to backersManager contract to be distributed to the gauges
     * @dev reverts if is not called by foundation treasury address
     * @param amountRif_ amount of ERC20 rif token to send
     * @param amountUsdrif_ amount of ERC20 usdrif token to send
     * @param amountNative_ amount of Native token to send
     */
    function sendRewards(
        uint256 amountRif_,
        uint256 amountUsdrif_,
        uint256 amountNative_
    )
        external
        payable
        onlyFoundationTreasury
    {
        _sendRewards(amountRif_, amountUsdrif_, amountNative_);
    }

    /**
     * @notice sends rewards to backersManager contract and starts the distribution to the gauges
     * @dev reverts if is not called by foundation treasury address
     *  reverts if is not in the distribution window
     * @param amountRif_ amount of ERC20 rif token to send
     * @param amountUsdrif_ amount of ERC20 usdrif token to send
     * @param amountNative_ amount of Native token to send
     */
    function sendRewardsAndStartDistribution(
        uint256 amountRif_,
        uint256 amountUsdrif_,
        uint256 amountNative_
    )
        external
        payable
        onlyFoundationTreasury
    {
        _sendRewards(amountRif_, amountUsdrif_, amountNative_);
        backersManager.startDistribution();
    }

    /**
     * @notice sets the default reward amounts
     * @dev reverts if is not called by foundation treasury address
     * @param rifTokenAmount_ default amount of ERC20 rif token to send
     * @param usdrifTokenAmount_ default amount of ERC20 usdrif token to send
     * @param nativeAmount_ default amount of Native token to send
     */
    function setDefaultRewardAmount(
        uint256 rifTokenAmount_,
        uint256 usdrifTokenAmount_,
        uint256 nativeAmount_
    )
        external
        payable
        onlyFoundationTreasury
    {
        defaultRifAmount = rifTokenAmount_;
        defaultUsdrifAmount = usdrifTokenAmount_;
        defaultNativeAmount = nativeAmount_;
    }

    /**
     * @notice sends rewards to backersManager contract with default amounts
     * @dev reverts if is called more than once per cycle
     */
    function sendRewardsWithDefaultAmount() external payable onlyOncePerCycle {
        _sendRewards(defaultRifAmount, defaultUsdrifAmount, defaultNativeAmount);
    }

    /**
     * @notice sends rewards to backersManager contract with default amounts and starts the distribution
     * @dev reverts if is called more than once per cycle
     */
    function sendRewardsAndStartDistributionWithDefaultAmount() external payable onlyOncePerCycle {
        _sendRewards(defaultRifAmount, defaultUsdrifAmount, defaultNativeAmount);
        backersManager.startDistribution();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice internal function to send rewards to backersManager contract
     * @param amountRif_ amount of ERC20 rif token to send
     * @param amountUsdrif_ amount of ERC20 usdrif token to send
     * @param amountNative_ amount of Native token to send
     */
    function _sendRewards(uint256 amountRif_, uint256 amountUsdrif_, uint256 amountNative_) internal {
        BackersManagerRootstockCollective _backersManager = backersManager;
        rifToken.approve(address(_backersManager), amountRif_);
        usdrifToken.approve(address(_backersManager), amountUsdrif_);
        _backersManager.notifyRewardAmount{ value: amountNative_ }(amountRif_, amountUsdrif_);
    }

    /**
     * @notice receives native tokens to distribute for rewards
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
