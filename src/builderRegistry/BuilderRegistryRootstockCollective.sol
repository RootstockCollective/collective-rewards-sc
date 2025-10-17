// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsLib } from "../libraries/UtilsLib.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { BackersManagerRootstockCollective } from "../backersManager/BackersManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "../gauge/GaugeFactoryRootstockCollective.sol";
import { UpgradeableRootstockCollective } from "../governance/UpgradeableRootstockCollective.sol";

/**
 * @title BuilderRegistryRootstockCollective
 * @notice Keeps registers of the builders
 */
contract BuilderRegistryRootstockCollective is UpgradeableRootstockCollective {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant _MAX_REWARD_PERCENTAGE = UtilsLib._PRECISION;
    uint256 internal constant _MAX_BUILDERS = 1000;
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------

    error BuilderAlreadyKYCApproved();
    error BuilderAlreadyCommunityApproved();
    error BuilderAlreadySelfPaused();
    error NotActivated();
    error BuilderNotKYCApproved();
    error BuilderNotCommunityApproved();
    error BuilderNotKYCPaused();
    error BuilderNotSelfPaused();
    error BuilderNotOperational();
    error InvalidBackerRewardPercentage();
    error InvalidRewardReceiver();
    error BuilderAlreadyInitialized();
    error BuilderNotInitialized();
    error BuilderAlreadyExists();
    error BuilderDoesNotExist();
    error GaugeDoesNotExist();
    error NotAuthorized();
    error ZeroAddressNotAllowed();
    error BuilderRewardsLocked();
    error InvalidIndex();
    error InvalidMaxRewardPercentage();
    error MaxRewardPercentageTooLow();
    error MaxNumberOfBuildersReached();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderInitialized(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event CommunityApproved(address indexed builder_);
    event CommunityBanned(address indexed builder_);
    event KYCPaused(address indexed builder_, bytes20 reason_);
    event KYCResumed(address indexed builder_);
    event SelfPaused(address indexed builder_);
    event SelfResumed(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event BackerRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event RewardReceiverUpdateRequested(address indexed builder_, address newRewardReceiver_);
    event RewardReceiverUpdateCancelled(address indexed builder_, address newRewardReceiver_);
    event RewardReceiverUpdated(address indexed builder_, address newRewardReceiver_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
    event MaxRewardPercentageUpdated(uint256 oldMaxRewardPercentage_, uint256 newMaxRewardPercentage_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyKycApprover() {
        governanceManager.validateKycApprover(msg.sender);
        _;
    }

    modifier onlyUpgrader() {
        governanceManager.validateAuthorizedUpgrader(msg.sender);
        _;
    }

    modifier onlyBackersManager() {
        if (msg.sender != address(backersManager)) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyAuthorizedChanger() {
        governanceManager.validateAuthorizedChanger(msg.sender);
        _;
    }

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct BuilderState {
        bool initialized;
        bool kycApproved;
        bool communityApproved;
        bool kycPaused;
        bool selfPaused;
        bytes7 reserved; // for future upgrades
        bytes20 pausedReason;
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
    mapping(address builder => address rewardReceiver) public rewardReceiver;
    /// @notice map of builders reward receiver updates, used as a buffer until the new address is accepted
    mapping(address builder => address update) public rewardReceiverUpdate;
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
    /// @notice address of the BackersManagerRootstockCollective contract
    BackersManagerRootstockCollective public backersManager;
    /// @notice maximum allowed reward percentage for builders (configurable by governance)
    uint256 public maxRewardPercentage;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param backersManager_ address of the BackersManagerRootstockCollective contract
     * @param gaugeFactory_ address of the GaugeFactoryRootstockCollective contract
     * @param rewardDistributor_ address of the rewardDistributor contract
     * @param rewardPercentageCooldown_ time that must elapse for a new reward percentage from a builder to be applied
     */
    function initialize(
        BackersManagerRootstockCollective backersManager_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint128 rewardPercentageCooldown_
    )
        external
        initializer
    {
        if (address(backersManager_) == address(0)) revert ZeroAddressNotAllowed();
        if (gaugeFactory_ == address(0)) revert ZeroAddressNotAllowed();
        __Upgradeable_init(backersManager_.governanceManager());
        backersManager = backersManager_;
        gaugeFactory = GaugeFactoryRootstockCollective(gaugeFactory_);
        rewardDistributor = rewardDistributor_;
        rewardPercentageCooldown = rewardPercentageCooldown_;
        maxRewardPercentage = _MAX_REWARD_PERCENTAGE;
    }

    /**
     * @notice contract initializer
     * @param gaugeFactory_ address of the GaugeFactoryRootstockCollective contract
     * @dev used to upgrade the contract to V3
     *  TODO: After upgrading the live contracts to V3, this function can be deleted as the gaugeFactory can be set
     * directly in the initialize function
     */
    function initializeV3(GaugeFactoryRootstockCollective gaugeFactory_) external reinitializer(3) {
        gaugeFactory = gaugeFactory_;
        maxRewardPercentage = _MAX_REWARD_PERCENTAGE;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice Builder submits a request to update his rewardReceiver address,
     * the request will then need to be approved by `approveNewRewardReceiver`
     * @dev reverts if Builder is not Operational
     * @param newRewardReceiver_ new address the builder is requesting to use
     */
    function requestRewardReceiverUpdate(address newRewardReceiver_) external {
        _requestRewardReceiverUpdate(newRewardReceiver_);
        emit RewardReceiverUpdateRequested(msg.sender, newRewardReceiver_);
    }

    /**
     * @notice Builder cancels his request to update his rewardReceiver address
     * @dev reverts if Builder is not Operational
     */
    function cancelRewardReceiverUpdate() external {
        // By overriding the update, it effectively cancels the request
        address _currRewardReceiver = rewardReceiver[msg.sender];
        _requestRewardReceiverUpdate(_currRewardReceiver);
        emit RewardReceiverUpdateCancelled(msg.sender, _currRewardReceiver);
    }

    /**
     * @notice KYCApprover approves Builder request to update his rewardReceiver address
     * @dev reverts if provided `newRewardReceiver_` doesn't match Builder's request
     * @param builder_ address of the builder
     * @param newRewardReceiver_ new address the builder is requesting to use
     */
    function approveNewRewardReceiver(address builder_, address newRewardReceiver_) external onlyKycApprover {
        // Only an operational builder can be approved
        if (!isBuilderOperational(builder_)) revert BuilderNotOperational();

        address _newRewardReceiver = rewardReceiverUpdate[builder_];
        if (_newRewardReceiver != newRewardReceiver_) revert InvalidRewardReceiver();
        rewardReceiver[builder_] = _newRewardReceiver;
        emit RewardReceiverUpdated(builder_, newRewardReceiver_);
    }

    /**
     * @notice returns true if the builder has an open request to update his receiver address
     * @param builder_ address of the builder
     */
    function isRewardReceiverUpdatePending(address builder_) public view returns (bool) {
        return
            rewardReceiverUpdate[builder_] != address(0) && rewardReceiver[builder_] != rewardReceiverUpdate[builder_];
    }

    /**
     * @notice initializes builder, setting the reward receiver and the reward percentage
     *  Sets initialized flag to true. It cannot be switched to false anymore
     * @dev reverts if it is not called by the owner address
     * reverts if it is already initialized
     * @param builder_ address of the builder
     * @param rewardReceiver_ address of the builder reward receiver
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function initializeBuilder(address builder_, address rewardReceiver_, uint64 rewardPercentage_)
        external
        onlyKycApprover
    {
        _initializeBuilder(builder_, rewardReceiver_, rewardPercentage_);
    }

    /**
     * @notice approves builder's KYC after a revocation
     * @dev reverts if it is not called by the owner address
     * reverts if it is not initialized
     * reverts if it is already KYC approved
     * reverts if it does not have a gauge associated
     * @param builder_ address of the builder
     */
    function approveBuilderKYC(address builder_) external onlyKycApprover {
        GaugeRootstockCollective _gauge = builderToGauge[builder_];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (builderState[builder_].kycApproved) revert BuilderAlreadyKYCApproved();
        if (!builderState[builder_].initialized) revert BuilderNotInitialized();

        builderState[builder_].kycApproved = true;

        _resumeGauge(_gauge);

        emit KYCApproved(builder_);
    }

    /**
     * @notice revokes builder's KYC and sent builder unclaimed rewards to rewardDistributor contract
     * @dev reverts if it is not called by the owner address
     * reverts if it is not KYC approved
     * @param builder_ address of the builder
     */
    function revokeBuilderKYC(address builder_) external onlyKycApprover {
        if (!builderState[builder_].kycApproved) revert BuilderNotKYCApproved();

        builderState[builder_].kycApproved = false;

        GaugeRootstockCollective _gauge = builderToGauge[builder_];
        // if builder is community approved, it has a gauge associated
        if (address(_gauge) != address(0)) {
            _haltGauge(_gauge);
            _gauge.moveBuilderUnclaimedRewards(rewardDistributor);
        }

        emit KYCRevoked(builder_);
    }

    /**
     * @notice community approve builder and create its gauge
     * @dev reverts if it is not called by the governor or the authorized changer
     * reverts if is already community approved
     * reverts if it has a gauge associated
     * @param builder_ address of the builder
     * @return gauge_ gauge contract
     */
    function communityApproveBuilder(address builder_)
        external
        onlyValidChanger
        returns (GaugeRootstockCollective gauge_)
    {
        return _communityApproveBuilder(builder_);
    }

    /**
     * @notice community ban builder. This process is effectively irreversible, as community approval requires a gauge
     * to not exist fo given builder
     * @dev reverts if it is not called by the governor address or authorized changer
     * reverts if it does not have a gauge associated
     * reverts if it is not community approved
     * @param builder_ address of the builder
     */
    function communityBanBuilder(address builder_) external onlyValidChanger {
        _communityBanBuilder(builder_);
    }

    /**
     * @notice Removes a builder from the whitelist. This function is maintained for compatibility with the previous
     * naming convention
     * @dev reverts if it is not called by the governor address or authorized changer
     * reverts if it does not have a gauge associated
     * reverts if it is not community approved
     * Internally calls `_communityBanBuilder` to perform the operation.
     * @param builder_ address of the builder
     */
    function dewhitelistBuilder(address builder_) external onlyValidChanger {
        _communityBanBuilder(builder_);
    }

    /**
     * @notice pause builder KYC
     * @dev reverts if it is not called by the owner address
     * @param builder_ address of the builder
     * @param reason_ reason for the pause
     */
    function pauseBuilderKYC(address builder_, bytes20 reason_) external onlyKycApprover {
        // pause can be overwritten to change the reason
        builderState[builder_].kycPaused = true;
        builderState[builder_].pausedReason = reason_;
        emit KYCPaused(builder_, reason_);
    }

    /**
     * @notice unpause builder KYC
     * @dev reverts if it is not called by the owner address
     * reverts if it is not paused
     * @param builder_ address of the builder
     */
    function unpauseBuilderKYC(address builder_) external onlyKycApprover {
        if (!builderState[builder_].kycPaused) revert BuilderNotKYCPaused();

        builderState[builder_].kycPaused = false;
        builderState[builder_].pausedReason = "";

        emit KYCResumed(builder_);
    }

    /**
     * @notice Builder unpauses himself
     * @dev reverts if it does not have a gauge associated
     *  reverts if it is not KYC approved
     *  reverts if it is not community approved
     *  reverts if it is not self paused
     *  reverts if it is executed in distribution period because changing the totalPotentialReward produce a
     * miscalculation of rewards
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function unpauseSelf(uint64 rewardPercentage_) external {
        GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[msg.sender].kycApproved) revert BuilderNotKYCApproved();
        if (!builderState[msg.sender].communityApproved) revert BuilderNotCommunityApproved();
        if (!builderState[msg.sender].selfPaused) revert BuilderNotSelfPaused();

        if (rewardPercentage_ > maxRewardPercentage) {
            revert InvalidBackerRewardPercentage();
        }

        builderState[msg.sender].selfPaused = false;

        // read from storage
        RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[msg.sender];

        _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
        _rewardPercentageData.next = rewardPercentage_;

        // write to storage
        backerRewardPercentage[msg.sender] = _rewardPercentageData;

        _resumeGauge(_gauge);

        emit SelfResumed(msg.sender, rewardPercentage_, _rewardPercentageData.cooldownEndTime);
    }

    /**
     * @notice Builder pauses himself - this action will also halt the gauge
     * @dev reverts if caller does not have a gauge associated
     *  reverts if caller is not KYC approved
     *  reverts if caller is not community approved
     *  reverts if caller is already self paused
     *  reverts if caller is executed in distribution period because changing the totalPotentialReward produce a
     * miscalculation of rewards
     */
    function pauseSelf() external {
        GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[msg.sender].kycApproved) revert BuilderNotKYCApproved();
        if (!builderState[msg.sender].communityApproved) revert BuilderNotCommunityApproved();
        if (builderState[msg.sender].selfPaused) revert BuilderAlreadySelfPaused();

        builderState[msg.sender].selfPaused = true;
        // when self paused builder wants to come back, it can set a new reward percentage. So, the cooldown time starts
        // here
        backerRewardPercentage[msg.sender].cooldownEndTime = uint128(block.timestamp + rewardPercentageCooldown);

        _haltGauge(_gauge);

        emit SelfPaused(msg.sender);
    }

    /**
     * @notice allows a builder to set his backers reward percentage
     * @dev reverts if builder is not operational
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function setBackerRewardPercentage(uint64 rewardPercentage_) external {
        if (!isBuilderOperational(msg.sender)) revert BuilderNotOperational();

        if (rewardPercentage_ > maxRewardPercentage) {
            revert InvalidBackerRewardPercentage();
        }

        // read from storage
        RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[msg.sender];

        _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
        _rewardPercentageData.next = rewardPercentage_;
        _rewardPercentageData.cooldownEndTime = uint128(block.timestamp) + rewardPercentageCooldown;

        emit BackerRewardPercentageUpdateScheduled(msg.sender, rewardPercentage_, _rewardPercentageData.cooldownEndTime);

        // write to storage
        backerRewardPercentage[msg.sender] = _rewardPercentageData;
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
     * @notice returns the reward receiver address for a builder
     * @dev reverts if conditions for the builder to claim are not met
     * @param claimer_ address of the claimer
     */
    function canClaimBuilderReward(address claimer_) external view returns (address rewardReceiver_) {
        address _builder = gaugeToBuilder[GaugeRootstockCollective(msg.sender)];
        if (_builder == address(0)) revert BuilderDoesNotExist();
        rewardReceiver_ = rewardReceiver[_builder];
        if (isBuilderPaused(_builder)) revert BuilderRewardsLocked();
        if (claimer_ != _builder && claimer_ != rewardReceiver_) revert NotAuthorized();
        // if Builder uses the rewardReceiver account to claim, there shouldn't be an
        // open request to replace such address, they need to use the Builder account instead
        if (claimer_ == rewardReceiver_ && isRewardReceiverUpdatePending(_builder)) {
            revert NotAuthorized();
        }
    }

    /**
     * @notice Validates if a gauge is halted and can accept allocations
     * @dev This function first checks if the gauge is initialized and then checks if it is halted.
     *      Halted gauges can only have negative allocations (withdrawals) and are not considered for rewards.
     * @param gauge_ The gauge contract to check
     * @return bool True if the gauge is halted, false otherwise
     */
    function validateGaugeHalted(GaugeRootstockCollective gauge_) external view returns (bool) {
        requireInitializedBuilder(gauge_);
        return isGaugeHalted(address(gauge_));
    }

    /**
     * @notice return true if builder is operational
     *  kycApproved == true &&
     *  communityApproved == true &&
     *  paused == false
     */
    function isBuilderOperational(address builder_) public view returns (bool) {
        BuilderState memory _builderState = builderState[builder_];
        return _builderState.kycApproved && _builderState.communityApproved && !_builderState.kycPaused;
    }

    /**
     * @notice return true if builder is paused
     */
    function isBuilderPaused(address builder_) public view returns (bool) {
        return builderState[builder_].kycPaused;
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
     * @notice Get gauges in a specified range.
     * @param start_ The starting index (inclusive).
     * @param length_ The number of gauge addresses we want to retrieve.
     * @return gauges_ An array of gauge addresses within the specified range.
     */
    function getGaugesInRange(uint256 start_, uint256 length_) external view returns (address[] memory) {
        uint256 _total = _gauges.length();
        if (start_ >= _total) revert InvalidIndex();

        uint256 _actualLength = length_;
        if (start_ + length_ > _total) {
            _actualLength = _total - start_;
        }

        address[] memory _batch = new address[](_actualLength);
        for (uint256 i = 0; i < _actualLength; ++i) {
            _batch[i] = _gauges.at(start_ + i);
        }
        return _batch;
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
     * @notice get halted gauge by index
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
     * @notice Updates the maximum allowed reward percentage for builders
     * @dev Only callable by governor or authorized changer
     * @param maxRewardPercentage_ The maximum reward percentage (100% == 1 ether)
     */
    function updateMaxRewardPercentage(uint256 maxRewardPercentage_) external onlyAuthorizedChanger {
        if (maxRewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
            revert InvalidMaxRewardPercentage();
        }

        // Validate that the new max reward percentage is higher than all active builders' current reward percentages
        _validateMaxRewardPercentageAgainstActiveBuilders(maxRewardPercentage_);

        uint256 _oldMaxRewardPercentage = maxRewardPercentage;
        maxRewardPercentage = maxRewardPercentage_;

        emit MaxRewardPercentageUpdated(_oldMaxRewardPercentage, maxRewardPercentage_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice Validates that the new max reward percentage is higher or equal to all active builders' next reward
     * percentages
     * @dev Iterates through all operational gauges and checks their builders' reward percentages
     * @dev Also iterates through halted gauges and checks KYC-revoked builders (they can come back without changing
     * reward percentage)
     * @dev Self-paused builders are not checked since they must set a new reward percentage when unpausing
     * @param maxRewardPercentage_ The new maximum reward percentage to validate
     */
    function _validateMaxRewardPercentageAgainstActiveBuilders(uint256 maxRewardPercentage_) internal view {
        // Check all operational gauges
        uint256 _gaugesLength = _gauges.length();
        for (uint256 i = 0; i < _gaugesLength; ++i) {
            GaugeRootstockCollective _gauge = GaugeRootstockCollective(_gauges.at(i));
            address _builder = gaugeToBuilder[_gauge];
            // Only consider the next reward percentage since it's the one that will be applied after the cooldown
            RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[_builder];
            if (maxRewardPercentage_ < _rewardPercentageData.next) {
                revert MaxRewardPercentageTooLow();
            }
        }

        // Check halted gauges for builders that can resume without changing their reward percentage
        uint256 _haltedGaugesLength = _haltedGauges.length();
        for (uint256 i = 0; i < _haltedGaugesLength; ++i) {
            GaugeRootstockCollective _gauge = GaugeRootstockCollective(_haltedGauges.at(i));
            address _builder = gaugeToBuilder[_gauge];
            BuilderState memory _builderState = builderState[_builder];

            // Only check KYC-revoked builders (they can resume via approveBuilderKYC without changing reward %)
            // Consider builders that can be resumed without changing reward %
            // Skip self-paused builders (they must set new reward % when calling unpauseSelf)
            if (!_builderState.kycApproved && _builderState.communityApproved && !_builderState.selfPaused) {
                RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[_builder];
                if (maxRewardPercentage_ < _rewardPercentageData.next) {
                    revert MaxRewardPercentageTooLow();
                }
            }
        }
    }

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
     * @notice Builder submits a request to update his rewardReceiver address,
     * the request will then need to be approved by `approveNewRewardReceiver`
     * @dev reverts if Builder is not Operational
     * @param newRewardReceiver_ new address the builder is requesting to use
     */
    function _requestRewardReceiverUpdate(address newRewardReceiver_) internal {
        // Only builder can submit a reward receiver address replacement
        address _builder = msg.sender;
        // Only operational builder can initiate this action
        if (!isBuilderOperational(_builder)) revert BuilderNotOperational();
        rewardReceiverUpdate[_builder] = newRewardReceiver_;
    }

    /**
     * @notice Ensures the builder associated with the given gauge exists and builder is initialized
     * @dev Reverts if the builder gauge does not exist or if the builder is not initialized.
     * @dev reverts if it is not called by the backers manager
     * @param gauge_ The gauge to validate.
     */
    function requireInitializedBuilder(GaugeRootstockCollective gauge_) public view {
        address _builder = gaugeToBuilder[gauge_];
        if (_builder == address(0)) revert GaugeDoesNotExist();
        if (!builderState[_builder].initialized) revert BuilderNotInitialized();
    }

    /**
     * @notice halts a gauge moving it from the active array to the halted one
     * @param gauge_ gauge contract to be halted
     */
    function _haltGauge(GaugeRootstockCollective gauge_) internal {
        if (!isGaugeHalted(address(gauge_))) {
            _haltedGauges.add(address(gauge_));
            _gauges.remove(address(gauge_));
            haltedGaugeLastPeriodFinish[gauge_] = backersManager.haltGaugeShares(gauge_);
        }
    }

    /**
     * @notice resumes a gauge moving it from the halted array to the active one
     * @dev BackersManagerRootstockCollective override this function to restore its shares
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGauge(GaugeRootstockCollective gauge_) internal {
        if (_canBeResumed(gauge_)) {
            _gauges.add(address(gauge_));
            _haltedGauges.remove(address(gauge_));
            backersManager.resumeGaugeShares(gauge_, haltedGaugeLastPeriodFinish[gauge_]);
            haltedGaugeLastPeriodFinish[gauge_] = 0;
        }
    }

    /**
     * @notice returns true if gauge can be resumed
     * @dev kycApproved == true &&
     *  communityApproved == true &&
     *  selfPaused == false
     * @param gauge_ gauge contract to be resumed
     */
    function _canBeResumed(GaugeRootstockCollective gauge_) internal view returns (bool) {
        BuilderState memory _builderState = builderState[gaugeToBuilder[gauge_]];
        return _builderState.kycApproved && _builderState.communityApproved && !_builderState.selfPaused;
    }

    /**
     * @dev Initializes builder for the first time, setting the reward receiver and the reward percentage
     * @dev reverts if max number of builders is reached
     *  Sets initialized flag to true. It cannot be switched to false anymore
     *  See {initializeBuilder} for details.
     */
    function _initializeBuilder(address builder_, address rewardReceiver_, uint64 rewardPercentage_) private {
        if (builderState[builder_].initialized) revert BuilderAlreadyInitialized();
        if (_gauges.length() + _haltedGauges.length() >= _MAX_BUILDERS) revert MaxNumberOfBuildersReached();

        builderState[builder_].initialized = true;
        builderState[builder_].kycApproved = true;
        rewardReceiver[builder_] = rewardReceiver_;
        // TODO: should we have a minimal amount?
        if (rewardPercentage_ > maxRewardPercentage) {
            revert InvalidBackerRewardPercentage();
        }

        // read from storage
        RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[builder_];

        _rewardPercentageData.previous = rewardPercentage_;
        _rewardPercentageData.next = rewardPercentage_;
        _rewardPercentageData.cooldownEndTime = uint128(block.timestamp);

        // write to storage
        backerRewardPercentage[builder_] = _rewardPercentageData;

        emit BuilderInitialized(builder_, rewardReceiver_, rewardPercentage_);
    }

    /**
     * @dev Internal function to community approve and create its gauge
     *  See {communityApproveBuilder} for details.
     */
    function _communityApproveBuilder(address builder_) private returns (GaugeRootstockCollective gauge_) {
        if (builderState[builder_].communityApproved) revert BuilderAlreadyCommunityApproved();
        if (address(builderToGauge[builder_]) != address(0)) revert BuilderAlreadyExists();

        builderState[builder_].communityApproved = true;
        gauge_ = _createGauge(builder_);

        backersManager.rewardTokensApprove(address(gauge_), type(uint256).max);

        emit CommunityApproved(builder_);
    }

    /**
     * @dev Internal function to community ban and halt its gauge
     *  See {communityBanBuilder} for details.
     */
    function _communityBanBuilder(address builder_) private {
        GaugeRootstockCollective _gauge = builderToGauge[builder_];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[builder_].communityApproved) revert BuilderNotCommunityApproved();

        builderState[builder_].communityApproved = false;

        _haltGauge(_gauge);
        backersManager.rewardTokensApprove(address(_gauge), 0);

        emit CommunityBanned(builder_);
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
