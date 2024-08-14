// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Copied from https://github.com/rsksmart/optimism/blob/develop/packages/contracts-bedrock/scripts/Executables.sol

/// @notice The executables used in ffi commands. These are set here
///         to have a single source of truth in case absolute paths
///         need to be used.
library Executables {
    string internal constant _BASH = "BASH";
    string internal constant _JQ = "JQ";
    string internal constant _FORGE = "FORGE";
    string internal constant _ECHO = "ECHO";
    string internal constant _SED = "SED";
    string internal constant _FIND = "FIND";
    string internal constant _LS = "LS";
}
