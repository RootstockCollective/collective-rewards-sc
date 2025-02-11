// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script } from "forge-std/src/Script.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";

contract MigrationV2Utils is Script {
    BackersManagerRootstockCollective public backersManager;
    BuilderRegistryRootstockCollective public builderRegistry;
    string public version;
    string public constant dataPath = "./script/migrations/v2/data";

    constructor() {
        backersManager = BackersManagerRootstockCollective(vm.envAddress("BACKERS_MANAGER_ADDRESS"));
        try backersManager.builderRegistry() returns (BuilderRegistryRootstockCollective _builderRegistry) {
            builderRegistry = _builderRegistry;
            version = "V2";
        } catch { }
        if (address(builderRegistry) == address(0)) {
            builderRegistry = BuilderRegistryRootstockCollective(address(backersManager));
            version = "V1";
        }
    }

    // Helper function to convert address to string
    function toString(address address_) public pure returns (string memory) {
        bytes32 _value = bytes32(uint256(uint160(address_)));
        bytes memory _alphabet = "0123456789abcdef";
        bytes memory _str = new bytes(42); // 2 characters for "0x" + 40 for the address

        _str[0] = "0";
        _str[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            _str[2 + i * 2] = _alphabet[uint8(_value[i + 12] >> 4)];
            _str[3 + i * 2] = _alphabet[uint8(_value[i + 12] & 0x0f)];
        }

        return string(_str);
    }

    function getPath(string memory fileName_) public pure returns (string memory) {
        return string.concat(dataPath, "/", fileName_, ".json");
    }

    function getVersionedPath(string memory fileName_) public view returns (string memory) {
        return getPath(string.concat(fileName_, version));
    }
}
