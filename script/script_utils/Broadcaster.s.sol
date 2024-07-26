// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";

/// @dev Needed for the deterministic deployments.
bytes32 constant ZERO_SALT = bytes32(0);

abstract contract Broadcaster is Script {
    bytes32 internal _salt = ZERO_SALT;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
