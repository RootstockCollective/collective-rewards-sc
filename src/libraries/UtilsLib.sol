// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

library UtilsLib {
    // Constants may not be used in child contracts and that is fine as they are
    // not using any space in storage, so we disable the check
    // slither-disable-next-line unused-state
    uint256 internal constant _PRECISION = 10 ** 18;
    address internal constant _COINBASE_ADDRESS = address(uint160(uint256(keccak256("COINBASE_ADDRESS"))));

    // Saves gas
    // https://github.com/KadenZipfel/gas-optimizations/blob/main/gas-saving-patterns/unchecked-arithmetic.md
    function _uncheckedInc(uint256 i_) internal pure returns (uint256) {
        unchecked {
            return i_ + 1;
        }
    }

    /**
     * @notice add precision and div two number
     * @param a_ numerator
     * @param b_ denominator
     * @return `a_` * PRECISION / `b_`
     */
    function _divPrec(uint256 a_, uint256 b_) internal pure returns (uint256) {
        return (a_ * _PRECISION) / b_;
    }

    /**
     * @notice multiply two number and remove precision
     * @param a_ term 1
     * @param b_ term 2
     * @return `a_` * `b_` / PRECISION
     */
    function _mulPrec(uint256 a_, uint256 b_) internal pure returns (uint256) {
        return (a_ * b_) / _PRECISION;
    }

    /**
     * @notice calculates when an epoch ends or the next one starts based on given `epochDuration_` and a `timestamp_`
     * @param epochStart_ epoch start timestamp
     * @param epochDuration_ epoch time duration
     * @param timestamp_ timestamp to calculate
     * @return epochNext timestamp when the epoch ends or the next starts
     */
    function _calcEpochNext(
        uint256 epochStart_,
        uint256 epochDuration_,
        uint256 timestamp_
    )
        internal
        pure
        returns (uint256)
    {
        unchecked {
            return timestamp_ + _calcTimeUntilNextEpoch(epochStart_, epochDuration_, timestamp_);
        }
    }

    /**
     * @notice calculates the time left until the next epoch based on given `epochDuration_` and a `timestamp_`
     * @param epochStart_ epoch start timestamp
     * @param epochDuration_ epoch time duration
     * @param timestamp_ timestamp to calculate
     * @return timeUntilNextEpoch amount of time until next epoch
     */
    function _calcTimeUntilNextEpoch(
        uint256 epochStart_,
        uint256 epochDuration_,
        uint256 timestamp_
    )
        internal
        pure
        returns (uint256)
    {
        uint256 _timeSinceStart = timestamp_ - epochStart_;
        unchecked {
            return epochDuration_ - (_timeSinceStart % epochDuration_);
        }
    }
}
