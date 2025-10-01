// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library UtilsLib {
    // Constants may not be used in child contracts and that is fine as they are
    // not using any space in storage, so we disable the check
    // COINBASE_ADDRESS is used to represent the native token address. COINBASE_ADDRESS string is used for legacy
    // reasons and should not be changed.
    // slither-disable-next-line unused-state
    uint256 internal constant _PRECISION = 10 ** 18;
    address internal constant _NATIVE_ADDRESS = address(uint160(uint256(keccak256("COINBASE_ADDRESS"))));
    uint256 public constant MIN_AMOUNT_INCENTIVES = 100;

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
     * @notice calculates when an cycle ends or the next one starts based on given `cycleDuration_` and a `timestamp_`
     * @param cycleStart_ Collective Rewards cycle start timestamp
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @param timestamp_ timestamp to calculate
     * @return cycleNext timestamp when the cycle ends or the next starts
     */
    function _calcCycleNext(
        uint256 cycleStart_,
        uint256 cycleDuration_,
        uint256 timestamp_
    )
        internal
        pure
        returns (uint256)
    {
        unchecked {
            return timestamp_ + _calcTimeUntilNextCycle(cycleStart_, cycleDuration_, timestamp_);
        }
    }

    /**
     * @notice calculates the time left until the next cycle based on given `cycleDuration_` and a `timestamp_`
     * @param cycleStart_ Collective Rewards cycle start timestamp
     * @param cycleDuration_ Collective Rewards cycle time duration
     * @param timestamp_ timestamp to calculate
     * @return timeUntilNextCycle amount of time until next cycle
     */
    function _calcTimeUntilNextCycle(
        uint256 cycleStart_,
        uint256 cycleDuration_,
        uint256 timestamp_
    )
        internal
        pure
        returns (uint256)
    {
        uint256 _timeSinceStart = timestamp_ - cycleStart_;
        unchecked {
            return cycleDuration_ - (_timeSinceStart % cycleDuration_);
        }
    }
}
