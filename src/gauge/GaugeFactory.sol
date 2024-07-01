// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Gauge } from "./Gauge.sol";

contract GaugeFactory {
    function createGauge(address rewardToken_) external returns (address gauge) {
        gauge = address(new Gauge(rewardToken_, msg.sender));
    }
}
