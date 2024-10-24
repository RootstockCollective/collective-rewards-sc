// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { IGoverned } from "../src/interfaces/IGoverned.sol";

contract Deploy is Broadcaster {
    function run() public returns (RewardDistributor proxy_, RewardDistributor implementation_) {
        address _governed = vm.envOr("Governed", address(0));
        if (_governed == address(0)) {
            _governed = vm.envAddress("ACCESS_CONTROL_ADDRESS");
        }

        (proxy_, implementation_) = run(_governed);

        address _sponsorsManagerAddress = vm.envOr("SponsorsManager", address(0));
        if (_sponsorsManagerAddress == address(0)) {
            _sponsorsManagerAddress = vm.envAddress("SPONSORS_MANAGER_ADDRESS");
        }

        proxy_.initializeBIMAddresses(address(_sponsorsManagerAddress));
    }

    function run(address governed_) public broadcast returns (RewardDistributor, RewardDistributor) {
        require(governed_ != address(0), "Access control address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(RewardDistributor.initialize, (IGoverned(governed_)));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new RewardDistributor());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (RewardDistributor(payable(_proxy)), RewardDistributor(payable(_implementation)));
        }
        _implementation = address(new RewardDistributor{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (RewardDistributor(payable(_proxy)), RewardDistributor(payable(_implementation)));
    }
}
