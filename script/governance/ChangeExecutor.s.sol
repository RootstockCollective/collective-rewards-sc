// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";
import { IGovernanceManager } from "../../src/interfaces/IGovernanceManager.sol";

contract Deploy is Broadcaster {
    function run() public returns (ChangeExecutor proxy_, ChangeExecutor implementation_) {
        address _governanceManager = vm.envAddress("ACCESS_CONTROL_ADDRESS");

        (proxy_, implementation_) = run(_governanceManager);
    }

    function run(address governanceManager_) public broadcast returns (ChangeExecutor, ChangeExecutor) {
        require(governanceManager_ != address(0), "Access control address cannot be empty");

        bytes memory _initializerData =
            abi.encodeCall(ChangeExecutor.initialize, (IGovernanceManager(governanceManager_)));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new ChangeExecutor());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (ChangeExecutor(_proxy), ChangeExecutor(_implementation));
        }
        _implementation = address(new ChangeExecutor{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (ChangeExecutor(_proxy), ChangeExecutor(_implementation));
    }
}
