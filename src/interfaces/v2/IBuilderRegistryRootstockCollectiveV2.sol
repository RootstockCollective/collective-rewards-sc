// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IBuilderRegistryRootstockCollectiveV2 {
    error AddressEmptyCode(address target_);
    error AlreadyActivated();
    error AlreadyCommunityApproved();
    error AlreadyKYCApproved();
    error AlreadyRevoked();
    error BuilderAlreadyExists();
    error BuilderDoesNotExist();
    error ERC1967InvalidImplementation(address implementation_);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error GaugeDoesNotExist();
    error InvalidAddress();
    error InvalidBackerRewardPercentage();
    error InvalidBuilderRewardReceiver();
    error InvalidInitialization();
    error NotActivated();
    error NotAuthorized();
    error NotCommunityApproved();
    error NotInitializing();
    error NotKYCApproved();
    error NotOperational();
    error NotPaused();
    error NotRevoked();
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot_);

    event BackerRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
    event BuilderMigratedV2(address indexed builder_, address indexed migrator_);
    event BuilderRewardReceiverReplacementApproved(address indexed builder_, address newRewardReceiver_);
    event BuilderRewardReceiverReplacementCancelled(address indexed builder_, address newRewardReceiver_);
    event BuilderRewardReceiverReplacementRequested(address indexed builder_, address newRewardReceiver_);
    event CommunityApproved(address indexed builder_);
    event Dewhitelisted(address indexed builder_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
    event Initialized(uint64 version_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Permitted(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event Revoked(address indexed builder_);
    event Unpaused(address indexed builder_);
    event Upgraded(address indexed implementation_);

    function upgradeInterfaceVersion() external view returns (string memory);

    function activateBuilder(address builder_, address rewardReceiver_, uint64 rewardPercentage_) external;

    function approveBuilderKYC(address builder_) external;

    function approveBuilderRewardReceiverReplacement(
        address builder_,
        address rewardReceiverReplacement_
    )
        external;

    function backerRewardPercentage(address builder_)
        external
        view
        returns (uint64 previous_, uint64 next_, uint128 cooldownEndTime_);

    function backersManager() external view returns (address);

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

    function cancelRewardReceiverReplacementRequest() external;

    function communityApproveBuilder(address builder_) external returns (address gauge_);

    function dewhitelistBuilder(address builder_) external;

    function gaugeFactory() external view returns (address);

    function gaugeToBuilder(address gauge_) external view returns (address builder_);

    function getGaugeAt(uint256 index_) external view returns (address);

    function getGaugesLength() external view returns (uint256);

    function getHaltedGaugeAt(uint256 index_) external view returns (address);

    function getHaltedGaugesLength() external view returns (uint256);

    function getRewardPercentageToApply(address builder_) external view returns (uint64);

    function governanceManager() external view returns (address);

    function haltedGaugeLastPeriodFinish(address gauge_) external view returns (uint256 lastPeriodFinish_);

    function hasBuilderRewardReceiverPendingApproval(address builder_) external view returns (bool);

    function initialize(
        address backersManager_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint128 rewardPercentageCooldown_
    )
        external;

    function isBuilderOperational(address builder_) external view returns (bool);

    function isBuilderPaused(address builder_) external view returns (bool);

    function isGaugeHalted(address gauge_) external view returns (bool);

    function isGaugeOperational(address gauge_) external view returns (bool);

    function isGaugeRewarded(address gauge_) external view returns (bool);

    function migrateAllBuildersV2() external;

    function pauseBuilder(address builder_, bytes20 reason_) external;

    function permitBuilder(uint64 rewardPercentage_) external;

    function proxiableUUID() external view returns (bytes32);

    function revokeBuilder() external;

    function revokeBuilderKYC(address builder_) external;

    function rewardDistributor() external view returns (address);

    function rewardPercentageCooldown() external view returns (uint128);

    function setBackerRewardPercentage(uint64 rewardPercentage_) external;

    function setHaltedGaugeLastPeriodFinish(address gauge_, uint256 periodFinish_) external;

    function submitRewardReceiverReplacementRequest(address newRewardReceiver_) external;

    function unpauseBuilder(address builder_) external;

    function upgradeToAndCall(address newImplementation_, bytes memory data_) external payable;

    function validateWhitelisted(address gauge_) external view;
}
