// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";

abstract contract Broadcaster is Script {
    // /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    // string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    // /// @dev Needed for the deterministic deployments.
    // bytes32 internal constant ZERO_SALT = bytes32(0); // TODO: presumably we want to use create2 opcode, which is not
    // a predeploy on regtest and using cast publish fails due to effectiveGasPrice not being a RPC method on RSKj

    modifier broadcast() {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
