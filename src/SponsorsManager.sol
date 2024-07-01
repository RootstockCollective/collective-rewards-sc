// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GaugeFactory } from "./gauge/GaugeFactory.sol";

contract SponsorsManager {
    IERC20 public immutable rewardToken;
    GaugeFactory public immutable gaugeFactory;

    constructor(address rewardToken_, address gaugeFactory_) {
        rewardToken = IERC20(rewardToken_);
        gaugeFactory = GaugeFactory(gaugeFactory_);
    }

    function createGauge() external returns (address) {
        return gaugeFactory.createGauge(address(rewardToken));
    }
}
