// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Gauge } from "./Gauge.sol";

contract GaugeFactory {
    function createGauge(address builder_, address rewardToken_) external returns (Gauge gauge_) {
        gauge_ = new Gauge(builder_, rewardToken_, msg.sender);
    }
}
