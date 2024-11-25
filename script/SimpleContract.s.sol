// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { SimpleContract } from "src/SimpleContract.sol";

contract Deploy is Broadcaster {
    function run() public broadcast returns (SimpleContract) {
        return new SimpleContract();
    }
}
