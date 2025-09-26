// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IBackersManagerRootstockCollectiveV2 {
    error AddressEmptyCode(address target_);
    error AddressInsufficientBalance(address account_);
    error AlreadyOptedInRewards();
    error BackerHasAllocations();
    error BackerOptedOutRewards();
    error BeforeDistribution();
    error CycleDurationTooShort();
    error DistributionDurationTooLong();
    error DistributionDurationTooShort();
    error DistributionModifiedDuringDistributionWindow();
    error DistributionPeriodDidNotStart();
    error ERC1967InvalidImplementation(address implementation_);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error GaugeDoesNotExist();
    error InvalidAddress();
    error InvalidInitialization();
    error NoGaugesForDistribution();
    error NotAuthorized();
    error NotEnoughStaking();
    error NotInDistributionPeriod();
    error NotInitializing();
    error NotValidChangerOrFoundation();
    error OnlyInDistributionWindow();
    error PositiveAllocationOnHaltedGauge();
    error SafeERC20FailedOperation(address token_);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot_);
    error UnequalLengths();

    event BackerRewardsOptedIn(address indexed backer_);
    event BackerRewardsOptedOut(address indexed backer_);
    event Initialized(uint64 version_);
    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_);
    event NewDistributionDuration(uint256 newDistributionDuration_, address by_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);
    event RewardDistributionStarted(address indexed sender_);
    event Upgraded(address indexed implementation_);

    function upgradeInterfaceVersion() external view returns (string memory);

    function allocate(address gauge_, uint256 allocation_) external;

    function allocateBatch(address[] memory gauges_, uint256[] memory allocations_) external;

    function backerTotalAllocation(address backer_) external view returns (uint256 allocation_);

    function builderRegistry() external view returns (address);

    function canWithdraw(address targetAddress_, uint256) external view returns (bool);

    function claimBackerRewards(address[] memory gauges_) external;

    function claimBackerRewards(address rewardToken_, address[] memory gauges_) external;

    function communityApproveBuilder(address builder_) external returns (address gauge_);

    function cycleData()
        external
        view
        returns (
            uint32 previousDuration_,
            uint32 nextDuration_,
            uint64 previousStart_,
            uint64 nextStart_,
            uint24 offset_
        );

    function cycleNext(uint256 timestamp_) external view returns (uint256);

    function cycleStart(uint256 timestamp_) external view returns (uint256);

    function distribute() external returns (bool finished_);

    function distributionDuration() external view returns (uint32);

    function endDistributionWindow(uint256 timestamp_) external view returns (uint256);

    function getCycleStartAndDuration() external view returns (uint256, uint256);

    function governanceManager() external view returns (address);

    function haltGaugeShares(address gauge_) external;

    function indexLastGaugeDistributed() external view returns (uint256);

    function initialize(
        address governanceManager_,
        address rewardToken_,
        address stakingToken_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint32 distributionDuration_
    )
        external;

    function initializeV2(address builderRegistry_) external;

    function notifyRewardAmount(uint256 amount_) external payable;

    function onDistributionPeriod() external view returns (bool);

    function optInRewards(address backer_) external;

    function optOutRewards(address backer_) external;

    function periodFinish() external view returns (uint256);

    function proxiableUUID() external view returns (bytes32);

    function resumeGaugeShares(address gauge_) external;

    function rewardToken() external view returns (address);

    function rewardTokenApprove(address gauge_, uint256 value_) external;

    function rewardsCoinbase() external view returns (uint256);

    function rewardsERC20() external view returns (uint256);

    function rewardsOptedOut(address backer_) external view returns (bool hasOptedOut_);

    function setCycleDuration(uint32 newCycleDuration_, uint24 cycleStartOffset_) external;

    function setDistributionDuration(uint32 newDistributionDuration_) external;

    function stakingToken() external view returns (address);

    function startDistribution() external returns (bool finished_);

    function supportsInterface(bytes4 interfaceId_) external view returns (bool);

    function tempTotalPotentialReward() external view returns (uint256);

    function timeUntilNextCycle(uint256 timestamp_) external view returns (uint256);

    function totalPotentialReward() external view returns (uint256);

    function upgradeToAndCall(address newImplementation_, bytes memory data_) external payable;
}
