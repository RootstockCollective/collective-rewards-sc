// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { Gauge } from "src/gauge/Gauge.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract Deploy is Broadcaster {
    function run() public returns (UpgradeableBeacon) {
        address _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        return run(_governorAddress);
    }

    function run(address governor_) public broadcast returns (UpgradeableBeacon) {
        require(governor_ != address(0), "Governor address cannot be empty");
        address _gaugeImplementation = address(new Gauge());
        if (vm.envOr("NO_DD", false)) {
            return new UpgradeableBeacon(_gaugeImplementation, governor_);
        }
        return new UpgradeableBeacon{ salt: _salt }(_gaugeImplementation, governor_);
    }
}
