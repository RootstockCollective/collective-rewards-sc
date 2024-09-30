// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Upgradeable } from "./governance/Upgradeable.sol";
import { UtilsLib } from "./libraries/UtilsLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

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
    struct EpochDurationData {
        // previous epoch duration
        uint64 previous;
        // next epoch duration
        uint64 next;
        // epoch duration cooldown end time. After this time, new epoch duration will be applied
        uint128 cooldownEndTime;
    }

    // -----------------------------
    // ---------- Storage ----------
    // -----------------------------
    /// @notice epoch duration data
    EpochDurationData public epochDuration;

    // -----------------------------
    // ------- Initializer ---------
    // -----------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice contract initializer
     * @param epochDuration_ epoch time duration
     */
    function __EpochTimeKeeper_init(address changeExecutor_, uint64 epochDuration_) internal onlyInitializing {
        __Upgradeable_init(changeExecutor_);

        // read from store
        EpochDurationData memory _epochDuration = epochDuration;

        _epochDuration.previous = epochDuration_;
        _epochDuration.next = epochDuration_;
        _epochDuration.cooldownEndTime = uint128(block.timestamp);

        // write to storage
        epochDuration = _epochDuration;
    }

    // -----------------------------
    // ---- External Functions -----
    // -----------------------------

    /**
     * @notice schedule a new epoch duration. It will be applied for the next epoch
     *   The start and end of an epoch are determined absolutely by timestamps.
     *   As a result, both the new epoch duration and the current epoch duration must be multiples of each other
     *   to ensure synchronization. The transition to the new duration occurs when both periods align
     *   If the new duration is longer: The system waits for the current epoch to end before switching
     *   If the new duration is shorter: The system waits until the current epoch finishes
     *   This approach avoids extra storage or calculations, keeping epoch management efficient.
     * @dev reverts if is too short. It must be greater than 2 time the distribution window
     * @param newEpochDuration_ new epoch duration
     */
    function setEpochDuration(uint64 newEpochDuration_) external onlyGovernorOrAuthorizedChanger {
        if (newEpochDuration_ < 2 * _DISTRIBUTION_WINDOW) revert EpochDurationTooShort();
        if (newEpochDuration_ % 1 hours != 0) revert EpochDurationNotHourBasis();

        uint64 _currentEpochDuration = uint64(getEpochDuration());
        if (_currentEpochDuration % newEpochDuration_ != 0 && newEpochDuration_ % _currentEpochDuration != 0) {
            revert EpochDurationsAreNotMultiples();
        }

        // read from store
        EpochDurationData memory _epochDuration = epochDuration;

        _epochDuration.previous = _currentEpochDuration;
        _epochDuration.next = newEpochDuration_;
        _epochDuration.cooldownEndTime =
            uint128(UtilsLib._calcEpochNext(Math.max(_epochDuration.previous, newEpochDuration_), block.timestamp));

        emit NewEpochDurationScheduled(newEpochDuration_, _epochDuration.cooldownEndTime);

        // write to storage
        epochDuration = _epochDuration;
    }

    /**
     * @notice gets when an epoch starts based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return epochStart timestamp when the epoch starts
     */
    function epochStart(uint256 timestamp_) public view returns (uint256) {
        unchecked {
            return timestamp_ - (timestamp_ % getEpochDuration());
        }
    }

    /**
     * @notice gets when an epoch ends or the next one starts based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return epochNext timestamp when the epoch ends or the next starts
     */
    function epochNext(uint256 timestamp_) public view returns (uint256) {
        return UtilsLib._calcEpochNext(getEpochDuration(), timestamp_);
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
        return UtilsLib._calcTimeUntilNextEpoch(getEpochDuration(), timestamp_);
    }

    // -----------------------------
    // ---- Internal Functions -----
    // -----------------------------

    /**
     * @notice returns epoch duration
     *  If there is a new one and cooldown time has expired, apply that one; otherwise, apply the previous one
     */
    function getEpochDuration() public view returns (uint256) {
        EpochDurationData memory _epochDuration = epochDuration;
        if (block.timestamp >= _epochDuration.cooldownEndTime) {
            return uint256(_epochDuration.next);
        }
        return uint256(_epochDuration.previous);
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
