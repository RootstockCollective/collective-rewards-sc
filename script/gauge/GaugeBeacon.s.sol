// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { Gauge } from "src/gauge/Gauge.sol";
import { GaugeBeacon } from "src/gauge/GaugeBeacon.sol";
import { IGoverned } from "../../src/interfaces/IGoverned.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeBeacon) {
        address _governed = vm.envAddress("ACCESS_CONTROL_ADDRESS");
        return run(_governed);
    }

    function run(address governed_) public broadcast returns (GaugeBeacon) {
        require(governed_ != address(0), "Change executor address cannot be empty");
        address _gaugeImplementation = address(new Gauge());
        if (vm.envOr("NO_DD", false)) {
            return new GaugeBeacon(IGoverned(governed_), _gaugeImplementation);
        }
        return new GaugeBeacon{ salt: _salt }(IGoverned(governed_), _gaugeImplementation);
    }
}
