// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Governed } from "./governance/Governed.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 */
contract BuilderRegistry is Governed, Ownable2StepUpgradeable {
    uint256 internal constant MAX_KICKBACK = UtilsLib.PRECISION;
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------

    error NotAuthorized();
    error InvalidBuilderKickback();
    error RequiredState(BuilderState state);

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdated(address indexed builder_, BuilderState previousState_, BuilderState newState_);
    event BuilderKickbackUpdated(address indexed builder_, uint256 builderKickback_);

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

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param changeExecutor_ See Governed doc
     * @param kycApprover_ account responsible of approving Builder's Know you Costumer policies and Legal requirements
     */
    function initialize(address changeExecutor_, address kycApprover_) external initializer {
        __Governed_init(changeExecutor_);
        __Ownable2Step_init();
        __Ownable_init(kycApprover_);
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
     * @param builderKickback_ kickback(100% == 1 ether)
     */
    function activateBuilder(
        address builder_,
        address rewardReceiver_,
        uint256 builderKickback_
    )
        external
        onlyOwner
        atState(builder_, BuilderState.Pending)
    {
        builderRewardReceiver[builder_] = rewardReceiver_;
        _setBuilderKickback(builder_, builderKickback_);

        _updateState(builder_, BuilderState.KYCApproved);
    }

    /**
     * @notice whitelist builder
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not KYCApproved
     * @param builder_ address of the builder
     */
    function whitelistBuilder(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.KYCApproved)
    {
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
     * @notice set builder kickback
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Whitelisted
     * @param builder_ address of the builder
     * @param builderKickback_ kickback(100% == 1 ether)
     */
    function setBuilderKickback(
        address builder_,
        uint256 builderKickback_
    )
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.Whitelisted)
    {
        _setBuilderKickback(builder_, builderKickback_);
    }

    // -----------------------------
    // ---- Public Functions -----
    // -----------------------------

    /**
     * @notice get builder state
     * @param builder_ address of the builder
     */
    function getState(address builder_) public view returns (BuilderState) {
        return builderState[builder_];
    }

    /**
     * @notice get builder reward receiver
     * @param builder_ address of the builder
     */
    function getRewardReceiver(address builder_) public view returns (address) {
        return builderRewardReceiver[builder_];
    }

    /**
     * @notice get builder kickback
     * @param builder_ address of the builder
     */
    function getBuilderKickback(address builder_) public view returns (uint256) {
        return builderKickback[builder_];
    }

    /**
     * @notice apply builder kickback
     * @param builder_ address of the builder
     * @param amount_ amount to apply the kickback
     */
    function applyBuilderKickback(address builder_, uint256 amount_) public view returns (uint256) {
        // [N] = [N] * [PREC] / [PREC]
        return builderKickback[builder_] * amount_ / UtilsLib.PRECISION;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    function _setBuilderKickback(address builder_, uint256 builderKickback_) internal {
        // TODO: should we have a minimal amount?
        if (builderKickback_ > MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }
        builderKickback[builder_] = builderKickback_;

        emit BuilderKickbackUpdated(builder_, builderKickback_);
    }

    function _updateState(address builder_, BuilderState newState_) internal {
        BuilderState previousState_ = builderState[builder_];
        builderState[builder_] = newState_;
        emit StateUpdated(builder_, previousState_, newState_);
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
