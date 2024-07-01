// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";

contract GaugeTest is BaseTest {
    function test_alwaysTrue() public pure {
        assertEq(true, true);
    }
}
