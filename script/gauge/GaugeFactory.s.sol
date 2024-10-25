// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeFactory) {
        address _beaconAddress = vm.envOr("GaugeBeacon", address(0));
        address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        if (_beaconAddress == address(0)) {
            _beaconAddress = vm.envAddress("BEACON_ADDRESS");
        }
        return run(_beaconAddress, _rewardTokenAddress);
    }

    function run(address beacon_, address rewardToken_) public broadcast returns (GaugeFactory) {
        require(beacon_ != address(0), "Beacon address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        if (vm.envOr("NO_DD", false)) {
            return new GaugeFactory(beacon_, rewardToken_);
        }
        return new GaugeFactory{ salt: _salt }(beacon_, rewardToken_);
    }
}
