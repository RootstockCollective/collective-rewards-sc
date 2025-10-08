// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/src/Script.sol";

/// @dev Needed for the deterministic deployments.
bytes32 constant ZERO_SALT = bytes32(0);

abstract contract Broadcaster is Script {
    bytes32 internal _salt;

    modifier broadcast() {
        _salt = vm.envOr("DD_SALT", ZERO_SALT);
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
