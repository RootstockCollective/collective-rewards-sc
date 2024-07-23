// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library UtilsLib {
    // Constants may not be used in child contracts and that is fine as they are
    // not using any space in storage, so we disable the check
    // slither-disable-next-line unused-state
    uint256 internal constant PRECISION = 10 ** 18;

    // Saves gas
    // https://github.com/KadenZipfel/gas-optimizations/blob/main/gas-saving-patterns/unchecked-arithmetic.md
    function unchecked_inc(uint256 i_) internal pure returns (uint256) {
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
        return (a_ * PRECISION) / b_;
    }

    /**
     * @notice multiply two number and remove precision
     * @param a_ term 1
     * @param b_ term 2
     * @return `a_` * `b_` / PRECISION
     */
    function _mulPrec(uint256 a_, uint256 b_) internal pure returns (uint256) {
        return (a_ * b_) / PRECISION;
    }
}
