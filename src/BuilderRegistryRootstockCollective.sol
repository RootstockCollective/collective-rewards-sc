// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { CycleTimeKeeperRootstockCollective } from "./CycleTimeKeeperRootstockCollective.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { GaugeRootstockCollective } from "./gauge/GaugeRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "./gauge/GaugeFactoryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "./interfaces/IGovernanceManagerRootstockCollective.sol";

/**
 * @title BuilderRegistryRootstockCollective
 * @notice Keeps registers of the builders
 */
abstract contract BuilderRegistryRootstockCollective is CycleTimeKeeperRootstockCollective, ERC165Upgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant _MAX_REWARD_PERCENTAGE = UtilsLib._PRECISION;
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
    error InvalidBuilderRewardPercentage();
    error BuilderAlreadyExists();
    error BuilderDoesNotExist();
    error GaugeDoesNotExist();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event Whitelisted(address indexed builder_);
    event Dewhitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Unpaused(address indexed builder_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event BuilderRewardPercentageUpdateScheduled(
        address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_
    );
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
    mapping(address builder => address rewardReceiver) public builderRewardReceiver;
    /// @notice map of builders reward percentage data
    mapping(address builder => RewardPercentageData rewardPercentageData) public builderRewardPercentage;
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

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /**
     * @notice contract initializer
     * @param governanceManager_ contract with permissioned roles
     * @param gaugeFactory_ address of the GaugeFactoryRootstockCollective contract
     * @param rewardDistributor_ address of the rewardDistributor contract
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @param cycleStartOffset_ offset to add to the first cycle, used to set an specific day to start the cycles
     * @param rewardPercentageCooldown_ time that must elapse for a new reward percentage from a builder to be applied
     */
    function __BuilderRegistryRootstockCollective_init(
        IGovernanceManagerRootstockCollective governanceManager_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint128 rewardPercentageCooldown_
    )
        internal
        onlyInitializing
    {
        __CycleTimeKeeperRootstockCollective_init(governanceManager_, cycleDuration_, cycleStartOffset_);
        __ERC165_init();
        gaugeFactory = GaugeFactoryRootstockCollective(gaugeFactory_);
        rewardDistributor = rewardDistributor_;
        rewardPercentageCooldown = rewardPercentageCooldown_;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice activates builder for the first time, setting the reward receiver and the reward percentage
     *  Sets activate flag to true. It cannot be switched to false anymore
     * @dev reverts if it is not called by the owner address
     * reverts if it is already activated
     * @param builder_ address of the builder
     * @param rewardReceiver_ address of the builder reward receiver
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function activateBuilder(
        address builder_,
        address rewardReceiver_,
        uint64 rewardPercentage_
    )
        external
        onlyKycApprover
    {
        if (builderState[builder_].activated) revert AlreadyActivated();
        builderState[builder_].activated = true;
        builderState[builder_].kycApproved = true;
        builderRewardReceiver[builder_] = rewardReceiver_;
        // TODO: should we have a minimal amount?
        if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
            revert InvalidBuilderRewardPercentage();
        }

        // read from storage
        RewardPercentageData memory _rewardPercentageData = builderRewardPercentage[builder_];

        _rewardPercentageData.previous = rewardPercentage_;
        _rewardPercentageData.next = rewardPercentage_;
        _rewardPercentageData.cooldownEndTime = uint128(block.timestamp);

        // write to storage
        builderRewardPercentage[builder_] = _rewardPercentageData;

        emit BuilderActivated(builder_, rewardReceiver_, rewardPercentage_);
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
        GaugeRootstockCollective _gauge = builderToGauge[builder_];
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

        GaugeRootstockCollective _gauge = builderToGauge[builder_];
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
    function whitelistBuilder(address builder_) external onlyValidChanger returns (GaugeRootstockCollective gauge_) {
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
        GaugeRootstockCollective _gauge = builderToGauge[builder_];
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
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    // function permitBuilder(uint64 rewardPercentage_) external {
    function permitBuilder(uint64 rewardPercentage_) external {
        GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[msg.sender].kycApproved) revert NotKYCApproved();
        if (!builderState[msg.sender].whitelisted) revert NotWhitelisted();
        if (!builderState[msg.sender].revoked) revert NotRevoked();

        // TODO: should we have a minimal amount?
        if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
            revert InvalidBuilderRewardPercentage();
        }

        builderState[msg.sender].revoked = false;

        // read from storage
        RewardPercentageData memory _rewardPercentageData = builderRewardPercentage[msg.sender];

        _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
        _rewardPercentageData.next = rewardPercentage_;

        // write to storage
        builderRewardPercentage[msg.sender] = _rewardPercentageData;

        _resumeGauge(_gauge);

        emit Permitted(msg.sender, rewardPercentage_, _rewardPercentageData.cooldownEndTime);
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
        GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
        if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
        if (!builderState[msg.sender].kycApproved) revert NotKYCApproved();
        if (!builderState[msg.sender].whitelisted) revert NotWhitelisted();
        if (builderState[msg.sender].revoked) revert AlreadyRevoked();

        builderState[msg.sender].revoked = true;
        // when revoked builder wants to come back, it can set a new reward percentage. So, the cooldown time starts
        // here
        builderRewardPercentage[msg.sender].cooldownEndTime = uint128(block.timestamp + rewardPercentageCooldown);

        _haltGauge(_gauge);

        emit Revoked(msg.sender);
    }

    /**
     * @notice set a builder reward percentage
     * @dev reverts if builder is not operational
     * @param rewardPercentage_ reward percentage(100% == 1 ether)
     */
    function setBuilderRewardPercentage(uint64 rewardPercentage_) external {
        if (!isBuilderOperational(msg.sender)) revert NotOperational();

        // TODO: should we have a minimal amount?
        if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
            revert InvalidBuilderRewardPercentage();
        }

        // read from storage
        RewardPercentageData memory _rewardPercentageData = builderRewardPercentage[msg.sender];

        _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
        _rewardPercentageData.next = rewardPercentage_;
        _rewardPercentageData.cooldownEndTime = uint128(block.timestamp) + rewardPercentageCooldown;

        emit BuilderRewardPercentageUpdateScheduled(
            msg.sender, rewardPercentage_, _rewardPercentageData.cooldownEndTime
        );

        // write to storage
        builderRewardPercentage[msg.sender] = _rewardPercentageData;
    }

    /**
     * @notice returns reward percentage to apply.
     *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
     * @param builder_ address of the builder
     */
    function getRewardPercentageToApply(address builder_) public view returns (uint64) {
        RewardPercentageData memory _rewardPercentageData = builderRewardPercentage[builder_];
        if (block.timestamp >= _rewardPercentageData.cooldownEndTime) {
            return _rewardPercentageData.next;
        }
        return _rewardPercentageData.previous;
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
    function _createGauge(address builder_) internal returns (GaugeRootstockCollective gauge_) {
        gauge_ = gaugeFactory.createGauge();
        builderToGauge[builder_] = gauge_;
        gaugeToBuilder[gauge_] = builder_;
        _gauges.add(address(gauge_));
        emit GaugeCreated(builder_, address(gauge_), msg.sender);
    }

    /**
     * @notice reverts if builder was not activated or approved by the community
     */
    function _validateGauge(GaugeRootstockCollective gauge_) internal view {
        address _builder = gaugeToBuilder[gauge_];
        if (_builder == address(0)) revert GaugeDoesNotExist();
        if (!builderState[_builder].activated) revert NotActivated();
    }

    /**
     * @notice halts a gauge moving it from the active array to the halted one
     * @param gauge_ gauge contract to be halted
     */
    function _haltGauge(GaugeRootstockCollective gauge_) internal {
        if (!isGaugeHalted(address(gauge_))) {
            _haltedGauges.add(address(gauge_));
            _gauges.remove(address(gauge_));
            _haltGaugeShares(gauge_);
        }
    }

    /**
     * @notice resumes a gauge moving it from the halted array to the active one
     * @dev SponsorsManagerRootstockCollective override this function to restore its shares
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGauge(GaugeRootstockCollective gauge_) internal {
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
    function _canBeResumed(GaugeRootstockCollective gauge_) internal view returns (bool) {
        BuilderState memory _builderState = builderState[gaugeToBuilder[gauge_]];
        return _builderState.kycApproved && _builderState.whitelisted && !_builderState.revoked;
    }

    /**
     * @notice SponsorsManagerRootstockCollective override this function to modify gauge rewardToken allowance
     * @param gauge_ gauge contract to approve rewardTokens
     * @param value_ amount of rewardTokens to approve
     */
    function _rewardTokenApprove(address gauge_, uint256 value_) internal virtual { }
    /**
     * @notice SponsorsManagerRootstockCollective override this function to remove its shares
     * @param gauge_ gauge contract to be halted
     */
    function _haltGaugeShares(GaugeRootstockCollective gauge_) internal virtual { }

    /**
     * @notice SponsorsManagerRootstockCollective override this function to restore its shares
     * @param gauge_ gauge contract to be resumed
     */
    function _resumeGaugeShares(GaugeRootstockCollective gauge_) internal virtual { }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}