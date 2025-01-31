// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { MigrationV2 } from "src/upgrade/MigrationV2.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";

contract MigrationV2Deployer is Broadcaster {
    function run() public returns (MigrationV2 migrationV2_) {
        address _backersManager = vm.envOr("BackersManagerRootstockCollective", address(0));
        if (_backersManager == address(0)) {
            _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        }
        migrationV2_ = run(_backersManager);
    }

    function run(address backersManager_) public broadcast returns (MigrationV2 migrationV2_) {
        require(backersManager_ != address(0), "Backers Manager address cannot be empty");

        BuilderRegistryRootstockCollective _builderRegistryImp = new BuilderRegistryRootstockCollective();
        BackersManagerRootstockCollective _backersManagerImp = new BackersManagerRootstockCollective();
        migrationV2_ = new MigrationV2(backersManager_, _builderRegistryImp, _backersManagerImp);
    }
}
