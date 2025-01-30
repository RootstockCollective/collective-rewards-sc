// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

interface IBackersManagerV1 {
    // Constructor
    function initialize() external;

    // Errors
    error AddressEmptyCode(address target_);
    error AddressInsufficientBalance(address account_);
    error AlreadyActivated();
    error AlreadyCommunityApproved();
    error AlreadyKYCApproved();
    error AlreadyRevoked();
    error BeforeDistribution();
    error BuilderAlreadyExists();
    error BuilderDoesNotExist();
    error CycleDurationTooShort();
    error DistributionDurationTooLong();
    error DistributionDurationTooShort();
    error DistributionModifiedDuringDistributionWindow();
    error DistributionPeriodDidNotStart();
    error ERC1967InvalidImplementation(address implementation_);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error GaugeDoesNotExist();
    error InvalidBackerRewardPercentage();
    error InvalidBuilderRewardReceiver();
    error InvalidInitialization();
    error NoGaugesForDistribution();
    error NotActivated();
    error NotCommunityApproved();
    error NotEnoughStaking();
    error NotInDistributionPeriod();
    error NotInitializing();
    error NotKYCApproved();
    error NotOperational();
    error NotPaused();
    error NotRevoked();
    error NotValidChangerOrFoundation();
    error OnlyInDistributionWindow();
    error PositiveAllocationOnHaltedGauge();
    error SafeERC20FailedOperation(address token_);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot_);
    error UnequalLengths();

    // Events
    event BackerRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
    event BuilderRewardReceiverReplacementApproved(address indexed builder_, address newRewardReceiver_);
    event BuilderRewardReceiverReplacementCancelled(address indexed builder_, address newRewardReceiver_);
    event BuilderRewardReceiverReplacementRequested(address indexed builder_, address newRewardReceiver_);
    event CommunityApproved(address indexed builder_);
    event Dewhitelisted(address indexed builder_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
    event Initialized(uint64 version_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_);
    event NewDistributionDuration(uint256 newDistributionDuration_, address by_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Permitted(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event Revoked(address indexed builder_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);
    event RewardDistributionStarted(address indexed sender_);
    event Unpaused(address indexed builder_);
    event Upgraded(address indexed implementation_);

    // Functions
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

    function activateBuilder(address builder_, address rewardReceiver_, uint64 rewardPercentage_) external;

    function allocate(address gauge_, uint256 allocation_) external;

    function allocateBatch(address[] calldata gauges_, uint256[] calldata allocations_) external;

    function approveBuilderKYC(address builder_) external;

    function approveBuilderRewardReceiverReplacement(address builder_, address rewardReceiverReplacement_) external;

    function backerRewardPercentage(address builder_)
        external
        view
        returns (uint64 previous_, uint64 next_, uint128 cooldownEndTime_);

    function backerTotalAllocation(address backer_) external view returns (uint256 allocation_);

    function builderRewardReceiver(address builder_) external view returns (address rewardReceiver_);

    function builderRewardReceiverReplacement(address builder_)
        external
        view
        returns (address rewardReceiverReplacement_);

    function builderState(address builder_)
        external
        view
        returns (
            bool activated_,
            bool kycApproved_,
            bool communityApproved_,
            bool paused_,
            bool revoked_,
            bytes7 reserved_,
            bytes20 pausedReason_
        );

    function builderToGauge(address builder_) external view returns (address gauge_);

    function canWithdraw(address targetAddress_, uint256) external view returns (bool);

    function cancelRewardReceiverReplacementRequest() external;

    function claimBackerRewards(address[] calldata gauges_) external;

    function claimBackerRewards(address rewardToken_, address[] calldata gauges_) external;

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

    function dewhitelistBuilder(address builder_) external;

    function distribute() external returns (bool finished_);

    function distributionDuration() external view returns (uint32);

    function endDistributionWindow(uint256 timestamp_) external view returns (uint256);

    function gaugeFactory() external view returns (address);

    function gaugeToBuilder(address gauge_) external view returns (address builder_);

    function getCycleStartAndDuration() external view returns (uint256, uint256);

    function getGaugeAt(uint256 index_) external view returns (address);

    function getGaugesLength() external view returns (uint256);

    function getHaltedGaugeAt(uint256 index_) external view returns (address);

    function getHaltedGaugesLength() external view returns (uint256);

    function getRewardPercentageToApply(address builder_) external view returns (uint64);

    function governanceManager() external view returns (IGovernanceManagerRootstockCollective);

    function haltedGaugeLastPeriodFinish(address gauge_) external view returns (uint256 lastPeriodFinish_);

    function hasBuilderRewardReceiverPendingApproval(address builder_) external view returns (bool);

    function indexLastGaugeDistributed() external view returns (uint256);

    function initialize(
        address governanceManager_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint32 distributionDuration_,
        uint128 rewardPercentageCooldown_
    )
        external;

    function isBuilderOperational(address builder_) external view returns (bool);

    function isBuilderPaused(address builder_) external view returns (bool);

    function isGaugeHalted(address gauge_) external view returns (bool);

    function isGaugeOperational(address gauge_) external view returns (bool);

    function isGaugeRewarded(address gauge_) external view returns (bool);

    function migrateBuilder(address builder_, address rewardAddress_, uint64 rewardPercentage_) external;

    function notifyRewardAmount(uint256 amount_) external payable;

    function onDistributionPeriod() external view returns (bool);

    function pauseBuilder(address builder_, bytes20 reason_) external;

    function periodFinish() external view returns (uint256);

    function permitBuilder(uint64 rewardPercentage_) external;

    function proxiableUUID() external view returns (bytes32);

    function revokeBuilder() external;

    function revokeBuilderKYC(address builder_) external;

    function rewardDistributor() external view returns (address);

    function rewardPercentageCooldown() external view returns (uint128);

    function rewardToken() external view returns (address);

    function rewardsCoinbase() external view returns (uint256);

    function rewardsERC20() external view returns (uint256);

    function setBackerRewardPercentage(uint64 rewardPercentage_) external;

    function setCycleDuration(uint32 newCycleDuration_, uint24 cycleStartOffset_) external;

    function setDistributionDuration(uint32 newDistributionDuration_) external;

    function stakingToken() external view returns (IERC20);

    function startDistribution() external returns (bool finished_);

    function submitRewardReceiverReplacementRequest(address newRewardReceiver_) external;

    function supportsInterface(bytes4 interfaceId_) external view returns (bool);

    function tempTotalPotentialReward() external view returns (uint256);

    function timeUntilNextCycle(uint256 timestamp_) external view returns (uint256);

    function totalPotentialReward() external view returns (uint256);

    function unpauseBuilder(address builder_) external;

    function upgradeToAndCall(address newImplementation_, bytes calldata data_) external payable;
}
