// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UpgradeableRootstockCollective } from "../governance/UpgradeableRootstockCollective.sol";
import { UtilsLib } from "../libraries/UtilsLib.sol";
import { IGovernanceManagerRootstockCollective } from "../interfaces/IGovernanceManagerRootstockCollective.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract CycleTimeKeeperRootstockCollective is UpgradeableRootstockCollective {
  error NotValidChangerOrFoundation();

  modifier onlyValidChangerOrFoundation() {
    if (!governanceManager.isAuthorizedChanger(msg.sender) && msg.sender != governanceManager.foundationTreasury()) {
      revert NotValidChangerOrFoundation();
    }
    _;
  }

  modifier onlyFoundation() {
    governanceManager.validateFoundationTreasury(msg.sender);
    _;
  }

  // -----------------------------
  // ------- Custom Errors -------
  // -----------------------------
  error CycleDurationTooShort();
  error DistributionDurationTooShort();
  error DistributionDurationTooLong();
  error DistributionModifiedDuringDistributionWindow();

  // -----------------------------
  // ----------- Events ----------
  // -----------------------------
  event NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_);
  event NewDistributionDuration(uint256 newDistributionDuration_, address by_);

  // -----------------------------
  // ---------- Structs ----------
  // -----------------------------
  struct CycleData {
    // previous cycle duration
    uint32 previousDuration;
    // next cycle duration
    uint32 nextDuration;
    // after this time, new cycle duration will be applied
    uint64 previousStart;
    // after this time, next cycle duration will be applied
    uint64 nextStart;
    // offset to add to the first cycle, used to set an specific day to start the cycles
    uint24 offset;
  }

  // -----------------------------
  // ---------- Storage ----------
  // -----------------------------
  /// @notice cycle data
  CycleData public cycleData;
  uint32 public distributionDuration;

  // -----------------------------
  // ------- Initializer ---------
  // -----------------------------

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice contract initializer
   * @dev the first cycle will end in cycleDuration_ + cycleStartOffset_ seconds to to ensure that
   *  it lasts at least as long as the desired period
   * @param governanceManager_ contract with permissioned roles
   * @param cycleDuration_ Collective Rewards cycle time duration
   * @param cycleStartOffset_ offset to add to the first cycle, used to set an specific day to start the cycles
   * @param distributionDuration_ duration of the distribution window
   */
  function __CycleTimeKeeperRootstockCollective_init(
    IGovernanceManagerRootstockCollective governanceManager_,
    uint32 cycleDuration_,
    uint24 cycleStartOffset_,
    uint32 distributionDuration_
  ) internal onlyInitializing {
    __Upgradeable_init(governanceManager_);

    // read from store
    CycleData memory _cycleData = cycleData;

    _cycleData.previousDuration = cycleDuration_;
    _cycleData.nextDuration = cycleDuration_;
    _cycleData.previousStart = uint64(block.timestamp);
    _cycleData.nextStart = uint64(block.timestamp);
    _cycleData.offset = cycleStartOffset_;

    // write to storage
    cycleData = _cycleData;
    distributionDuration = distributionDuration_;
  }

  // -----------------------------
  // ---- External Functions -----
  // -----------------------------

  /**
   * @notice schedule a new cycle duration. It will be applied for the next cycle
   * @dev reverts if is too short. It must be greater than 2 time the distribution window
   * @dev only callable by an authorized changer or the foundation
   * @param newCycleDuration_ new cycle duration
   * @param cycleStartOffset_ offset to add to the first cycle, used to set an specific day to start the cycles
   */
  function setCycleDuration(uint32 newCycleDuration_, uint24 cycleStartOffset_) external onlyValidChangerOrFoundation {
    if (!_isValidDistributionToCycleRatio(distributionDuration, newCycleDuration_)) revert CycleDurationTooShort();

    (uint256 _start, uint256 _duration) = getCycleStartAndDuration();
    // read from store
    CycleData memory _cycleData = cycleData;

    _cycleData.previousDuration = uint32(_duration);
    _cycleData.nextDuration = newCycleDuration_;
    _cycleData.previousStart = uint64(_start);
    _cycleData.nextStart = uint64(
      UtilsLib._calcCycleNext(_cycleData.previousStart, _cycleData.previousDuration, block.timestamp)
    );
    _cycleData.offset = cycleStartOffset_;

    emit NewCycleDurationScheduled(newCycleDuration_, _cycleData.nextStart);

    // write to storage
    cycleData = _cycleData;
  }

  /**
   * @notice set the duration of the distribution window
   * @dev reverts if is too short. It must be greater than 0
   * @dev reverts if the new distribution is greater than half of the cycle duration
   * @dev reverts if the distribution window is modified during the distribution window
   * @dev only callable by the foundation
   * @param newDistributionDuration_ new distribution window duration
   */
  function setDistributionDuration(uint32 newDistributionDuration_) external onlyFoundation {
    // revert if the new distribution duration is too short
    if (newDistributionDuration_ == 0) revert DistributionDurationTooShort();

    // revert if the distribution duration is modified during the current or new distribution window
    uint256 _cycleStart = cycleStart(block.timestamp);
    if (
      block.timestamp > _cycleStart &&
      (block.timestamp < _cycleStart + Math.max(distributionDuration, newDistributionDuration_))
    ) {
      revert DistributionModifiedDuringDistributionWindow();
    }

    // revert if the new distribution duration is too long
    CycleData memory _cycleData = cycleData;
    if (!_isValidDistributionToCycleRatio(newDistributionDuration_, _cycleData.nextDuration)) {
      revert DistributionDurationTooLong();
    }
    if (block.timestamp < _cycleData.nextStart) {
      if (!_isValidDistributionToCycleRatio(newDistributionDuration_, _cycleData.previousDuration)) {
        revert DistributionDurationTooLong();
      }
    }

    emit NewDistributionDuration(newDistributionDuration_, msg.sender);

    distributionDuration = newDistributionDuration_;
  }

  /**
   * @notice gets when an cycle starts based on given `timestamp_`
   * @param timestamp_ timestamp to calculate
   * @return cycleStart timestamp when the cycle starts
   */
  function cycleStart(uint256 timestamp_) public view returns (uint256) {
    (uint256 _start, uint256 _duration) = getCycleStartAndDuration();
    uint256 _timeSinceStart = timestamp_ - _start;
    unchecked {
      return timestamp_ - (_timeSinceStart % _duration);
    }
  }

  /**
   * @notice gets when an cycle ends or the next one starts based on given `timestamp_`
   * @param timestamp_ timestamp to calculate
   * @return cycleNext timestamp when the cycle ends or the next starts
   */
  function cycleNext(uint256 timestamp_) public view returns (uint256) {
    (uint256 _start, uint256 _duration) = getCycleStartAndDuration();
    return UtilsLib._calcCycleNext(_start, _duration, timestamp_);
  }

  /**
   * @notice gets when an cycle distribution ends based on given `timestamp_`
   * @param timestamp_ timestamp to calculate
   * @return endDistributionWindow timestamp when the cycle distribution ends
   */
  function endDistributionWindow(uint256 timestamp_) public view returns (uint256) {
    return cycleStart(timestamp_) + distributionDuration;
  }

  /**
   * @notice gets time left until the next cycle based on given `timestamp_`
   * @param timestamp_ timestamp to calculate
   * @return timeUntilNextCycle amount of time until next cycle
   */
  function timeUntilNextCycle(uint256 timestamp_) public view returns (uint256) {
    (uint256 _start, uint256 _duration) = getCycleStartAndDuration();
    return UtilsLib._calcTimeUntilNextCycle(_start, _duration, timestamp_);
  }

  /**
   * @notice returns cycle start and duration
   *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
   */
  function getCycleStartAndDuration() public view returns (uint256, uint256) {
    CycleData memory _cycleData = cycleData;
    if (block.timestamp >= _cycleData.nextStart) {
      // the first cycle will account for an offset to allow adjusting the start day
      if (block.timestamp < _cycleData.nextStart + _cycleData.nextDuration + _cycleData.offset) {
        return (uint256(_cycleData.nextStart), uint256(_cycleData.nextDuration + _cycleData.offset));
      }
      return (uint256(_cycleData.nextStart + _cycleData.offset), uint256(_cycleData.nextDuration));
    }
    return (uint256(_cycleData.previousStart), uint256(_cycleData.previousDuration));
  }

  // -----------------------------
  // ---- Internal Functions -----
  // -----------------------------

  /**
   * @notice checks if the distribution and cycle duration are valid
   * @param distributionDuration_ duration of the distribution window
   * @param cycleDuration_ cycle time duration
   * @return true if the distribution duration is less than half of the cycle duration
   */
  function _isValidDistributionToCycleRatio(
    uint32 distributionDuration_,
    uint32 cycleDuration_
  ) internal pure returns (bool) {
    return cycleDuration_ >= distributionDuration_ * 2;
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
