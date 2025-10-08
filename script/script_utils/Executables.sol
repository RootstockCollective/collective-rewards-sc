// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Copied from https://github.com/rsksmart/optimism/blob/develop/packages/contracts-bedrock/scripts/Executables.sol

/// @notice The executables used in ffi commands. These are set here
///         to have a single source of truth in case absolute paths
///         need to be used.
library Executables {
    string internal constant _BASH = "bash";
    string internal constant _JQ = "jq";
    string internal constant _FORGE = "forge";
    string internal constant _ECHO = "echo";
    string internal constant _SED = "sed";
    string internal constant _FIND = "find";
    string internal constant _LS = "ls";
}
