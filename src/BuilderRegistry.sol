// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 */
contract BuilderRegistry {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error NotFoundation();
    error NotGovernor();
    error NotAuthorized();
    error RequiredState(BuilderState state);

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdate(address indexed builder_, BuilderState indexed state_);
    event RewardSplitPercentageUpdate(address indexed builder_, uint8 rewardSplitPercentage_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyFoundation() {
        if (msg.sender != foundation) revert NotFoundation();
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert NotGovernor();
        _;
    }

    modifier atState(address builder_, BuilderState preState_) {
        Builder memory _builder = builders[builder_];
        if (_builder.state != preState_) revert RequiredState(preState_);
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
    // ---------- Structs ----------
    // -----------------------------
    struct Builder {
        BuilderState state;
        address rewardsReceiver;
        uint256 rewardSplitPercentage;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice foundation address
    address public immutable foundation;

    /// @notice governor address
    address public immutable governor;

    /// @notice map of builders with their information
    mapping(address builder => Builder registry) public builders;

    /**
     * @notice constructor
     * @param foundation_ address of the foundation
     * @param governor_ address of the governor
     */
    constructor(address foundation_, address governor_) {
        foundation = foundation_;
        governor = governor_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice activates builder and set rewards receiver
     * @dev reverts if is not called by the foundation address
     * reverts if builder state is not pending
     * @param builder_ address of builder
     * @param rewardsReceiver_ address of the builder rewards receiver
     */
    function activateBuilder(
        address builder_,
        address rewardsReceiver_
    )
        external
        onlyFoundation
        atState(builder_, BuilderState.Pending)
    {
        Builder storage _builder = builders[builder_];
        _builder.state = BuilderState.KYCApproved;
        _builder.rewardsReceiver = rewardsReceiver_;

        emit StateUpdate(builder_, _builder.state);
    }

    /**
     * @notice whitelist builder
     * @dev reverts if is not called by the governor address
     * reverts if builder state is not KYCApproved
     * @param builder_ address of builder
     */
    function whitelistBuilder(address builder_) external onlyGovernor atState(builder_, BuilderState.KYCApproved) {
        Builder storage _builder = builders[builder_];
        _builder.state = BuilderState.Whitelisted;

        emit StateUpdate(builder_, _builder.state);
    }

    /**
     * @notice pause builder
     * @dev reverts if is not called by the governor address
     * reverts if builder state is not Whitelisted
     * @param builder_ address of builder
     */
    function pauseBuilder(address builder_) external onlyGovernor atState(builder_, BuilderState.Whitelisted) {
        Builder storage _builder = builders[builder_];
        _builder.state = BuilderState.Paused;

        emit StateUpdate(builder_, _builder.state);
    }

    /**
     * @notice permit builder
     * @dev reverts if is not called by the governor address
     * reverts if builder state is not Revoked
     * @param builder_ address of builder
     */
    function permitBuilder(address builder_) external onlyGovernor atState(builder_, BuilderState.Revoked) {
        Builder storage _builder = builders[builder_];
        _builder.state = BuilderState.Whitelisted;

        emit StateUpdate(builder_, _builder.state);
    }

    /**
     * @notice revoke builder
     * @dev reverts if is not called by the builder address
     * reverts if builder state is not Whitelisted
     * @param builder_ address of builder
     */
    function revokeBuilder(address builder_) external atState(builder_, BuilderState.Whitelisted) {
        if (msg.sender != builder_) revert NotAuthorized();

        Builder storage _builder = builders[builder_];
        _builder.state = BuilderState.Revoked;

        emit StateUpdate(builder_, _builder.state);
    }

    /**
     * @notice set builder reward split percentage
     * @dev reverts if is not called by the governor address
     * reverts if builder state is not Whitelisted
     * @param builder_ address of builder
     * @param rewardSplitPercentage_ percentage of reward split
     */
    function setRewardSplitPercentage(
        address builder_,
        uint8 rewardSplitPercentage_
    )
        external
        onlyGovernor
        atState(builder_, BuilderState.Whitelisted)
    {
        Builder storage _builder = builders[builder_];
        _builder.rewardSplitPercentage = rewardSplitPercentage_;

        emit RewardSplitPercentageUpdate(builder_, rewardSplitPercentage_);
    }

    // -----------------------------
    // ---- Public Functions -----
    // -----------------------------

    /**
     * @notice get builder state
     * @param builder_ address of builder
     */
    function getState(address builder_) public view returns (BuilderState) {
        Builder storage _builder = builders[builder_];

        return _builder.state;
    }

    /**
     * @notice get builder rewards receiver
     * @param builder_ address of builder
     */
    function getRewardsReceiver(address builder_) public view returns (address) {
        Builder storage _builder = builders[builder_];

        return _builder.rewardsReceiver;
    }

    /**
     * @notice get builder reward split percentage
     * @param builder_ address of builder
     */
    function getRewardSplitPercentage(address builder_) public view returns (uint256) {
        Builder storage _builder = builders[builder_];

        return _builder.rewardSplitPercentage;
    }
}
