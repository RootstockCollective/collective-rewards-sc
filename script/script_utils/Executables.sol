// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice The executables used in ffi commands. These are set here
///         to have a single source of truth in case absolute paths
///         need to be used.
library Executables {
    string internal constant BASH = "BASH";
    string internal constant JQ = "JQ";
    string internal constant FORGE = "FORGE";
    string internal constant ECHO = "ECHO";
    string internal constant SED = "SED";
    string internal constant FIND = "FIND";
    string internal constant LS = "LS";
}
