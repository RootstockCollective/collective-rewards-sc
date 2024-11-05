// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeFactoryRootstockCollective) {
        address _beaconAddress = vm.envOr("GaugeBeaconRootstockCollective", address(0));
        address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        if (_beaconAddress == address(0)) {
            _beaconAddress = vm.envAddress("BEACON_ADDRESS");
        }
        return run(_beaconAddress, _rewardTokenAddress);
    }

    function run(address beacon_, address rewardToken_) public broadcast returns (GaugeFactoryRootstockCollective) {
        require(beacon_ != address(0), "Beacon address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        if (vm.envOr("NO_DD", false)) {
            return new GaugeFactoryRootstockCollective(beacon_, rewardToken_);
        }
        return new GaugeFactoryRootstockCollective{ salt: _salt }(beacon_, rewardToken_);
    }
}
