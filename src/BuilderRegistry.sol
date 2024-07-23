// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Governed } from "./governance/Governed.sol";

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 */
contract BuilderRegistry is Governed {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotFoundation();
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
    modifier onlyFoundation() {
        if (msg.sender != foundation) revert NotFoundation();
        _;
    }

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

    /// @notice foundation address
    address public immutable foundation;

    /// @notice map of builders state
    mapping(address builder => BuilderState state) public builderState;

    /// @notice map of builders reward receiver
    mapping(address builder => address rewardReceiver) public builderRewardReceiver;

    /// @notice map of builders kickback percentage
    mapping(address builder => uint256 percentage) public builderKickbackPct;

    constructor(address governor_, address changeExecutor_, address foundation_) Governed(governor_, changeExecutor_) {
        foundation = foundation_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice activates builder and set reward receiver
     * @dev reverts if is not called by the foundation address
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
        onlyFoundation
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
}
