// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import { IGaugeFactory } from "../interfaces/factories/IGaugeFactory.sol";
import { Gauge } from "../gauges/Gauge.sol";

contract GaugeFactory is IGaugeFactory {
    function createGauge(address _stakingToken, address _rewardToken) external returns (address gauge) {
        gauge = address(new Gauge(_stakingToken, _rewardToken, msg.sender));
    }
}
