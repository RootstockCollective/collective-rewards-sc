// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { GaugeBeacon } from "src/gauge/GaugeBeacon.sol";
import { IGovernanceManager } from "../../src/interfaces/IGovernanceManager.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeBeacon) {
        address _governanceManager = vm.envOr("GovernanceManager", address(0));
        if (_governanceManager == address(0)) {
            _governanceManager = vm.envAddress("GOVERNANCE_MANAGER_ADDRESS");
        }
        return run(_governanceManager);
    }

    function run(address governanceManager_) public broadcast returns (GaugeBeacon) {
        require(governanceManager_ != address(0), "Change executor address cannot be empty");
        address _gaugeImplementation = address(new GaugeRootstockCollective());
        if (vm.envOr("NO_DD", false)) {
            return new GaugeBeacon(IGovernanceManager(governanceManager_), _gaugeImplementation);
        }
        return new GaugeBeacon{ salt: _salt }(IGovernanceManager(governanceManager_), _gaugeImplementation);
    }
}
