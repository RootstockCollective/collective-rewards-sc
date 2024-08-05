// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Governed } from "../governance/Governed.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title SimplifiedBuilderRegistry
 * @notice Simplified version for the MVP.
 *  Keeps registers of the builders
 */
abstract contract SimplifiedBuilderRegistry is Governed, Ownable2StepUpgradeable {
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------

    error NotAuthorized();
    error RequiredState(BuilderState state);

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdate(address indexed builder_, BuilderState previousState_, BuilderState newState_);

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
        Whitelisted
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------

    /// @notice map of builders state
    mapping(address builder => BuilderState state) public builderState;

    /// @notice map of builders reward receiver
    mapping(address builder => address payable rewardReceiver) public builderRewardReceiver;

    // @notice array of whitelisted builders
    address[] public whitelistedBuilders;

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
    function ___SimplifiedBuilderRegistry_init(
        address changeExecutor_,
        address kycApprover_
    )
        internal
        onlyInitializing
    {
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
     */
    function activateBuilder(
        address builder_,
        address payable rewardReceiver_
    )
        external
        onlyOwner
        atState(builder_, BuilderState.Pending)
    {
        builderRewardReceiver[builder_] = rewardReceiver_;

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
        whitelistedBuilders.push(builder_);
        _updateState(builder_, BuilderState.Whitelisted);
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
     * @notice get length of whitelisted builders array
     */
    function getWhitelistedBuildersLength() public view returns (uint256) {
        return whitelistedBuilders.length;
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    function _updateState(address builder_, BuilderState newState_) internal {
        BuilderState previousState_ = builderState[builder_];
        builderState[builder_] = newState_;
        emit StateUpdate(builder_, previousState_, newState_);
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
