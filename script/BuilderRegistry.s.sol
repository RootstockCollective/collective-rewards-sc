// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";

contract Deploy is Broadcaster {
    function run() public returns (BuilderRegistry builderRegistry) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        address changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        address kycApprover = vm.envAddress("KYC_APPROVER_ADDRESS");
        builderRegistry = run(governorAddress, changeExecutorAddress, kycApprover);
    }

    function run(
        address governor,
        address changeExecutor,
        address kycApprover
    )
        public
        broadcast
        returns (BuilderRegistry builderRegistry)
    {
        require(governor != address(0), "Governor address cannot be empty");
        require(changeExecutor != address(0), "Change executor address cannot be empty");
        require(kycApprover != address(0), "KYC Approver address cannot be empty");

        builderRegistry = new BuilderRegistry(governor, changeExecutor, kycApprover);
    }
}
