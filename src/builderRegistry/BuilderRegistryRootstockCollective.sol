// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UtilsLib } from "../libraries/UtilsLib.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { BackersManagerRootstockCollective } from "../backersManager/BackersManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "../gauge/GaugeFactoryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../interfaces/IGovernanceManagerRootstockCollective.sol";
import { UpgradeableRootstockCollective } from "../governance/UpgradeableRootstockCollective.sol";

enum BuilderState {
    Inactive,
    CommunityApproved,
    KYCApproved,
    Active,
    Paused,
    DEAD // Marks the end for iterations over State
}

interface StateMachineErrors {
    error NoSuchTransition(BuilderState originalState_, BuilderState targetState_);
}

interface BuilderEvents {
    event BuilderStateChanged(address indexed builder_, BuilderState prevState_, BuilderState newState_);
    event RewardsInitialized(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
    event Blacklisted(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Unpaused(address indexed builder_);
    event ReceivingRewardsPaused(address indexed builder_);
    event ReceivingRewardsResumed(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event BackerRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event BuilderRewardReceiverReplacementRequested(address indexed builder_, address newRewardReceiver_);
    event BuilderRewardReceiverReplacementCancelled(address indexed builder_, address newRewardReceiver_);
    event BuilderRewardReceiverReplacementApproved(address indexed builder_, address newRewardReceiver_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
    event BuilderMigrated(address indexed builder_, address indexed migrator_);
}

interface BuilderErrors {
    error AlreadyKYCApproved();
    error AlreadyCommunityApproved();
    error AlreadyPausedRewards();
    error AlreadyReceivingRewards();
    error RewardsNotInitialized();
    error RewardsAlreadyInitialized();
    error NotKYCApproved();
    error NotCommunityApproved();
    error NotPaused();
    error CannotReceiveRewards();
    error NotOperational();
    error InvalidBackerRewardPercentage();
    error InvalidBuilderRewardReceiver();
    error BuilderAlreadyExists();
    error BuilderDoesNotExist();
    error GaugeDoesNotExist();
    error NotAuthorized();
}

/**
 * @title BuilderRegistryRootstockCollective
 * @notice Keeps registers of the builders
 */
contract BuilderRegistryRootstockCollective is UpgradeableRootstockCollective, BuilderEvents, BuilderErrors {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant _MAX_REWARD_PERCENTAGE = UtilsLib._PRECISION;

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyKycApprover() {
        governanceManager.validateKycApprover(msg.sender);
        _;
    }

    modifier onlyBackersManager() {
        if (msg.sender != address(backersManager)) {
            revert NotAuthorized();
        }
        _;
    }

    modifier transition(
        address builder_,
        BuilderState requiredState_,
        BuilderState targetState_
    ) {
        if (builderState[builder_] != requiredState_) {
            revert StateMachineErrors.NoSuchTransition(builderState[builder_], targetState_);
        }
        _;
        builderState[builder_] = targetState_;
        emit BuilderStateChanged(builder_, requiredState_, targetState_);
    }

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct RewardPercentageData {
        // previous reward percentage
        uint64 previous;
        // next reward percentage
        uint64 next;
        // reward percentage cooldown end time. After this time, new reward percentage will be applied
        uint128 cooldownEndTime;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------
    /// @notice reward distributor address. If a builder is KYC revoked their unclaimed rewards will sent back here
    address public rewardDistributor;
    /// @notice map of builders state
    mapping(address builder => BuilderState state) public builderState;
    /// @notice map of builders reward receiver
    mapping(address builder => address rewardReceiver) public builderRewardReceiver;
    /// @notice map of builders reward receiver replacement, used as a buffer until the new address is accepted
    mapping(address builder => address rewardReceiverReplacement) public builderRewardReceiverReplacement;
    /// @notice map of builder's backers reward percentage data
    mapping(address builder => RewardPercentageData rewardPercentageData) public backerRewardPercentage;
    /// @notice array of all the operational gauges
    EnumerableSet.AddressSet internal _gauges;
    /// @notice array of all the halted gauges
    EnumerableSet.AddressSet internal _haltedGauges;
    /// @notice gauge factory contract address
    GaugeFactoryRootstockCollective public gaugeFactory;
    /// @notice gauge contract for a builder
    mapping(address builder => GaugeRootstockCollective gauge) public builderToGauge;
    /// @notice builder address for a gauge contract
    mapping(GaugeRootstockCollective gauge => address builder) public gaugeToBuilder;
    /// @notice map of last period finish for halted gauges
    mapping(GaugeRootstockCollective gauge => uint256 lastPeriodFinish) public haltedGaugeLastPeriodFinish;
    /// @notice time that must elapse for a new reward percentage from a builder to be applied
    uint128 public rewardPercentageCooldown;
    BackersManagerRootstockCollective public backersManager;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param governanceManager_ contract with permissioned roles
     * @param gaugeFactory_ address of the GaugeFactoryRootstockCollective contract
     * @param rewardDistributor_ address of the rewardDistributor contract
     * @param rewardPercentageCooldown_ time that must elapse for a new reward percentage from a builder to be applied
     */
    function initialize(
        IGovernanceManagerRootstockCollective governanceManager_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint128 rewardPercentageCooldown_
    ) external initializer {
        __Upgradeable_init(governanceManager_);
        gaugeFactory = GaugeFactoryRootstockCollective(gaugeFactory_);
        rewardDistributor = rewardDistributor_;
        rewardPercentageCooldown = rewardPercentageCooldown_;
    }

    function initializeBackersManager(BackersManagerRootstockCollective backersManager_) external {
        require(address(backersManager) == address(0), "Already set");
        require(address(backersManager_) != address(0), "Must set backers manager");
        backersManager = backersManager_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    function setHaltedGaugeLastPeriodFinish(
        GaugeRootstockCollective gauge_,
        uint256 periodFinish_
    ) external onlyBackersManager {
        haltedGaugeLastPeriodFinish[gauge_] = periodFinish_;
    }

    /**
     * @notice Builder submits a request to replace his rewardReceiver address,
     * the request will then need to be approved by `approveBuilderRewardReceiverReplacement`
     * @dev reverts if Builder is not Operational
     * @param newRewardReceiver_ new address the builder is requesting to use
     */
    function submitRewardReceiverReplacementRequest(address newRewardReceiver_) external {
        _submitRewardReceiverReplacementRequest(newRewardReceiver_);
        emit BuilderRewardReceiverReplacementRequested(msg.sender, newRewardReceiver_);
    }

    /**
     * @notice Builder cancels his request to replace his rewardReceiver address
     * @dev reverts if Builder is not Operational
     */
    function cancelRewardReceiverReplacementRequest() external {
        // By overriding the replacement with the current, it effectively cancels the request
        address _currRewardReceiver = builderRewardReceiver[msg.sender];
        _submitRewardReceiverReplacementRequest(_currRewardReceiver);
        emit BuilderRewardReceiverReplacementCancelled(msg.sender, _currRewardReceiver);
    }

    /**
     * @notice KYCApprover approves Builder's request to replace his rewardReceiver address
     * @dev reverts if provided `rewardReceiverReplacement_` doesn't match Builder's request
     * @param builder_ address of the builder
     * @param rewardReceiverReplacement_ new address the builder is requesting to use
     */
    function approveBuilderRewardReceiverReplacement(
        address builder_,
        address rewardReceiverReplacement_
    ) external onlyKycApprover {
        // Only an operational builder can be approved
        if (!isBuilderOperational(builder_)) revert NotOperational();

        address _rewardReceiverReplacement = builderRewardReceiverReplacement[builder_];
        if (_rewardReceiverReplacement != rewardReceiverReplacement_) revert InvalidBuilderRewardReceiver();
        builderRewardReceiver[builder_] = _rewardReceiverReplacement;
        emit BuilderRewardReceiverReplacementApproved(builder_, rewardReceiverReplacement_);
    }

    /**
     * @notice returns true if the builder has an open request to replace his receiver address
     * @param builder_ address of the builder
     */
    function hasBuilderRewardReceiverPendingApproval(address builder_) external view returns (bool) {
        return
            builderRewardReceiverReplacement[builder_] != address(0) &&
            builderRewardReceiver[builder_] != builderRewardReceiverReplacement[builder_];
    }

    /**
     * @notice approves builder's KYC after a revocation
     * @dev reverts if it is not called by the owner address
     * reverts if builder has been initialized already but gauge does not exist
     * reverts if builder is already KYC approved
     * reverts if called in non iniactive, non community approved state
     * @param builder_ address of the builder
     */
    function approveBuilderKYC(address builder_) external onlyKycApprover {
        _approveBuilderKYC(builder_);
    }

    /**
     * @notice Initialises reward data for a builder and approves KYC, creating a gauge if needed
     * @param builder_ address of the builder
     * @param rewardReceiver_  address of the reward receiver (may be the same as the builder)
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function _initializeBuilder(
        address builder_,
        address rewardReceiver_,
        uint64 rewardPercentage_
    ) external onlyKycApprover {
        if (backerRewardPercentage[builder_].cooldownEndTime != 0) {
            // cooldown time is only ever 0 if the builder is uninitialized
            revert RewardsAlreadyInitialized();
        }
        _initializeRewardData(builder_, rewardReceiver_, rewardPercentage_);
        _approveBuilderKYC(builder_);
    }

    /**
     * @notice revokes builder's KYC and sent builder unclaimed rewards to rewardDistributor contract
     * @dev reverts if it is not called by the owner address
     * reverts if it is not KYC approved
     * @param builder_ address of the builder
     */
    function revokeBuilderKYC(address builder_) external onlyKycApprover {
        /**
         *
         *         enum BuilderState {
         *             Inactive = 0
         *             CommunityApproved = 1
         *             KYCApproved = 2
         *             Active = 3
         *             Paused = 4
         *             DEAD = 5
         *         }
         *
         *         2 -> 0 KYCApproved -> Inactive
         *         3 -> 1 Active -> CommunityApproved
         *         4 -> 1 Paused -> CommunityApproved
         */
        BuilderState _state = builderState[builder_];
        BuilderState _targetState;

        if (_state == BuilderState.KYCApproved) {
            _targetState = BuilderState.Inactive;
        } else if (_state == BuilderState.Active || _state == BuilderState.Paused) {
            _targetState = BuilderState.CommunityApproved;
        } else {
            revert StateMachineErrors.NoSuchTransition(_state, BuilderState.DEAD); // the DEAD state is not accurate but
            // for PoC it's ok
        }

        GaugeRootstockCollective _gauge = builderToGauge[builder_];
        // if builder is community approved, it has a gauge associated
        if (address(_gauge) != address(0)) {
            _haltGauge(_gauge);
            _gauge.moveBuilderUnclaimedRewards(rewardDistributor);
        }

        builderState[builder_] = _targetState;
        emit BuilderStateChanged(builder_, _state, _targetState);
    }

    /**
     * @notice community approve builder and create its gauge
     * @dev reverts if it is not called by the governor address or authorized changer
     * reverts if is already community approved
     * reverts if it has a gauge associated
     * @param builder_ address of the builder
     * @return gauge_ gauge contract
     */
    function communityApproveBuilder(
        address builder_
    ) external onlyValidChanger returns (GaugeRootstockCollective gauge_) {
        return _communityApproveBuilder(builder_);
    }

    /**
     * @notice de-whitelist builder
     * @dev reverts if it is not called by the governor address or authorized changer
     * reverts if it does not have a gauge associated
     * reverts if it is not community approved
     * @param builder_ address of the builder
     */
    function dewhitelistBuilder(address builder_) external onlyValidChanger {
        /**
         *
         *         enum BuilderState {
         *             Inactive = 0
         *             CommunityApproved = 1
         *             KYCApproved = 2
         *             Active = 3
         *             Paused = 4
         *             DEAD = 5
         *         }
         *
         *         1 -> 5 CommunityApproved -> DEAD
         *         2 -> 5 KYCApproved -> DEAD
         *         3 -> 5 Active -> DEAD
         *         4 -> 5 Paused -> DEAD
         */
        BuilderState _state = builderState[builder_];
        if (_state == BuilderState.Inactive) revert StateMachineErrors.NoSuchTransition(_state, BuilderState.DEAD);

        GaugeRootstockCollective _gauge = builderToGauge[builder_];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist(); // FIXME: (buisiness logic) I'd argue that the community should be able to dewhitelist any address even before they enter the system

        _haltGauge(_gauge);
        backersManager.rewardTokenApprove(address(_gauge), 0);

        emit Blacklisted(builder_);
        builderState[builder_] = BuilderState.DEAD;
    }

    /**
     * @notice pause builder
     * @dev reverts if it is not called by the owner address
     * @param builder_ address of the builder
     * @param reason_ reason for the pause
     */
    function pauseBuilder(address builder_, bytes20 reason_) external onlyKycApprover {
        /**
         *
         *         enum BuilderState {
         *             Inactive = 0
         *             CommunityApproved = 1
         *             KYCApproved = 2
         *             Active = 3
         *             Paused = 4
         *             DEAD = 5
         *         }
         *
         *         2 -> 4 KYCApproved -> Paused
         *         3 -> 4 Active -> Paused
         */
        BuilderState _currentState = builderState[builder_];
        if (
            uint8(_currentState) != uint8(BuilderState.KYCApproved) ||
            uint8(_currentState) != uint8(BuilderState.Active)
        ) {
            revert StateMachineErrors.NoSuchTransition(_currentState, BuilderState.Paused);
        }
        builderState[builder_] = BuilderState.Paused;
        
        emit BuilderStateChanged(builder_, _currentState, BuilderState.Paused);
        emit Paused(builder_, reason_);
    }

    /**
     * @notice change the paused reason of a paused builder
     * @param builder_ address of the paused builder
     * @param reason_ the new reason for being paused
     *
     */
    function changePausedReason(address builder_, bytes20 reason_) external onlyKycApprover {
        require(uint8(builderState[builder_]) == uint8(BuilderState.Paused), "Builder not paused");
        emit Paused(builder_, reason_);
    }

    /**
     * @notice unpause builder
     * @dev reverts if it is not called by the owner address
     * reverts if it is not paused
     * @param builder_ address of the builder
     */
    function resumeBuilder(
        address builder_
    ) external onlyKycApprover transition(builder_, BuilderState.Paused, BuilderState.Active) {
        /**
         *
         *         enum BuilderState {
         *             Inactive = 0
         *             CommunityApproved = 1
         *             KYCApproved = 2
         *             Active = 3
         *             Paused = 4
         *             DEAD = 5
         *         }
         *
         *         4 -> 2 Paused -> KYCApproved
         *         4 -> 3 Paused -> Active
         */
        BuilderState _currentState = builderState[builder_];
        if (_currentState != BuilderState.Paused) {
            revert StateMachineErrors.NoSuchTransition(_currentState, BuilderState.Active);
        }

        GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) {
            builderState[builder_] = BuilderState.KYCApproved;
        } else {
            builderState[builder_] = BuilderState.Active;
        }
        
        emit BuilderStateChanged(builder_, _currentState, BuilderState.Paused);
        emit Unpaused(builder_); // could be not needed
    }

    /**
     * @notice unpause thyself
     * @dev reverts if it does not have a gauge associated
     *  reverts if it is executed in distribution period because changing the totalPotentialReward produce a
     * miscalculation of rewards
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function resumeReceivingRewards(uint64 rewardPercentage_) external {
        GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!isGaugeHalted(address(_gauge))) revert AlreadyReceivingRewards();

        if (backerRewardPercentage[msg.sender].cooldownEndTime == 0) {
            revert RewardsNotInitialized();
        }

        // TODO: should we have a minimal amount?
        if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
            revert InvalidBackerRewardPercentage();
        }

        // read from storage
        RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[msg.sender];

        _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
        _rewardPercentageData.next = rewardPercentage_;

        // write to storage
        backerRewardPercentage[msg.sender] = _rewardPercentageData;

        _resumeGauge(_gauge);

        emit ReceivingRewardsResumed(msg.sender, rewardPercentage_, _rewardPercentageData.cooldownEndTime);
    }

    /**
     * @notice pause thyself
     * @dev reverts if it does not have a gauge associated
     *  reverts if it is executed in distribution period because changing the totalPotentialReward produce a
     * miscalculation of rewards
     */
    function pauseReceivingRewards() external {
        GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (backerRewardPercentage[msg.sender].cooldownEndTime == 0) {
            revert RewardsNotInitialized();
        }

        // when opted-out builder wants to start receiving rewards again, they will set a new reward percentage.
        // So, the cooldown time starts here TODO: I don't get it. why do we need to set cooldownEndTime here?
        backerRewardPercentage[msg.sender].cooldownEndTime = uint128(block.timestamp + rewardPercentageCooldown);

        _haltGauge(_gauge);

        emit ReceivingRewardsPaused(msg.sender); // TODO: could be not needed
    }

    /**
     * @notice allows a builder to set his backers reward percentage
     * @dev reverts if builder is not operational
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function setBackerRewardPercentage(uint64 rewardPercentage_) external {
        if (!isBuilderOperational(msg.sender)) revert NotOperational();

        // TODO: should we have a minimal amount?
        if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
            revert InvalidBackerRewardPercentage();
        }

        // read from storage
        RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[msg.sender];

        _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
        _rewardPercentageData.next = rewardPercentage_;
        _rewardPercentageData.cooldownEndTime = uint128(block.timestamp) + rewardPercentageCooldown;

        emit BackerRewardPercentageUpdateScheduled(
            msg.sender,
            rewardPercentage_,
            _rewardPercentageData.cooldownEndTime
        );

        // write to storage
        backerRewardPercentage[msg.sender] = _rewardPercentageData;
    }

    /**
     * @notice migrate v1 builder to the new builder registry
     * @param builder_ address of the builder whitelisted on the V1's SimplifiedRewardDistributor contract
     * @param rewardAddress_ address of the builder reward receiver whitelisted on the V1's SimplifiedRewardDistributor
     * contract
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function migrateBuilder(address builder_, address rewardAddress_, uint64 rewardPercentage_) public onlyKycApprover {
        _communityApproveBuilder(builder_);
        _initializeRewardData(builder_, rewardAddress_, rewardPercentage_);

        emit BuilderMigrated(builder_, msg.sender);
    }

    /**
     * @notice returns reward percentage to apply.
     *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
     * @param builder_ address of the builder
     */
    function getRewardPercentageToApply(address builder_) public view returns (uint64) {
        RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[builder_];
        if (block.timestamp >= _rewardPercentageData.cooldownEndTime) {
            return _rewardPercentageData.next;
        }
        return _rewardPercentageData.previous;
    }

    /**
     * @notice return true if builder is operational
     *  kycApproved == true &&
     *  communityApproved == true &&
     *  paused == false
     */
    function isBuilderOperational(address builder_) public view returns (bool) {
        BuilderState _builderState = builderState[builder_];
        return _builderState > BuilderState.Inactive && _builderState < BuilderState.Paused;
    }

    /**
     * @dev could be removed with state machine
     * @notice return true if builder is paused
     */
    function isBuilderPaused(address builder_) public view returns (bool) {
        return builderState[builder_] == BuilderState.Paused;
    }

    /**
     * @notice return true if gauge is operational
     *  kycApproved == true &&
     *  communityApproved == true &&
     *  paused == false
     */
    function isGaugeOperational(GaugeRootstockCollective gauge_) public view returns (bool) {
        return isBuilderOperational(gaugeToBuilder[gauge_]);
    }

    /**
     * @notice get length of gauges array
     */
    function getGaugesLength() public view returns (uint256) {
        return _gauges.length();
    }

    /**
     * @notice get gauge from array at a given index
     */
    function getGaugeAt(uint256 index_) public view returns (address) {
        return _gauges.at(index_);
    }

    /**
     * @notice return true is gauge is rewarded
     */
    function isGaugeRewarded(address gauge_) public view returns (bool) {
        return _gauges.contains(gauge_);
    }

    /**
     * @notice get length of halted gauges array
     */
    function getHaltedGaugesLength() public view returns (uint256) {
        return _haltedGauges.length();
    }

    /**
     * @notice get halted gauge from array at a given index
     */
    function getHaltedGaugeAt(uint256 index_) public view returns (address) {
        return _haltedGauges.at(index_);
    }

    /**
     * @notice return true is gauge is halted
     */
    function isGaugeHalted(address gauge_) public view returns (bool) {
        return _haltedGauges.contains(gauge_);
    }

    /**
     * @notice reverts if builder was not activated or approved by the community
     */
    function requireInitializedRewards(GaugeRootstockCollective gauge_) external view onlyBackersManager {
        address _builder = gaugeToBuilder[gauge_];
        if (_builder == address(0)) revert GaugeDoesNotExist();
        if (builderState[_builder] != BuilderState.Active) revert RewardsNotInitialized();
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice creates a new gauge for a builder
     * @param builder_ builder address who can claim the rewards
     * @return gauge_ gauge contract
     */
    function _createGauge(address builder_) internal returns (GaugeRootstockCollective gauge_) {
        gauge_ = gaugeFactory.createGauge();
        builderToGauge[builder_] = gauge_;
        gaugeToBuilder[gauge_] = builder_;
        _gauges.add(address(gauge_));
        emit GaugeCreated(builder_, address(gauge_), msg.sender);
    }

    /**
     * @notice Builder submits a request to replace his rewardReceiver address,
     * the request will then need to be approved by `approveBuilderRewardReceiverReplacement`
     * @dev reverts if Builder is not Operational
     * @param newRewardReceiver_ new address the builder is requesting to use
     */
    function _submitRewardReceiverReplacementRequest(address newRewardReceiver_) internal {
        // Only builder can submit a reward receiver address replacement
        address _builder = msg.sender;
        // Only operational builder can initiate this action
        if (!isBuilderOperational(_builder)) revert NotOperational();
        builderRewardReceiverReplacement[_builder] = newRewardReceiver_;
    }

    /**
     * @notice halts a gauge moving it from the active array to the halted one
     * @param gauge_ gauge contract to be halted
     */
    function _haltGauge(GaugeRootstockCollective gauge_) internal {
        if (!isGaugeHalted(address(gauge_))) {
            _haltedGauges.add(address(gauge_));
            _gauges.remove(address(gauge_));
            backersManager.haltGaugeShares(gauge_);
        }
    }

    function _approveBuilderKYC(address builder_) internal {
        /**
         *
         *         enum BuilderState {
         *             Inactive = 0
         *             CommunityApproved = 1
         *             KYCApproved = 2
         *             Active = 3
         *             Paused = 4
         *             DEAD = 5
         *         }
         *
         *         0 -> 2 Inactive (fist-time & uninitialized & nogague) -> KYCApproved (initialized & nogague)
         *         0 -> 2 Inactive (reapproved & initialized  & nogague) -> KYCApproved (initialized & nogague)
         *         1 -> 3 CommunityApproved (fist-time & uninitialized & gague) -> Active
         *         1 -> 3 CommunityApproved (reapproved & initialized & nogague) -> Active
         */
        BuilderState _state = builderState[builder_];
        BuilderState _targetState = BuilderState(uint8(_state) + 2);

        if (uint8(_state) > uint8(BuilderState.CommunityApproved)) {
            revert StateMachineErrors.NoSuchTransition(_state, _targetState);
        }

        if (uint8(_state) == uint8(BuilderState.CommunityApproved)) {
            GaugeRootstockCollective _gauge = builderToGauge[builder_];
            if (address(builderToGauge[builder_]) != address(0)) {
                revert AlreadyCommunityApproved();
            }
            _resumeGauge(_gauge);
        }

        builderState[builder_] = _targetState;
        emit BuilderStateChanged(builder_, _state, _targetState);
    }

    /**
     * @notice resumes a gauge moving it from the halted array to the active one
     * @dev BackersManagerRootstockCollective override this function to restore its shares
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGauge(GaugeRootstockCollective gauge_) internal {
        _gauges.add(address(gauge_));
        _haltedGauges.remove(address(gauge_));
        backersManager.resumeGaugeShares(gauge_);
    }

    /**
     * @dev initializes the reward data for builder for the first time, setting
     *  - reward receiver
     *  - reward percentage
     *  - cooldown end time - this value is se to non-0 and should never be set to 0 again as it serves as a flag of builder initialisation as well as 0 cooldown end time has no meaning in real life
     * @dev reverts if reward percentage is greater than `_MAX_REWARD_PERCENTAGE`
     *  See {approveBuilderKYC} for details.
     */
    function _initializeRewardData(address builder_, address rewardReceiver_, uint64 rewardPercentage_) private {
        builderRewardReceiver[builder_] = rewardReceiver_;
        // TODO: should we have a minimal amount?
        if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
            revert InvalidBackerRewardPercentage();
        }

        // read from storage
        RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[builder_];

        _rewardPercentageData.previous = rewardPercentage_;
        _rewardPercentageData.next = rewardPercentage_;
        _rewardPercentageData.cooldownEndTime = uint128(block.timestamp);

        // write to storage
        backerRewardPercentage[builder_] = _rewardPercentageData;

        emit RewardsInitialized(builder_, rewardReceiver_, rewardPercentage_);
    }

    /**
     * @dev Internal function to community approve and create its gauge
     *  See {communityApproveBuilder} for details.
     */
    function _communityApproveBuilder(address builder_) private returns (GaugeRootstockCollective gauge_) {
        BuilderState _state = builderState[builder_];

        /**
         *
         *         enum BuilderState {
         *             Inactive = 0
         *             CommunityApproved = 1
         *             KYCApproved = 2
         *             Active = 3
         *             Paused = 4
         *             DEAD = 5
         *         }
         *
         *         0 -> 1 Inactive -> CommunityApproved
         *         2 -> 3 KYCApproved -> Active
         */
        BuilderState _targetState = BuilderState(uint8(_state) + 1);

        if (_state != BuilderState.Inactive || _state != BuilderState.KYCApproved) {
            revert StateMachineErrors.NoSuchTransition(_state, _targetState);
        }
        if (address(builderToGauge[builder_]) != address(0)) revert BuilderAlreadyExists();

        gauge_ = _createGauge(builder_);

        backersManager.rewardTokenApprove(address(gauge_), type(uint256).max);

        builderState[builder_] = _targetState;
        emit BuilderStateChanged(builder_, _state, _targetState);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
