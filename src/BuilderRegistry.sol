// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Upgradeable } from "./governance/Upgradeable.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { GaugeFactory } from "./gauge/GaugeFactory.sol";

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 */
abstract contract BuilderRegistry is Upgradeable, Ownable2StepUpgradeable {
    uint256 internal constant _MAX_KICKBACK = UtilsLib._PRECISION;
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------

    error AlreadyKYCApproved();
    error AlreadyWhitelisted();
    error AlreadyPaused();
    error NotPaused();
    error NotRevoked();
    error CannotRevoke();
    error NotAuthorized();
    error NotOperational();
    error InvalidBuilderKickback();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event KYCApproved(address indexed builder_);
    event Whitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes29 reason_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_);
    event BuilderKickbackUpdateScheduled(address indexed builder_, uint256 kickback_, uint256 cooldown_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct BuilderState {
        bool kycApproved;
        bool whitelisted;
        bool paused;
        bytes29 pausedReason;
    }

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct KickbackData {
        // previous kickback
        uint64 previous;
        // latest kickback
        uint64 latest;
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
    /// @notice array of all the gauges created
    Gauge[] public gauges;
    /// @notice gauge factory contract address
    GaugeFactory public gaugeFactory;
    /// @notice gauge contract for a builder
    mapping(address builder => Gauge gauge) public builderToGauge;
    /// @notice builder address for a gauge contract
    mapping(Gauge gauge => address builder) public gaugeToBuilder;
    /// @notice time that must elapse for a new kickback from a builder to be applied
    uint256 public kickbackCooldown;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param changeExecutor_ See Governed doc
     * @param kycApprover_ account responsible of approving Builder's Know you Costumer policies and Legal requirements
     * @param gaugeFactory_ address of the GaugeFactory contract
     * @param kickbackCooldown_ time that must elapse for a new kickback from a builder to be applied
     */
    function __BuilderRegistry_init(
        address changeExecutor_,
        address kycApprover_,
        address gaugeFactory_,
        uint256 kickbackCooldown_
    )
        internal
        onlyInitializing
    {
        __Upgradeable_init(changeExecutor_);
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
        _kickbackData.latest = kickback_;
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
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Whitelisted
     * reverts trying to revoke
     * @param builder_ address of the builder
     * @param reason_ reason for the pause
     */
    function pauseBuilder(address builder_, bytes29 reason_) external onlyGovernorOrAuthorizedChanger {
        if (reason_ == "Revoked") revert CannotRevoke();
        // pause can be overwritten to change the reason
        builderState[builder_].paused = true;
        builderState[builder_].pausedReason = reason_;
        emit Paused(builder_, reason_);
    }

    /**
     * @notice permit builder
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Revoked
     * @param builder_ address of the builder
     */
    function permitBuilder(address builder_) external {
        if (msg.sender != builder_) revert NotAuthorized();
        if (builderState[builder_].pausedReason != "Revoked") revert NotRevoked();

        builderState[builder_].paused = false;
        builderState[builder_].pausedReason = "";
        emit Permitted(builder_);
    }

    /**
     * @notice revoke builder
     * @dev reverts if is not called by the builder address
     * reverts if builder state is not Whitelisted
     * @param builder_ address of the builder
     */
    function revokeBuilder(address builder_) external {
        if (msg.sender != builder_) revert NotAuthorized();
        if (builderState[builder_].paused == true) revert AlreadyPaused();

        builderState[builder_].paused = true;
        builderState[builder_].pausedReason = "Revoked";
        emit Revoked(builder_);
    }

    /**
     * @notice set a builder kickback
     * @dev reverts if is not called by the builder
     * reverts if builder is not operational
     * @param builder_ address of the builder
     * @param kickback_ kickback(100% == 1 ether)
     */
    function setBuilderKickback(address builder_, uint64 kickback_) external {
        if (msg.sender != builder_) revert NotAuthorized();
        if (isBuilderOperational(builder_) == false) revert NotOperational();

        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        KickbackData storage _kickbackData = builderKickback[builder_];
        _kickbackData.previous = getKickbackToApply(builder_);
        _kickbackData.latest = kickback_;
        _kickbackData.cooldownEndTime = uint128(block.timestamp + kickbackCooldown);

        emit BuilderKickbackUpdateScheduled(builder_, kickback_, _kickbackData.cooldownEndTime);
    }

    /**
     * @notice returns kickback to apply.
     *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
     * @param builder_ address of the builder
     */
    function getKickbackToApply(address builder_) public view returns (uint64) {
        KickbackData memory _kickbackData = builderKickback[builder_];
        if (block.timestamp >= _kickbackData.cooldownEndTime) {
            return _kickbackData.latest;
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
        gauges.push(gauge_);
        emit GaugeCreated(builder_, address(gauge_), msg.sender);
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
