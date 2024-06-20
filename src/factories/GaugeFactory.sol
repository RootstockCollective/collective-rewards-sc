// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import { IGaugeFactory } from "../interfaces/factories/IGaugeFactory.sol";
import { Gauge } from "../gauges/Gauge.sol";

contract GaugeFactory is IGaugeFactory {
    function createGauge(address _rewardToken) external returns (address gauge) {
        gauge = address(new Gauge(_rewardToken, msg.sender));
    }
}
