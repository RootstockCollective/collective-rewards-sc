// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ChangeExecutorRootstockCollective } from "src/governance/ChangeExecutorRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run()
        public
        returns (ChangeExecutorRootstockCollective proxy_, ChangeExecutorRootstockCollective implementation_)
    {
        address _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");

        (proxy_, implementation_) = run(_governorAddress);
    }

    function run(address governor_)
        public
        broadcast
        returns (ChangeExecutorRootstockCollective, ChangeExecutorRootstockCollective)
    {
        require(governor_ != address(0), "Governor address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(ChangeExecutorRootstockCollective.initialize, (governor_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new ChangeExecutorRootstockCollective());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (ChangeExecutorRootstockCollective(_proxy), ChangeExecutorRootstockCollective(_implementation));
        }
        _implementation = address(new ChangeExecutorRootstockCollective{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (ChangeExecutorRootstockCollective(_proxy), ChangeExecutorRootstockCollective(_implementation));
    }
}
