// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";

abstract contract Broadcaster is Script {
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
