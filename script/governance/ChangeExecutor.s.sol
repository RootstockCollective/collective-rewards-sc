// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";

contract Deploy is Broadcaster {
    function run() public returns (ChangeExecutor changeExecutor) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        changeExecutor = run(governorAddress);
    }

    function run(address governor) public broadcast returns (ChangeExecutor changeExecutor) {
        require(governor != address(0), "Governor address cannot be empty");

        changeExecutor = new ChangeExecutor{ salt: _salt }(governor);
    }
}
