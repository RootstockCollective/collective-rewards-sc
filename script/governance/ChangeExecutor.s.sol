// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (ChangeExecutor) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        return run(governorAddress);
    }

    function run(address governor_) public broadcast returns (ChangeExecutor) {
        require(governor_ != address(0), "Governor address cannot be empty");

        string memory _contractName = "ChangeExecutor.sol";
        bytes memory _initializerData = abi.encodeCall(ChangeExecutor.initialize, (governor_));
        if (vm.envOr("NO_DD", false)) {
            return ChangeExecutor(_deployUUPSProxy(_contractName, _initializerData));
        }
        return ChangeExecutor(_deployUUPSProxyDD(_contractName, _initializerData, _salt));
    }
}
