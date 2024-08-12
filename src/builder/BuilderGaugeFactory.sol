// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BuilderGauge } from "./BuilderGauge.sol";

contract BuilderGaugeFactory {
    function createBuilderGauge(address builder_, address rewardToken_) external returns (BuilderGauge) {
        return new BuilderGauge(builder_, rewardToken_, msg.sender);
    }
}
