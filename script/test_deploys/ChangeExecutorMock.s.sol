// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ChangeExecutorMock } from "test/mock/ChangeExecutorMock.sol";

contract Deploy is Broadcaster {
    function run() public returns (ChangeExecutorMock mockChangeExecutor) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        mockChangeExecutor = run(governorAddress);
    }

    function run(address governorAddress) public broadcast returns (ChangeExecutorMock mockChangeExecutor) {
        mockChangeExecutor = new ChangeExecutorMock(governorAddress);
    }
}
