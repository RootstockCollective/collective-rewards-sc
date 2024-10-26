// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { Gauge } from "src/gauge/Gauge.sol";
import { GaugeBeacon } from "src/gauge/GaugeBeacon.sol";
import { IGovernanceManager } from "../../src/interfaces/IGovernanceManager.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeBeacon) {
        address _governanceManager = vm.envAddress("ACCESS_CONTROL_ADDRESS");
        return run(_governanceManager);
    }

    function run(address governanceManager_) public broadcast returns (GaugeBeacon) {
        require(governanceManager_ != address(0), "Change executor address cannot be empty");
        address _gaugeImplementation = address(new Gauge());
        if (vm.envOr("NO_DD", false)) {
            return new GaugeBeacon(IGovernanceManager(governanceManager_), _gaugeImplementation);
        }
        return new GaugeBeacon{ salt: _salt }(IGovernanceManager(governanceManager_), _gaugeImplementation);
    }
}
