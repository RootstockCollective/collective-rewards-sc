// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BaseInvariants } from "./BaseInvariants.sol";

contract CycleInvariants is BaseInvariants {
    /**
     * SCENARIO: any new cycle duration and offset can be set
     */
    function invariant_CycleDuration() public useTime {
        (uint256 _start, uint256 _duration) = backersManager.getCycleStartAndDuration();
        uint256 _periodFinish = backersManager.periodFinish();
        if (_periodFinish >= block.timestamp) {
            assertEq((_periodFinish - _start) % _duration, 0);
        }
    }
}
