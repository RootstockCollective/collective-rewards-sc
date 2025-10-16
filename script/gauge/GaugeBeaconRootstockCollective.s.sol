// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { GaugeBeaconRootstockCollective } from "src/gauge/GaugeBeaconRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeBeaconRootstockCollective) {
        address _governanceManager = vm.envOr("GovernanceManagerRootstockCollective", address(0));
        if (_governanceManager == address(0)) {
            _governanceManager = vm.envAddress("GOVERNANCE_MANAGER_ADDRESS");
        }
        return run(_governanceManager);
    }

    function run(address governanceManager_) public broadcast returns (GaugeBeaconRootstockCollective) {
        require(governanceManager_ != address(0), "Change executor address cannot be empty");
        address _gaugeImplementation = address(new GaugeRootstockCollective());
        if (vm.envOr("NO_DD", false)) {
            return new GaugeBeaconRootstockCollective(
                IGovernanceManagerRootstockCollective(governanceManager_), _gaugeImplementation
            );
        }
        return new GaugeBeaconRootstockCollective{
            salt: _salt
        }(IGovernanceManagerRootstockCollective(governanceManager_), _gaugeImplementation);
    }
}
