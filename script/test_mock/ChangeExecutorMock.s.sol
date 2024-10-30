// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ChangeExecutorMock } from "test/mock/ChangeExecutorMock.sol";
import { ChangeExecutorRootstockCollective } from "src/mvp/ChangeExecutorRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run() public returns (ChangeExecutorMock proxy_, ChangeExecutorMock implementation_) {
        address _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");

        (proxy_, implementation_) = run(_governorAddress);
    }

    function run(address governorAddress_) public broadcast returns (ChangeExecutorMock, ChangeExecutorMock) {
        bytes memory _initializerData = abi.encodeCall(ChangeExecutorRootstockCollective.initialize, (governorAddress_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new ChangeExecutorMock());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (ChangeExecutorMock(_proxy), ChangeExecutorMock(_implementation));
        }
        _implementation = address(new ChangeExecutorMock{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (ChangeExecutorMock(_proxy), ChangeExecutorMock(_implementation));
    }
}
