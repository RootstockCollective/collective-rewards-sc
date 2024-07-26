// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Governed } from "./governance/Governed.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 * @custom:oz-upgrades
 */
contract BuilderRegistry is Governed, Ownable2StepUpgradeable {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotAuthorized();
    error InvalidBuilderKickbackPct();
    error RequiredState(BuilderState state);

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);
    event BuilderKickbackPctUpdate(address indexed builder_, uint256 builderKickbackPct_);

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

    /// @notice map of builders kickback percentage
    mapping(address builder => uint256 percentage) public builderKickbackPct;

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
     * @param builder_ address of builder
     * @param rewardReceiver_ address of the builder reward receiver
     * @param builderKickbackPct_ kickback percentage(100% == 1 ether)
     */
    function activateBuilder(
        address builder_,
        address rewardReceiver_,
        uint256 builderKickbackPct_
    )
        external
        onlyOwner
        atState(builder_, BuilderState.Pending)
    {
        builderState[builder_] = BuilderState.KYCApproved;
        builderRewardReceiver[builder_] = rewardReceiver_;
        _setBuilderKickbackPct(builder_, builderKickbackPct_);

        emit StateUpdate(builder_, BuilderState.Pending, BuilderState.KYCApproved);
    }

    /**
     * @notice whitelist builder
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not KYCApproved
     * @param builder_ address of builder
     */
    function whitelistBuilder(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.KYCApproved)
    {
        builderState[builder_] = BuilderState.Whitelisted;

        emit StateUpdate(builder_, BuilderState.KYCApproved, BuilderState.Whitelisted);
    }

    /**
     * @notice pause builder
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Whitelisted
     * @param builder_ address of builder
     */
    function pauseBuilder(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.Whitelisted)
    {
        builderState[builder_] = BuilderState.Paused;

        emit StateUpdate(builder_, BuilderState.Whitelisted, BuilderState.Paused);
    }

    /**
     * @notice permit builder
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Revoked
     * @param builder_ address of builder
     */
    function permitBuilder(address builder_)
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.Revoked)
    {
        builderState[builder_] = BuilderState.Whitelisted;

        emit StateUpdate(builder_, BuilderState.Revoked, BuilderState.Whitelisted);
    }

    /**
     * @notice revoke builder
     * @dev reverts if is not called by the builder address
     * reverts if builder state is not Whitelisted
     * @param builder_ address of builder
     */
    function revokeBuilder(address builder_) external atState(builder_, BuilderState.Whitelisted) {
        if (msg.sender != builder_) revert NotAuthorized();

        builderState[builder_] = BuilderState.Revoked;

        emit StateUpdate(builder_, BuilderState.Whitelisted, BuilderState.Revoked);
    }

    /**
     * @notice set builder kickback percentage
     * @dev reverts if is not called by the governor address or authorized changer
     * reverts if builder state is not Whitelisted
     * @param builder_ address of builder
     * @param builderKickbackPct_ kickback percentage(100% == 1 ether)
     */
    function setBuilderKickbackPct(
        address builder_,
        uint256 builderKickbackPct_
    )
        external
        onlyGovernorOrAuthorizedChanger
        atState(builder_, BuilderState.Whitelisted)
    {
        _setBuilderKickbackPct(builder_, builderKickbackPct_);
    }

    // -----------------------------
    // ---- Public Functions -----
    // -----------------------------

    /**
     * @notice get builder state
     * @param builder_ address of builder
     */
    function getState(address builder_) public view returns (BuilderState) {
        return builderState[builder_];
    }

    /**
     * @notice get builder reward receiver
     * @param builder_ address of builder
     */
    function getRewardReceiver(address builder_) public view returns (address) {
        return builderRewardReceiver[builder_];
    }

    /**
     * @notice get builder kickback percentage
     * @param builder_ address of builder
     */
    function getBuilderKickbackPct(address builder_) public view returns (uint256) {
        return builderKickbackPct[builder_];
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    function _setBuilderKickbackPct(address builder_, uint256 builderKickbackPct_) internal {
        if (builderKickbackPct_ > 1 ether) revert InvalidBuilderKickbackPct();
        builderKickbackPct[builder_] = builderKickbackPct_;

        emit BuilderKickbackPctUpdate(builder_, builderKickbackPct_);
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
