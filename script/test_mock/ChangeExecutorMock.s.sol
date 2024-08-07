// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { ChangeExecutorMock } from "test/mock/ChangeExecutorMock.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (ChangeExecutorMock implementation, ChangeExecutorMock proxy) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");

        (implementation, proxy) = run(governorAddress);
    }

    function run(address governorAddress_) public broadcast returns (ChangeExecutorMock, ChangeExecutorMock) {
        string memory _contractName = "ChangeExecutorMock.sol";
        bytes memory _initializerData = abi.encodeCall(ChangeExecutor.initialize, (governorAddress_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            (_implementation, _proxy) = _deployUUPSProxy(_contractName, _initializerData);

            return (ChangeExecutorMock(_implementation), ChangeExecutorMock(_proxy));
        }
        (_implementation, _proxy) = _deployUUPSProxyDD(_contractName, _initializerData, _salt);

        return (ChangeExecutorMock(_implementation), ChangeExecutorMock(_proxy));
    }
}
