// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (ChangeExecutor proxy_, ChangeExecutor implementation_) {
        address _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");

        (proxy_, implementation_) = run(_governorAddress);
    }

    function run(address governor_) public broadcast returns (ChangeExecutor, ChangeExecutor) {
        require(governor_ != address(0), "Governor address cannot be empty");

        string memory _contractName = "ChangeExecutor.sol";
        bytes memory _initializerData = abi.encodeCall(ChangeExecutor.initialize, (governor_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            (_proxy, _implementation) = _deployUUPSProxy(_contractName, _initializerData);

            return (ChangeExecutor(_proxy), ChangeExecutor(_implementation));
        }
        (_proxy, _implementation) = _deployUUPSProxyDD(_contractName, _initializerData, _salt);

        return (ChangeExecutor(_proxy), ChangeExecutor(_implementation));
    }
}
