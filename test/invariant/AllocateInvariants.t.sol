// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseInvariants } from "./BaseInvariants.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";

contract AllocateInvariants is BaseInvariants {
    /**
     * SCENARIO: totalPotentialReward is the sum of all gauges's reward shares
     */
    function invariant_TotalPotentialRewards() public useTime {
        uint256 _expectedTotalPotentialReward;
        for (uint256 i = 0; i < backersManager.getGaugesLength(); i++) {
            _expectedTotalPotentialReward += GaugeRootstockCollective(backersManager.getGaugeAt(i)).rewardShares();
        }
        assertEq(backersManager.totalPotentialReward(), _expectedTotalPotentialReward);
    }
}
