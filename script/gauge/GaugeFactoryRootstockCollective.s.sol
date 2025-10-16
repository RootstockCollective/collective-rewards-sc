// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeFactoryRootstockCollective) {
        address _beaconAddress = vm.envOr("GaugeBeaconRootstockCollective", address(0));
        address _rifTokenAddress = vm.envAddress("RIF_TOKEN_ADDRESS");
        address _usdrifTokenAddress = vm.envAddress("USDRIF_TOKEN_ADDRESS");
        if (_beaconAddress == address(0)) {
            _beaconAddress = vm.envAddress("BEACON_ADDRESS");
        }
        return run(_beaconAddress, _rifTokenAddress, _usdrifTokenAddress);
    }

    function run(address beacon_, address rifToken_, address usdrifToken_)
        public
        broadcast
        returns (GaugeFactoryRootstockCollective)
    {
        require(beacon_ != address(0), "Beacon address cannot be empty");
        require(rifToken_ != address(0), "Rif token address cannot be empty");
        require(usdrifToken_ != address(0), "Usdrif token address cannot be empty");
        if (vm.envOr("NO_DD", false)) {
            return new GaugeFactoryRootstockCollective(beacon_, rifToken_, usdrifToken_);
        }
        return new GaugeFactoryRootstockCollective{ salt: _salt }(beacon_, rifToken_, usdrifToken_);
    }
}
