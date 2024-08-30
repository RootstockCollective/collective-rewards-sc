// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Upgradeable } from "./governance/Upgradeable.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { GaugeFactory } from "./gauge/GaugeFactory.sol";
import { EpochLib } from "./libraries/EpochLib.sol";

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 */
abstract contract BuilderRegistry is Upgradeable, Ownable2StepUpgradeable {
    uint256 internal constant _MAX_KICKBACK = UtilsLib._PRECISION;
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------

    error NotAuthorized();
    error InvalidBuilderKickback();
    error RequiredState(BuilderState state_);

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);
    event BuilderKickbackRequested(address indexed builder_, uint256 kickback_, uint256 timeExpiration_);
    event BuilderKickbackUpdated(address indexed builder_, uint256 kickback_, uint256 timeExpiration_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier atState(address builder_, BuilderState previousState_) {
        if (builderState[builder_] != previousState_) revert RequiredState(previousState_);
        _;
    }

    // -----------------------------
    // ---------- Enums ----------
    // -----------------------------
    enum BuilderState {
        Pending,
        KYCApproved,
        Whitelisted,
        Paused,
        Revoked
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------
    /// @notice map of builders state
    mapping(address builder => BuilderState state) public builderState;
    /// @notice map of builders reward receiver
    mapping(address builder => address rewardReceiver) public builderRewardReceiver;
    /// @notice map of builders kickback
    mapping(address builder => uint256 percentage) public builderKickback;
    /// @notice map of builders kickback that will be applied in the new epoch
    mapping(address builder => uint256 percentage) public newBuilderKickback;
    /// @notice map of builders kickback expiration. After this time, builder can update the kicback without a changer
    mapping(address builder => uint256 timestamp) public builderKickbackExpiration;
    /// @notice array of all the gauges created
    Gauge[] public gauges;
    /// @notice gauge factory contract address
    GaugeFactory public gaugeFactory;
    /// @notice gauge contract for a builder
    mapping(address builder => Gauge gauge) public builderToGauge;
    /// @notice builder address for a gauge contract
    mapping(Gauge gauge => address builder) public gaugeToBuilder;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param changeExecutor_ See Governed doc
     * @param kycApprover_ account responsible of approving Builder's Know you Costumer policies and Legal requirements
     * @param gaugeFactory_ address of the GaugeFactory contract
     */
    function __BuilderRegistry_init(
        address changeExecutor_,
        address kycApprover_,
        address gaugeFactory_
    )
        internal
        onlyInitializing
    {
        __Upgradeable_init(changeExecutor_);
        __Ownable2Step_init();
        __Ownable_init(kycApprover_);
        gaugeFactory = GaugeFactory(gaugeFactory_);
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
     * @param kickbackTimeLock_ time where kicback cannot be changed without a changer
     */
    function activateBuilder(
        address builder_,
        address rewardReceiver_,
        uint256 kickback_,
        uint256 kickbackTimeLock_
    )
        external
        onlyOwner
        atState(builder_, BuilderState.Pending)
    {
        builderRewardReceiver[builder_] = rewardReceiver_;

        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        builderKickback[builder_] = kickback_;
        newBuilderKickback[builder_] = kickback_;
        builderKickbackExpiration[builder_] = block.timestamp + kickbackTimeLock_;

        _updateState(builder_, BuilderState.KYCApproved);
    }

    /**
     * @notice whitelist builder and create its gauge
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not KYCApproved
     * @param builder_ address of the builder
     * @return gauge_ gauge contract
     */
    function whitelistBuilder(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.KYCApproved)
        returns (Gauge gauge_)
    {
        gauge_ = _createGauge(builder_);
        _updateState(builder_, BuilderState.Whitelisted);
    }

    /**
     * @notice pause builder
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Whitelisted
     * @param builder_ address of the builder
     */
    function pauseBuilder(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.Whitelisted)
    {
        _updateState(builder_, BuilderState.Paused);
    }

    /**
     * @notice permit builder
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Revoked
     * @param builder_ address of the builder
     */
    function permitBuilder(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.Revoked)
    {
        _updateState(builder_, BuilderState.Whitelisted);
    }

    /**
     * @notice revoke builder
     * @dev reverts if is not called by the builder address
     * reverts if builder state is not Whitelisted
     * @param builder_ address of the builder
     */
    function revokeBuilder(address builder_) external atState(builder_, BuilderState.Whitelisted) {
        if (msg.sender != builder_) revert NotAuthorized();

        _updateState(builder_, BuilderState.Revoked);
    }

    /**
     * @notice set a builder kickback
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Whitelisted
     * @param builder_ address of the builder
     * @param kickback_ kickback(100% == 1 ether)
     * @param kickbackTimeLock_ time where kicback cannot be changed without a changer
     */
    function setBuilderKickback(
        address builder_,
        uint256 kickback_,
        uint256 kickbackTimeLock_
    )
        external
        atState(builder_, BuilderState.Whitelisted)
    {
        // builder can change the kickback when the time lock expires
        if (msg.sender != builder_ || block.timestamp < builderKickbackExpiration[builder_]) {
            _checkIfGovernorOrAuthorizedChanger();
        }

        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        // new kickback will be applied in the next epoch
        newBuilderKickback[builder_] = kickback_;
        builderKickbackExpiration[builder_] = EpochLib._epochNext(block.timestamp) + kickbackTimeLock_;

        emit BuilderKickbackRequested(builder_, kickback_, builderKickbackExpiration[builder_]);
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
     * @notice applies new builder kickback if it is different
     * @param builder_ address of the builder
     */
    function _applyNewBuilderKickback(address builder_) internal {
        if (newBuilderKickback[builder_] != builderKickback[builder_]) {
            builderKickback[builder_] = newBuilderKickback[builder_];
            emit BuilderKickbackUpdated(builder_, builderKickback[builder_], builderKickbackExpiration[builder_]);
        }
    }

    function _updateState(address builder_, BuilderState newState_) internal {
        BuilderState _previousState = builderState[builder_];
        builderState[builder_] = newState_;
        emit StateUpdate(builder_, _previousState, newState_);
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
