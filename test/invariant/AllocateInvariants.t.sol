// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseInvariants, Gauge } from "./BaseInvariants.sol";

contract AllocateInvariants is BaseInvariants {
    /**
     * SCENARIO: totalPotentialReward is the sum of all gauges's reward shares
     */
    function invariant_TotalPotentialRewards() public useTime {
        uint256 _expectedTotalPotentialReward;
        for (uint256 i = 0; i < sponsorsManager.getGaugesLength(); i++) {
            _expectedTotalPotentialReward += Gauge(sponsorsManager.getGaugeAt(i)).rewardShares();
        }
        assertEq(sponsorsManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }
}
