// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IRewardDistributorRootstockCollectiveV2 {
    error AddressEmptyCode(address target_);
    error CollectiveRewardsAddressesAlreadyInitialized();
    error ERC1967InvalidImplementation(address implementation_);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error InvalidInitialization();
    error NotFoundationTreasury();
    error NotInitializing();
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot_);

    event Initialized(uint64 version_);
    event Upgraded(address indexed implementation_);

    function upgradeInterfaceVersion() external view returns (string memory);

    function backersManager() external view returns (address);

    function defaultRewardCoinbaseAmount() external view returns (uint256);

    function defaultRewardTokenAmount() external view returns (uint256);

    function governanceManager() external view returns (address);

    function initialize(address governanceManager_) external;

    function initializeCollectiveRewardsAddresses(address backersManager_) external;

    function proxiableUUID() external view returns (bytes32);

    function rewardToken() external view returns (address);

    function sendRewards(uint256 amountERC20_, uint256 amountCoinbase_) external payable;

    function sendRewardsAndStartDistribution(uint256 amountERC20_, uint256 amountCoinbase_) external payable;

    function sendRewardsAndStartDistributionWithDefaultAmount() external payable;

    function sendRewardsWithDefaultAmount() external payable;

    function setDefaultRewardAmount(uint256 tokenAmount_, uint256 coinbaseAmount_) external payable;

    function upgradeToAndCall(address newImplementation_, bytes memory data_) external payable;

    receive() external payable;
}
