// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (BuilderRegistry proxy_, BuilderRegistry implementation_) {
        address _kycApprover = vm.envAddress("KYC_APPROVER_ADDRESS");
        address _changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        if (_changeExecutorAddress == address(0)) {
            _changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }

        (proxy_, implementation_) = run(_changeExecutorAddress, _kycApprover);
    }

    function run(
        address changeExecutor_,
        address kycApprover_
    )
        public
        broadcast
        returns (BuilderRegistry, BuilderRegistry)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(kycApprover_ != address(0), "KYC Approver address cannot be empty");
        string memory _contractName = "BuilderRegistry.sol";
        bytes memory _initializerData = abi.encodeCall(BuilderRegistry.initialize, (changeExecutor_, kycApprover_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            (_proxy, _implementation) = _deployUUPSProxy(_contractName, _initializerData);

            return (BuilderRegistry(_proxy), BuilderRegistry(_implementation));
        }
        (_proxy, _implementation) = _deployUUPSProxyDD(_contractName, _initializerData, _salt);

        return (BuilderRegistry(_proxy), BuilderRegistry(_implementation));
    }
}
