// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

contract TimeManager is Test {
    uint256 public timestamp;

    constructor() {
        timestamp = block.timestamp;
    }

    function increaseTimestamp(uint256 skipTime_) external {
        timestamp += skipTime_;
        vm.warp(timestamp);
    }
}
