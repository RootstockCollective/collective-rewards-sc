// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseInvariants } from "./BaseInvariants.sol";

contract EpochInvariants is BaseInvariants {
    /**
     * SCENARIO: any new epoch duration and offset can be set
     */
    function invariant_EpochDuration() public useTime {
        (uint256 _start, uint256 _duration) = sponsorsManager.getEpochStartAndDuration();
        uint256 _periodFinish = sponsorsManager.periodFinish();
        if (_periodFinish >= block.timestamp) {
            assertEq((_periodFinish - _start) % _duration, 0);
        }
    }
}
