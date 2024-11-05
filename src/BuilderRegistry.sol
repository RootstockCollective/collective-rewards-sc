// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { CycleTimeKeeper } from "./CycleTimeKeeper.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Gauge } from "./gauge/Gauge.sol";
import { GaugeFactory } from "./gauge/GaugeFactory.sol";
import { IGovernanceManager } from "./interfaces/IGovernanceManager.sol";

/**
 * @title BuilderRegistry
 * @notice Keeps registers of the builders
 */
abstract contract BuilderRegistry is CycleTimeKeeper, ERC165Upgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant _MAX_KICKBACK = UtilsLib._PRECISION;
    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------

    error AlreadyActivated();
    error AlreadyKYCApproved();
    error AlreadyWhitelisted();
    error AlreadyRevoked();
    error NotActivated();
    error NotKYCApproved();
    error NotWhitelisted();
    error NotPaused();
    error NotRevoked();
    error IsRevoked();
    error CannotRevoke();
    error NotOperational();
    error InvalidBuilderKickback();
    error BuilderAlreadyExists();
    error BuilderDoesNotExist();
    error GaugeDoesNotExist();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 kickback_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event Whitelisted(address indexed builder_);
    event Dewhitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Unpaused(address indexed builder_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_, uint256 kickback_, uint256 cooldown_);
    event BuilderKickbackUpdateScheduled(address indexed builder_, uint256 kickback_, uint256 cooldown_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    // -----------------------------
    // --------- Modifiers ---------
    // -----------------------------
    modifier onlyKycApprover() {
        governanceManager.validateKycApprover(msg.sender);
        _;
    }

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct BuilderState {
        bool activated;
        bool kycApproved;
        bool whitelisted;
        bool paused;
        bool revoked;
        bytes7 reserved; // for future upgrades
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
    /// @notice reward distributor address. If a builder is KYC revoked their unclaimed rewards will sent back here
    address public rewardDistributor;
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
     * @param governanceManager_ contract with permissioned roles
     * @param gaugeFactory_ address of the GaugeFactory contract
     * @param rewardDistributor_ address of the rewardDistributor contract
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @param cycleStartOffset_ offset to add to the first cycle, used to set an specific day to start the cycles
     * @param kickbackCooldown_ time that must elapse for a new kickback from a builder to be applied
     */
    function __BuilderRegistry_init(
        IGovernanceManager governanceManager_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint128 kickbackCooldown_
    )
        internal
        onlyInitializing
    {
        __CycleTimeKeeper_init(governanceManager_, cycleDuration_, cycleStartOffset_);
        __ERC165_init();
        gaugeFactory = GaugeFactory(gaugeFactory_);
        rewardDistributor = rewardDistributor_;
        kickbackCooldown = kickbackCooldown_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice activates builder for the first time, setting the reward receiver and the kickback
     *  Sets activate flag to true. It cannot be switched to false anymore
     * @dev reverts if it is not called by the owner address
     * reverts if it is already activated
     * @param builder_ address of the builder
     * @param rewardReceiver_ address of the builder reward receiver
     * @param kickback_ kickback(100% == 1 ether)
     */
    function activateBuilder(address builder_, address rewardReceiver_, uint64 kickback_) external onlyKycApprover {
        if (builderState[builder_].activated) revert AlreadyActivated();
        builderState[builder_].activated = true;
        builderState[builder_].kycApproved = true;
        builderRewardReceiver[builder_] = rewardReceiver_;
        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        // read from storage
        KickbackData memory _kickbackData = builderKickback[builder_];

        _kickbackData.previous = kickback_;
        _kickbackData.next = kickback_;
        _kickbackData.cooldownEndTime = uint128(block.timestamp);

        // write to storage
        builderKickback[builder_] = _kickbackData;

        emit BuilderActivated(builder_, rewardReceiver_, kickback_);
    }

    /**
     * @notice approves builder's KYC after a revocation
     * @dev reverts if it is not called by the owner address
     * reverts if it is not activated
     * reverts if it is already KYC approved
     * reverts if it does not have a gauge associated
     * @param builder_ address of the builder
     */
    function approveBuilderKYC(address builder_) external onlyKycApprover {
        Gauge _gauge = builderToGauge[builder_];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[builder_].activated) revert NotActivated();
        if (builderState[builder_].kycApproved) revert AlreadyKYCApproved();

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
        if (!builderState[builder_].kycApproved) revert NotKYCApproved();

        builderState[builder_].kycApproved = false;

        Gauge _gauge = builderToGauge[builder_];
        // if builder is whitelisted, it has a gauge associated
        if (address(_gauge) != address(0)) {
            _haltGauge(_gauge);
            _gauge.moveBuilderUnclaimedRewards(rewardDistributor);
        }

        emit KYCRevoked(builder_);
    }

    /**
     * @notice whitelist builder and create its gauge
     * @dev reverts if it is not called by the governor address or authorized changer
     * reverts if is already whitelisted
     * reverts if it has a gauge associated
     * @param builder_ address of the builder
     * @return gauge_ gauge contract
     */
    function whitelistBuilder(address builder_) external onlyValidChanger returns (Gauge gauge_) {
        if (builderState[builder_].whitelisted) revert AlreadyWhitelisted();
        if (address(builderToGauge[builder_]) != address(0)) revert BuilderAlreadyExists();

        builderState[builder_].whitelisted = true;
        gauge_ = _createGauge(builder_);

        _rewardTokenApprove(address(gauge_), type(uint256).max);

        emit Whitelisted(builder_);
    }

    /**
     * @notice de-whitelist builder
     * @dev reverts if it is not called by the governor address or authorized changer
     * reverts if it does not have a gauge associated
     * reverts if it is not whitelisted
     * @param builder_ address of the builder
     */
    function dewhitelistBuilder(address builder_) external onlyValidChanger {
        Gauge _gauge = builderToGauge[builder_];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[builder_].whitelisted) revert NotWhitelisted();

        builderState[builder_].whitelisted = false;

        _haltGauge(_gauge);
        _rewardTokenApprove(address(_gauge), 0);

        emit Dewhitelisted(builder_);
    }

    /**
     * @notice pause builder
     * @dev reverts if it is not called by the owner address
     * @param builder_ address of the builder
     * @param reason_ reason for the pause
     */
    function pauseBuilder(address builder_, bytes20 reason_) external onlyKycApprover {
        // pause can be overwritten to change the reason
        builderState[builder_].paused = true;
        builderState[builder_].pausedReason = reason_;
        emit Paused(builder_, reason_);
    }

    /**
     * @notice unpause builder
     * @dev reverts if it is not called by the owner address
     * reverts if it is not paused
     * @param builder_ address of the builder
     */
    function unpauseBuilder(address builder_) external onlyKycApprover {
        if (!builderState[builder_].paused) revert NotPaused();

        builderState[builder_].paused = false;
        builderState[builder_].pausedReason = "";

        emit Unpaused(builder_);
    }

    /**
     * @notice permit builder
     * @dev reverts if it does not have a gauge associated
     *  reverts if it is not KYC approved
     *  reverts if it is not whitelisted
     *  reverts if it is not revoked
     *  reverts if it is executed in distribution period because changing the totalPotentialReward produce a
     * miscalculation of rewards
     * @param kickback_ kickback(100% == 1 ether)
     */
    // function permitBuilder(uint64 kickback_) external {
    function permitBuilder(uint64 kickback_) external {
        Gauge _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[msg.sender].kycApproved) revert NotKYCApproved();
        if (!builderState[msg.sender].whitelisted) revert NotWhitelisted();
        if (!builderState[msg.sender].revoked) revert NotRevoked();

        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        builderState[msg.sender].revoked = false;

        // read from storage
        KickbackData memory _kickbackData = builderKickback[msg.sender];

        _kickbackData.previous = getKickbackToApply(msg.sender);
        _kickbackData.next = kickback_;

        // write to storage
        builderKickback[msg.sender] = _kickbackData;

        _resumeGauge(_gauge);

        emit Permitted(msg.sender, kickback_, _kickbackData.cooldownEndTime);
    }

    /**
     * @notice revoke builder
     * @dev reverts if it does not have a gauge associated
     *  reverts if it is not KYC approved
     *  reverts if it is not whitelisted
     *  reverts if it is already revoked
     *  reverts if it is executed in distribution period because changing the totalPotentialReward produce a
     * miscalculation of rewards
     */
    function revokeBuilder() external {
        Gauge _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[msg.sender].kycApproved) revert NotKYCApproved();
        if (!builderState[msg.sender].whitelisted) revert NotWhitelisted();
        if (builderState[msg.sender].revoked) revert AlreadyRevoked();

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
        if (!isBuilderOperational(msg.sender)) revert NotOperational();

        // TODO: should we have a minimal amount?
        if (kickback_ > _MAX_KICKBACK) {
            revert InvalidBuilderKickback();
        }

        // read from storage
        KickbackData memory _kickbackData = builderKickback[msg.sender];

        _kickbackData.previous = getKickbackToApply(msg.sender);
        _kickbackData.next = kickback_;
        _kickbackData.cooldownEndTime = uint128(block.timestamp) + kickbackCooldown;

        emit BuilderKickbackUpdateScheduled(msg.sender, kickback_, _kickbackData.cooldownEndTime);

        // write to storage
        builderKickback[msg.sender] = _kickbackData;
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
     * @notice return true if builder is paused
     */
    function isBuilderPaused(address builder_) public view returns (bool) {
        return builderState[builder_].paused;
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
     * @notice reverts if builder was not activated or approved by the community
     */
    function _validateGauge(Gauge gauge_) internal view {
        address _builder = gaugeToBuilder[gauge_];
        if (_builder == address(0)) revert GaugeDoesNotExist();
        if (!builderState[_builder].activated) revert NotActivated();
    }

    /**
     * @notice halts a gauge moving it from the active array to the halted one
     * @param gauge_ gauge contract to be halted
     */
    function _haltGauge(Gauge gauge_) internal {
        if (!isGaugeHalted(address(gauge_))) {
            _haltedGauges.add(address(gauge_));
            _gauges.remove(address(gauge_));
            _haltGaugeShares(gauge_);
        }
    }

    /**
     * @notice resumes a gauge moving it from the halted array to the active one
     * @dev SponsorsManager override this function to restore its shares
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGauge(Gauge gauge_) internal {
        if (_canBeResumed(gauge_)) {
            _gauges.add(address(gauge_));
            _haltedGauges.remove(address(gauge_));
            _resumeGaugeShares(gauge_);
        }
    }

    /**
     * @notice returns true if gauge can be resumed
     * @dev kycApproved == true &&
     *  whitelisted == true &&
     *  revoked == false
     * @param gauge_ gauge contract to be resumed
     */
    function _canBeResumed(Gauge gauge_) internal view returns (bool) {
        BuilderState memory _builderState = builderState[gaugeToBuilder[gauge_]];
        return _builderState.kycApproved && _builderState.whitelisted && !_builderState.revoked;
    }

    /**
     * @notice SponsorsManager override this function to modify gauge rewardToken allowance
     * @param gauge_ gauge contract to approve rewardTokens
     * @param value_ amount of rewardTokens to approve
     */
    function _rewardTokenApprove(address gauge_, uint256 value_) internal virtual { }
    /**
     * @notice SponsorsManager override this function to remove its shares
     * @param gauge_ gauge contract to be halted
     */
    function _haltGaugeShares(Gauge gauge_) internal virtual { }

    /**
     * @notice SponsorsManager override this function to restore its shares
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGaugeShares(Gauge gauge_) internal virtual { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
