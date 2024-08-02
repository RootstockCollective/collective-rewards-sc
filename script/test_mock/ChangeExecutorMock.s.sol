// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ChangeExecutorMock } from "test/mock/ChangeExecutorMock.sol";

contract Deploy is Broadcaster {
    function run() public returns (ChangeExecutorMock) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        return run(governorAddress);
    }

    function run(address governorAddress) public broadcast returns (ChangeExecutorMock) {
        if (vm.envOr("NO_DD", false)) {
            return new ChangeExecutorMock(governorAddress);
        }
        return new ChangeExecutorMock{ salt: _salt }(governorAddress);
    }
}
