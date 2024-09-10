// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { EpochTimeKeeper } from "./EpochTimeKeeper.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { GaugeFactory } from "./gauge/GaugeFactory.sol";

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 */
abstract contract BuilderRegistry is EpochTimeKeeper, Ownable2StepUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant _MAX_KICKBACK = UtilsLib._PRECISION;
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------

    error AlreadyKYCApproved();
    error AlreadyWhitelisted();
    error AlreadyRevoked();
    error NotPaused();
    error NotRevoked();
    error IsRevoked();
    error CannotRevoke();
    error NotOperational();
    error InvalidBuilderKickback();
    error BuilderDoesNotExist();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event KYCApproved(address indexed builder_);
    event Whitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Unpaused(address indexed builder_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_, uint256 kickback_, uint256 cooldown_);
    event BuilderKickbackUpdateScheduled(address indexed builder_, uint256 kickback_, uint256 cooldown_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct BuilderState {
        bool kycApproved;
        bool whitelisted;
        bool paused;
        bool revoked;
        bytes8 reserved; // for future upgrades
        bytes20 pausedReason;
    }

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct KickbackData {
        // previous kickback
        uint64 previous;
        // next kickback
        uint64 next;
        // kickback cooldown end time. After this time, new kickback will be applied
        uint128 cooldownEndTime;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------
    /// @notice map of builders state
    mapping(address builder => BuilderState state) public builderState;
    /// @notice map of builders reward receiver
    mapping(address builder => address rewardReceiver) public builderRewardReceiver;
    /// @notice map of builders kickback data
    mapping(address builder => KickbackData kickbackData) public builderKickback;
    /// @notice array of all the operational gauges
    EnumerableSet.AddressSet internal _gauges;
    /// @notice array of all the halted gauges
    EnumerableSet.AddressSet internal _haltedGauges;
    /// @notice gauge factory contract address
    GaugeFactory public gaugeFactory;
    /// @notice gauge contract for a builder
    mapping(address builder => Gauge gauge) public builderToGauge;
    /// @notice builder address for a gauge contract
    mapping(Gauge gauge => address builder) public gaugeToBuilder;
    /// @notice map of last period finish for halted gauges
    mapping(Gauge gauge => uint256 lastPeriodFinish) public haltedGaugeLastPeriodFinish;
    /// @notice time that must elapse for a new kickback from a builder to be applied
    uint128 public kickbackCooldown;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param changeExecutor_ See Governed doc
     * @param kycApprover_ account responsible of approving Builder's Know you Costumer policies and Legal requirements
     * @param gaugeFactory_ address of the GaugeFactory contract
     * @param epochDuration_ epoch time duration
     * @param kickbackCooldown_ time that must elapse for a new kickback from a builder to be applied
     */
    function __BuilderRegistry_init(
        address changeExecutor_,
        address kycApprover_,
        address gaugeFactory_,
        uint64 epochDuration_,
        uint128 kickbackCooldown_
    )
        internal
        onlyInitializing
    {
        __EpochTimeKeeper_init(changeExecutor_, epochDuration_);
        __Ownable2Step_init();
        __Ownable_init(kycApprover_);
        gaugeFactory = GaugeFactory(gaugeFactory_);
        kickbackCooldown = kickbackCooldown_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice activates builder and set reward receiver
     * @dev reverts if is not called by the owner address
     * reverts if builder state is not pending
     * @param builder_ address of the builder
     * @param rewardReceiver_ address of the builder reward receiver
     * @param kickback_ kickback(100% == 1 ether)
     */
    function activateBuilder(address builder_, address rewardReceiver_, uint64 kickback_) external onlyOwner {
        if (builderState[builder_].kycApproved == true) revert AlreadyKYCApproved();

        builderState[builder_].kycApproved = true;
        builderRewardReceiver[builder_] = rewardReceiver_;
        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }
        KickbackData storage _kickbackData = builderKickback[builder_];
        _kickbackData.previous = kickback_;
        _kickbackData.next = kickback_;
        _kickbackData.cooldownEndTime = uint128(block.timestamp);
        emit KYCApproved(builder_);
    }

    /**
     * @notice whitelist builder and create its gauge
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not KYCApproved
     * @param builder_ address of the builder
     * @return gauge_ gauge contract
     */
    function whitelistBuilder(address builder_) external onlyGovernorOrAuthorizedChanger returns (Gauge gauge_) {
        if (builderState[builder_].whitelisted == true) revert AlreadyWhitelisted();

        builderState[builder_].whitelisted = true;
        gauge_ = _createGauge(builder_);
        emit Whitelisted(builder_);
    }

    /**
     * @notice pause builder
     * @dev reverts if is not called by the owner address
     * @param builder_ address of the builder
     * @param reason_ reason for the pause
     */
    function pauseBuilder(address builder_, bytes20 reason_) external onlyOwner {
        // pause can be overwritten to change the reason
        builderState[builder_].paused = true;
        builderState[builder_].pausedReason = reason_;
        emit Paused(builder_, reason_);
    }

    /**
     * @notice unpause builder
     * @dev reverts if is not called by the owner address
     * reverts if builder state is not paused
     * @param builder_ address of the builder
     */
    function unpauseBuilder(address builder_) external onlyOwner {
        if (builderState[builder_].paused == false) revert NotPaused();

        builderState[builder_].paused = false;
        builderState[builder_].pausedReason = "";

        emit Unpaused(builder_);
    }

    /**
     * @notice permit builder
     * @dev reverts if builder state is not Revoked
     * @param kickback_ kickback(100% == 1 ether)
     */
    function permitBuilder(uint64 kickback_) external {
        Gauge _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (builderState[msg.sender].revoked == false) revert NotRevoked();

        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        builderState[msg.sender].revoked = false;

        KickbackData memory _kickbackData = builderKickback[msg.sender];
        _kickbackData.previous = getKickbackToApply(msg.sender);
        _kickbackData.next = kickback_;
        builderKickback[msg.sender] = _kickbackData;

        _resumeGauge(_gauge);

        emit Permitted(msg.sender, kickback_, _kickbackData.cooldownEndTime);
    }

    /**
     * @notice revoke builder
     * @dev reverts if builder is already revoked
     */
    function revokeBuilder() external {
        Gauge _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (builderState[msg.sender].revoked == true) revert AlreadyRevoked();

        builderState[msg.sender].revoked = true;
        // when revoked builder wants to come back, it can set a new kickback. So, the cooldown time starts here
        builderKickback[msg.sender].cooldownEndTime = uint128(block.timestamp + kickbackCooldown);
        _haltGauge(_gauge);

        emit Revoked(msg.sender);
    }

    /**
     * @notice set a builder kickback
     * @dev reverts if builder is not operational
     * @param kickback_ kickback(100% == 1 ether)
     */
    function setBuilderKickback(uint64 kickback_) external {
        if (isBuilderOperational(msg.sender) == false) revert NotOperational();

        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        KickbackData storage _kickbackData = builderKickback[msg.sender];
        _kickbackData.previous = getKickbackToApply(msg.sender);
        _kickbackData.next = kickback_;
        _kickbackData.cooldownEndTime = uint128(block.timestamp) + kickbackCooldown;

        emit BuilderKickbackUpdateScheduled(msg.sender, kickback_, _kickbackData.cooldownEndTime);
    }

    /**
     * @notice returns kickback to apply.
     *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
     * @param builder_ address of the builder
     */
    function getKickbackToApply(address builder_) public view returns (uint64) {
        KickbackData memory _kickbackData = builderKickback[builder_];
        if (block.timestamp >= _kickbackData.cooldownEndTime) {
            return _kickbackData.next;
        }
        return _kickbackData.previous;
    }

    /**
     * @notice return true if builder is operational
     *  kycApproved == true &&
     *  whitelisted == true &&
     *  paused == false
     */
    function isBuilderOperational(address builder_) public view returns (bool) {
        BuilderState memory _builderState = builderState[builder_];
        return _builderState.kycApproved && _builderState.whitelisted && !_builderState.paused;
    }

    /**
     * @notice return true if gauge is operational
     *  kycApproved == true &&
     *  whitelisted == true &&
     *  paused == false
     */
    function isGaugeOperational(Gauge gauge_) public view returns (bool) {
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

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice creates a new gauge for a builder
     * @param builder_ builder address who can claim the rewards
     * @return gauge_ gauge contract
     */
    function _createGauge(address builder_) internal returns (Gauge gauge_) {
        gauge_ = gaugeFactory.createGauge();
        builderToGauge[builder_] = gauge_;
        gaugeToBuilder[gauge_] = builder_;
        _gauges.add(address(gauge_));
        emit GaugeCreated(builder_, address(gauge_), msg.sender);
    }

    /**
     * @notice halts a gauge moving it from the active array to the halted one
     * @dev SponsorsManager override this function to remove its shares
     * @param gauge_ gauge contract to be halted
     */
    function _haltGauge(Gauge gauge_) internal virtual {
        _haltedGauges.add(address(gauge_));
        _gauges.remove(address(gauge_));
    }

    /**
     * @notice resumes a gauge moving it from the halted array to the active one
     * @dev SponsorsManager override this function to restore its shares
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGauge(Gauge gauge_) internal virtual {
        _gauges.add(address(gauge_));
        _haltedGauges.remove(address(gauge_));
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
