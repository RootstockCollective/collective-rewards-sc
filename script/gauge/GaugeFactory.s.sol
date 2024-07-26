// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";

contract Deploy is Broadcaster {
    function run() public broadcast returns (GaugeFactory gaugeFactory) {
        gaugeFactory = new GaugeFactory{ salt: _salt }();
    }
}
