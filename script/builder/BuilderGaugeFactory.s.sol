// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { BuilderGaugeFactory } from "src/builder/BuilderGaugeFactory.sol";

contract Deploy is Broadcaster {
    function run() public broadcast returns (BuilderGaugeFactory) {
        if (vm.envOr("NO_DD", false)) {
            return new BuilderGaugeFactory();
        }
        return new BuilderGaugeFactory{ salt: _salt }();
    }
}
