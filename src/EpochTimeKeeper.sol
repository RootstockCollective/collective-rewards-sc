// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Upgradeable } from "./governance/Upgradeable.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { IGovernanceManager } from "./interfaces/IGovernanceManager.sol";

abstract contract EpochTimeKeeper is Upgradeable {
    uint256 internal constant _DISTRIBUTION_WINDOW = 1 hours;

    // -----------------------------
    // ------- Custom Errors -------
    // -----------------------------
    error EpochDurationTooShort();
    error EpochDurationsAreNotMultiples();
    error EpochDurationNotHourBasis();

    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewEpochDurationScheduled(uint256 newEpochDuration_, uint256 cooldownEndTime_);

    // -----------------------------
    // ---------- Structs ----------
    // -----------------------------
    struct EpochData {
        // previous epoch duration
        uint32 previousDuration;
        // next epoch duration
        uint32 nextDuration;
        // after this time, new epoch duration will be applied
        uint64 previousStart;
        // after this time, next epoch duration will be applied
        uint64 nextStart;
        // offset to add to the first epoch, used to set an specific day to start the epochs
        uint24 offset;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------
    /// @notice epoch data
    EpochData public epochData;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @dev the first epoch will end in epochDuration_ + epochStartOffset_ seconds to to ensure that
     *  it lasts at least as long as the desired period
     * @param governanceManager_ contract with permissioned roles
     * @param epochDuration_ epoch time duration
     * @param epochStartOffset_ offset to add to the first epoch, used to set an specific day to start the epochs
     */
    function __EpochTimeKeeper_init(
        IGovernanceManager governanceManager_,
        uint32 epochDuration_,
        uint24 epochStartOffset_
    )
        internal
        onlyInitializing
    {
        __Upgradeable_init(governanceManager_);

        // read from store
        EpochData memory _epochData = epochData;

        _epochData.previousDuration = epochDuration_;
        _epochData.nextDuration = epochDuration_;
        _epochData.previousStart = uint64(block.timestamp);
        _epochData.nextStart = uint64(block.timestamp);
        _epochData.offset = epochStartOffset_;

        // write to storage
        epochData = _epochData;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice schedule a new epoch duration. It will be applied for the next epoch
     * @dev reverts if is too short. It must be greater than 2 time the distribution window
     * @param newEpochDuration_ new epoch duration
     * @param epochStartOffset_ offset to add to the first epoch, used to set an specific day to start the epochs
     */
    function setEpochDuration(uint32 newEpochDuration_, uint24 epochStartOffset_) external onlyValidChanger {
        if (newEpochDuration_ < 2 * _DISTRIBUTION_WINDOW) revert EpochDurationTooShort();

        (uint256 _start, uint256 _duration) = getEpochStartAndDuration();
        // read from store
        EpochData memory _epochData = epochData;

        _epochData.previousDuration = uint32(_duration);
        _epochData.nextDuration = newEpochDuration_;
        _epochData.previousStart = uint64(_start);
        _epochData.nextStart =
            uint64(UtilsLib._calcEpochNext(_epochData.previousStart, _epochData.previousDuration, block.timestamp));
        _epochData.offset = epochStartOffset_;

        emit NewEpochDurationScheduled(newEpochDuration_, _epochData.nextStart);

        // write to storage
        epochData = _epochData;
    }

    /**
     * @notice gets when an epoch starts based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return epochStart timestamp when the epoch starts
     */
    function epochStart(uint256 timestamp_) public view returns (uint256) {
        (uint256 _start, uint256 _duration) = getEpochStartAndDuration();
        uint256 _timeSinceStart = timestamp_ - _start;
        unchecked {
            return timestamp_ - (_timeSinceStart % _duration);
        }
    }

    /**
     * @notice gets when an epoch ends or the next one starts based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return epochNext timestamp when the epoch ends or the next starts
     */
    function epochNext(uint256 timestamp_) public view returns (uint256) {
        (uint256 _start, uint256 _duration) = getEpochStartAndDuration();
        return UtilsLib._calcEpochNext(_start, _duration, timestamp_);
    }

    /**
     * @notice gets when an epoch distribution ends based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return endDistributionWindow timestamp when the epoch distribution ends
     */
    function endDistributionWindow(uint256 timestamp_) public view returns (uint256) {
        return epochStart(timestamp_) + _DISTRIBUTION_WINDOW;
    }

    /**
     * @notice gets time left until the next epoch based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return timeUntilNextEpoch amount of time until next epoch
     */
    function timeUntilNextEpoch(uint256 timestamp_) public view returns (uint256) {
        (uint256 _start, uint256 _duration) = getEpochStartAndDuration();
        return UtilsLib._calcTimeUntilNextEpoch(_start, _duration, timestamp_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice returns epoch start and duration
     *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
     */
    function getEpochStartAndDuration() public view returns (uint256, uint256) {
        EpochData memory _epochData = epochData;
        if (block.timestamp >= _epochData.nextStart) {
            // the first epoch will account for an offset to allow adjusting the start day
            if (block.timestamp < _epochData.nextStart + _epochData.nextDuration + _epochData.offset) {
                return (uint256(_epochData.nextStart), uint256(_epochData.nextDuration + _epochData.offset));
            }
            return (uint256(_epochData.nextStart + _epochData.offset), uint256(_epochData.nextDuration));
        }
        return (uint256(_epochData.previousStart), uint256(_epochData.previousDuration));
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
