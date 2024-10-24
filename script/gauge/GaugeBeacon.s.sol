// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { Gauge } from "src/gauge/Gauge.sol";
import { GaugeBeacon } from "src/gauge/GaugeBeacon.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeBeacon) {
        address _changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        if (_changeExecutorAddress == address(0)) {
            _changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        return run(_changeExecutorAddress);
    }

    function run(address changeExecutor_) public broadcast returns (GaugeBeacon) {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        address _gaugeImplementation = address(new Gauge());
        if (vm.envOr("NO_DD", false)) {
            return new GaugeBeacon(changeExecutor_, _gaugeImplementation);
        }
        return new GaugeBeacon{ salt: _salt }(changeExecutor_, _gaugeImplementation);
    }
}
