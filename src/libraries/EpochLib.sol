// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

library EpochLib {
    // TODO: is epoch duration fixed?
    uint256 internal constant _WEEK = 7 days;

    /**
     * @notice gets when an epoch starts based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return epochStart timestamp when the epoch starts
     */
    function _epochStart(uint256 timestamp_) internal pure returns (uint256) {
        unchecked {
            return timestamp_ - (timestamp_ % _WEEK);
        }
    }

    /**
     * @notice gets when an epoch ends or the next one starts based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return epochNext timestamp when the epoch ends or the next starts
     */
    function _epochNext(uint256 timestamp_) internal pure returns (uint256) {
        unchecked {
            return timestamp_ - (timestamp_ % _WEEK) + _WEEK;
        }
    }

    /**
     * @notice gets when an epoch distribution ends based on given `timestamp_`
     * @param timestamp_ timestamp to calculate
     * @return endDistributionWindow timestamp when the epoch distribution ends
     */
    function _endDistributionWindow(uint256 timestamp_) internal pure returns (uint256) {
        unchecked {
            return _epochStart(timestamp_) + 1 hours;
        }
    }
}
