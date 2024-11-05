// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Upgradeable } from "./governance/Upgradeable.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { IGovernanceManager } from "./interfaces/IGovernanceManager.sol";

abstract contract CycleTimeKeeper is Upgradeable {
    uint256 internal constant _DISTRIBUTION_WINDOW = 1 hours;

    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error CycleDurationTooShort();
    error CycleDurationsAreNotMultiples();
    error CycleDurationNotHourBasis();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_);

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
     */
    function __CycleTimeKeeper_init(
        IGovernanceManager governanceManager_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_
    )
        internal
        onlyInitializing
    {
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
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice schedule a new cycle duration. It will be applied for the next cycle
     * @dev reverts if is too short. It must be greater than 2 time the distribution window
     * @param newCycleDuration_ new cycle duration
     * @param cycleStartOffset_ offset to add to the first cycle, used to set an specific day to start the cycles
     */
    function setCycleDuration(uint32 newCycleDuration_, uint24 cycleStartOffset_) external onlyValidChanger {
        if (newCycleDuration_ < 2 * _DISTRIBUTION_WINDOW) revert CycleDurationTooShort();

        (uint256 _start, uint256 _duration) = getCycleStartAndDuration();
        // read from store
        CycleData memory _cycleData = cycleData;

        _cycleData.previousDuration = uint32(_duration);
        _cycleData.nextDuration = newCycleDuration_;
        _cycleData.previousStart = uint64(_start);
        _cycleData.nextStart =
            uint64(UtilsLib._calcCycleNext(_cycleData.previousStart, _cycleData.previousDuration, block.timestamp));
        _cycleData.offset = cycleStartOffset_;

        emit NewCycleDurationScheduled(newCycleDuration_, _cycleData.nextStart);

        // write to storage
        cycleData = _cycleData;
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
        return cycleStart(timestamp_) + _DISTRIBUTION_WINDOW;
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

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
