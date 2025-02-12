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

    function getPath(string memory fileName_) public pure returns (string memory) {
        return string.concat(dataPath, "/", fileName_, ".json");
    }

    function getVersionedPath(string memory fileName_) public view returns (string memory) {
        return getPath(string.concat(fileName_, version));
    }
}
