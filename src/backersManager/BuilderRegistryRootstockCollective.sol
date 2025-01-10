// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { CycleTimeKeeperRootstockCollective } from "./CycleTimeKeeperRootstockCollective.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { SimpleAddressSet } from "../libraries/SimpleAddressSet.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "../gauge/GaugeFactoryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../interfaces/IGovernanceManagerRootstockCollective.sol";

/**
 * @title BuilderRegistryRootstockCollective
 * @notice Keeps registers of the builders
 */
abstract contract BuilderRegistryRootstockCollective is CycleTimeKeeperRootstockCollective, ERC165Upgradeable {
  using SimpleAddressSet for SimpleAddressSet.AddressSet;

  uint256 internal constant _MAX_REWARD_PERCENTAGE = UtilsLib._PRECISION;
  // -----------------------------
  // ------- Custom Errors -------
  // -----------------------------

  error AlreadyActivated();
  error AlreadyKYCApproved();
  error AlreadyCommunityApproved();
  error AlreadyRevoked();
  error NotActivated();
  error NotKYCApproved();
  error NotCommunityApproved();
  error NotPaused();
  error NotRevoked();
  error NotOperational();
  error InvalidBackerRewardPercentage();
  error InvalidBuilderRewardReceiver();
  error BuilderAlreadyExists();
  error BuilderDoesNotExist();
  error GaugeDoesNotExist();

  // -----------------------------
  // ----------- Events ----------
  // -----------------------------
  event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
  event KYCApproved(address indexed builder_);
  event KYCRevoked(address indexed builder_);
  event CommunityApproved(address indexed builder_);
  event Dewhitelisted(address indexed builder_);
  event Paused(address indexed builder_, bytes20 reason_);
  event Unpaused(address indexed builder_);
  event Revoked(address indexed builder_);
  event Permitted(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
  event BackerRewardPercentageUpdateScheduled(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
  event BuilderRewardReceiverReplacementRequested(address indexed builder_, address newRewardReceiver_);
  event BuilderRewardReceiverReplacementCancelled(address indexed builder_, address newRewardReceiver_);
  event BuilderRewardReceiverReplacementApproved(address indexed builder_, address newRewardReceiver_);
  event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);
  event BuilderMigrated(address indexed builder_, address indexed migrator_);

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
    bool communityApproved;
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
  /// @notice map of builders reward receiver replacement, used as a buffer until the new address is accepted
  mapping(address builder => address rewardReceiverReplacement) public builderRewardReceiverReplacement;
  /// @notice map of builder's backers reward percentage data
  mapping(address builder => RewardPercentageData rewardPercentageData) public backerRewardPercentage;
  /// @notice array of all the operational gauges
  SimpleAddressSet.AddressSet internal _gauges;
  /// @notice array of all the halted gauges
  SimpleAddressSet.AddressSet internal _haltedGauges;
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
   * @param distributionDuration_ duration of the distribution window
   */
  function __BuilderRegistryRootstockCollective_init(
    IGovernanceManagerRootstockCollective governanceManager_,
    address gaugeFactory_,
    address rewardDistributor_,
    uint32 cycleDuration_,
    uint24 cycleStartOffset_,
    uint32 distributionDuration_,
    uint128 rewardPercentageCooldown_
  ) internal onlyInitializing {
    __CycleTimeKeeperRootstockCollective_init(
      governanceManager_,
      cycleDuration_,
      cycleStartOffset_,
      distributionDuration_
    );
    __ERC165_init();
    gaugeFactory = GaugeFactoryRootstockCollective(gaugeFactory_);
    rewardDistributor = rewardDistributor_;
    rewardPercentageCooldown = rewardPercentageCooldown_;
  }

  // -----------------------------
  // ---- External Functions -----
  // -----------------------------

  /**
   * @notice Builder submits a request to replace his rewardReceiver address,
   * the request will then need to be approved by `approveBuilderRewardReceiverReplacement`
   * @dev reverts if Builder is not Operational
   * @param newRewardReceiver_ new address the builder is requesting to use
   */
  function submitRewardReceiverReplacementRequest(address newRewardReceiver_) external {
    _submitRewardReceiverReplacementRequest(newRewardReceiver_);
    emit BuilderRewardReceiverReplacementRequested(msg.sender, newRewardReceiver_);
  }

  /**
   * @notice Builder cancels his request to replace his rewardReceiver address
   * @dev reverts if Builder is not Operational
   */
  function cancelRewardReceiverReplacementRequest() external {
    // By overriding the replacement with the current, it effectively cancels the request
    address _currRewardReceiver = builderRewardReceiver[msg.sender];
    _submitRewardReceiverReplacementRequest(_currRewardReceiver);
    emit BuilderRewardReceiverReplacementCancelled(msg.sender, _currRewardReceiver);
  }

  /**
   * @notice KYCApprover approves Builder's request to replace his rewardReceiver address
   * @dev reverts if provided `rewardReceiverReplacement_` doesn't match Builder's request
   * @param builder_ address of the builder
   * @param rewardReceiverReplacement_ new address the builder is requesting to use
   */
  function approveBuilderRewardReceiverReplacement(
    address builder_,
    address rewardReceiverReplacement_
  ) external onlyKycApprover {
    // Only an operational builder can be approved
    if (!isBuilderOperational(builder_)) revert NotOperational();

    address _rewardReceiverReplacement = builderRewardReceiverReplacement[builder_];
    if (_rewardReceiverReplacement != rewardReceiverReplacement_) revert InvalidBuilderRewardReceiver();
    builderRewardReceiver[builder_] = _rewardReceiverReplacement;
    emit BuilderRewardReceiverReplacementApproved(builder_, rewardReceiverReplacement_);
  }

  /**
   * @notice returns true if the builder has an open request to replace his receiver address
   * @param builder_ address of the builder
   */
  function hasBuilderRewardReceiverPendingApproval(address builder_) external view returns (bool) {
    return
      builderRewardReceiverReplacement[builder_] != address(0) &&
      builderRewardReceiver[builder_] != builderRewardReceiverReplacement[builder_];
  }

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
  ) external onlyKycApprover {
    _activateBuilder(builder_, rewardReceiver_, rewardPercentage_);
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
    // if builder is community approved, it has a gauge associated
    if (address(_gauge) != address(0)) {
      _haltGauge(_gauge);
      _gauge.moveBuilderUnclaimedRewards(rewardDistributor);
    }

    emit KYCRevoked(builder_);
  }

  /**
   * @notice community approve builder and create its gauge
   * @dev reverts if it is not called by the governor address or authorized changer
   * reverts if is already community approved
   * reverts if it has a gauge associated
   * @param builder_ address of the builder
   * @return gauge_ gauge contract
   */
  function communityApproveBuilder(
    address builder_
  ) external onlyValidChanger returns (GaugeRootstockCollective gauge_) {
    return _communityApproveBuilder(builder_);
  }

  /**
   * @notice de-whitelist builder
   * @dev reverts if it is not called by the governor address or authorized changer
   * reverts if it does not have a gauge associated
   * reverts if it is not community approved
   * @param builder_ address of the builder
   */
  function dewhitelistBuilder(address builder_) external onlyValidChanger {
    GaugeRootstockCollective _gauge = builderToGauge[builder_];
    if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
    if (!builderState[builder_].communityApproved) revert NotCommunityApproved();

    builderState[builder_].communityApproved = false;

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
   *  reverts if it is not community approved
   *  reverts if it is not revoked
   *  reverts if it is executed in distribution period because changing the totalPotentialReward produce a
   * miscalculation of rewards
   * @param rewardPercentage_ reward percentage(100% == 1 ether)
   */
  function permitBuilder(uint64 rewardPercentage_) external {
    GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
    if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
    if (!builderState[msg.sender].kycApproved) revert NotKYCApproved();
    if (!builderState[msg.sender].communityApproved) revert NotCommunityApproved();
    if (!builderState[msg.sender].revoked) revert NotRevoked();

    // TODO: should we have a minimal amount?
    if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
      revert InvalidBackerRewardPercentage();
    }

    builderState[msg.sender].revoked = false;

    // read from storage
    RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[msg.sender];

    _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
    _rewardPercentageData.next = rewardPercentage_;

    // write to storage
    backerRewardPercentage[msg.sender] = _rewardPercentageData;

    _resumeGauge(_gauge);

    emit Permitted(msg.sender, rewardPercentage_, _rewardPercentageData.cooldownEndTime);
  }

  /**
   * @notice revoke builder
   * @dev reverts if it does not have a gauge associated
   *  reverts if it is not KYC approved
   *  reverts if it is not community approved
   *  reverts if it is already revoked
   *  reverts if it is executed in distribution period because changing the totalPotentialReward produce a
   * miscalculation of rewards
   */
  function revokeBuilder() external {
    GaugeRootstockCollective _gauge = builderToGauge[msg.sender];
    if (address(_gauge) == address(0)) revert BuilderDoesNotExist();
    if (!builderState[msg.sender].kycApproved) revert NotKYCApproved();
    if (!builderState[msg.sender].communityApproved) revert NotCommunityApproved();
    if (builderState[msg.sender].revoked) revert AlreadyRevoked();

    builderState[msg.sender].revoked = true;
    // when revoked builder wants to come back, it can set a new reward percentage. So, the cooldown time starts
    // here
    backerRewardPercentage[msg.sender].cooldownEndTime = uint128(block.timestamp + rewardPercentageCooldown);

    _haltGauge(_gauge);

    emit Revoked(msg.sender);
  }

  /**
   * @notice allows a builder to set his backers reward percentage
   * @dev reverts if builder is not operational
   * @param rewardPercentage_ reward percentage(100% == 1 ether)
   */
  function setBackerRewardPercentage(uint64 rewardPercentage_) external {
    if (!isBuilderOperational(msg.sender)) revert NotOperational();

    // TODO: should we have a minimal amount?
    if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
      revert InvalidBackerRewardPercentage();
    }

    // read from storage
    RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[msg.sender];

    _rewardPercentageData.previous = getRewardPercentageToApply(msg.sender);
    _rewardPercentageData.next = rewardPercentage_;
    _rewardPercentageData.cooldownEndTime = uint128(block.timestamp) + rewardPercentageCooldown;

    emit BackerRewardPercentageUpdateScheduled(msg.sender, rewardPercentage_, _rewardPercentageData.cooldownEndTime);

    // write to storage
    backerRewardPercentage[msg.sender] = _rewardPercentageData;
  }

  /**
   * @notice migrate v1 builder to the new builder registry
   * @param builder_ address of the builder whitelisted on the V1's SimplifiedRewardDistributor contract
   * @param rewardAddress_ address of the builder reward receiver whitelisted on the V1's SimplifiedRewardDistributor
   * contract
   * @param rewardPercentage_ reward percentage(100% == 1 ether)
   */
  function migrateBuilder(address builder_, address rewardAddress_, uint64 rewardPercentage_) public onlyKycApprover {
    _communityApproveBuilder(builder_);
    _activateBuilder(builder_, rewardAddress_, rewardPercentage_);

    emit BuilderMigrated(builder_, msg.sender);
  }

  /**
   * @notice returns reward percentage to apply.
   *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
   * @param builder_ address of the builder
   */
  function getRewardPercentageToApply(address builder_) public view returns (uint64) {
    RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[builder_];
    if (block.timestamp >= _rewardPercentageData.cooldownEndTime) {
      return _rewardPercentageData.next;
    }
    return _rewardPercentageData.previous;
  }

  /**
   * @notice return true if builder is operational
   *  kycApproved == true &&
   *  communityApproved == true &&
   *  paused == false
   */
  function isBuilderOperational(address builder_) public view returns (bool) {
    BuilderState memory _builderState = builderState[builder_];
    return _builderState.kycApproved && _builderState.communityApproved && !_builderState.paused;
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
   *  communityApproved == true &&
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
   * @notice Builder submits a request to replace his rewardReceiver address,
   * the request will then need to be approved by `approveBuilderRewardReceiverReplacement`
   * @dev reverts if Builder is not Operational
   * @param newRewardReceiver_ new address the builder is requesting to use
   */
  function _submitRewardReceiverReplacementRequest(address newRewardReceiver_) internal {
    // Only builder can submit a reward receiver address replacement
    address _builder = msg.sender;
    // Only operational builder can initiate this action
    if (!isBuilderOperational(_builder)) revert NotOperational();
    builderRewardReceiverReplacement[_builder] = newRewardReceiver_;
  }

  /**
   * @notice reverts if builder was not activated or approved by the community
   */
  function _validateWhitelisted(GaugeRootstockCollective gauge_) internal view {
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
   * @dev BackersManagerRootstockCollective override this function to restore its shares
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
   *  communityApproved == true &&
   *  revoked == false
   * @param gauge_ gauge contract to be resumed
   */
  function _canBeResumed(GaugeRootstockCollective gauge_) internal view returns (bool) {
    BuilderState memory _builderState = builderState[gaugeToBuilder[gauge_]];
    return _builderState.kycApproved && _builderState.communityApproved && !_builderState.revoked;
  }

  /**
   * @dev activates builder for the first time, setting the reward receiver and the reward percentage
   *  Sets activate flag to true. It cannot be switched to false anymore
   *  See {activateBuilder} for details.
   */
  function _activateBuilder(address builder_, address rewardReceiver_, uint64 rewardPercentage_) private {
    if (builderState[builder_].activated) revert AlreadyActivated();
    builderState[builder_].activated = true;
    builderState[builder_].kycApproved = true;
    builderRewardReceiver[builder_] = rewardReceiver_;
    // TODO: should we have a minimal amount?
    if (rewardPercentage_ > _MAX_REWARD_PERCENTAGE) {
      revert InvalidBackerRewardPercentage();
    }

    // read from storage
    RewardPercentageData memory _rewardPercentageData = backerRewardPercentage[builder_];

    _rewardPercentageData.previous = rewardPercentage_;
    _rewardPercentageData.next = rewardPercentage_;
    _rewardPercentageData.cooldownEndTime = uint128(block.timestamp);

    // write to storage
    backerRewardPercentage[builder_] = _rewardPercentageData;

    emit BuilderActivated(builder_, rewardReceiver_, rewardPercentage_);
  }

  /**
   * @dev Internal function to community approve and create its gauge
   *  See {communityApproveBuilder} for details.
   */
  function _communityApproveBuilder(address builder_) private returns (GaugeRootstockCollective gauge_) {
    if (builderState[builder_].communityApproved) revert AlreadyCommunityApproved();
    if (address(builderToGauge[builder_]) != address(0)) revert BuilderAlreadyExists();

    builderState[builder_].communityApproved = true;
    gauge_ = _createGauge(builder_);

    _rewardTokenApprove(address(gauge_), type(uint256).max);

    emit CommunityApproved(builder_);
  }

  /**
   * @notice BackersManagerRootstockCollective override this function to modify gauge rewardToken allowance
   * @param gauge_ gauge contract to approve rewardTokens
   * @param value_ amount of rewardTokens to approve
   */
  function _rewardTokenApprove(address gauge_, uint256 value_) internal virtual {}

  /**
   * @notice BackersManagerRootstockCollective override this function to remove its shares
   * @param gauge_ gauge contract to be halted
   */
  function _haltGaugeShares(GaugeRootstockCollective gauge_) internal virtual {}

  /**
   * @notice BackersManagerRootstockCollective override this function to restore its shares
   * @param gauge_ gauge contract to be resumed
   */
  function _resumeGaugeShares(GaugeRootstockCollective gauge_) internal virtual {}

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */

  // Purposely left unused to save some state space to allow for future upgrades
  // slither-disable-next-line unused-state
  uint256[50] private __gap;
}
