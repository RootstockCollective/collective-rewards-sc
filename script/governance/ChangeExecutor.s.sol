// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";

contract Deploy is Broadcaster {
    function run() public returns (ChangeExecutor) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        return run(governorAddress);
    }

    function run(address governor) public broadcast returns (ChangeExecutor) {
        require(governor != address(0), "Governor address cannot be empty");

        if (vm.envOr("NO_DD", false)) {
            return new ChangeExecutor(governor);
        }
        return new ChangeExecutor{ salt: _salt }(governor);
    }
}
