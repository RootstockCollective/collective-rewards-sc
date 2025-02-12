// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { MigrationV2 } from "src/migrations/v2/MigrationV2.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";

contract MigrationV2Deployer is Broadcaster, OutputWriter {
    function run() public returns (MigrationV2 migrationV2_) {
        outputWriterSetup();
        address _backersManager = vm.envOr("BackersManagerRootstockCollectiveProxy", address(0));
        if (_backersManager == address(0)) {
            _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        }
        migrationV2_ = run(_backersManager, true);
    }

    function run(address backersManager_, bool writeDeployment_) public broadcast returns (MigrationV2 migrationV2_) {
        require(backersManager_ != address(0), "Backers Manager address cannot be empty");

        BuilderRegistryRootstockCollective _builderRegistryImp = new BuilderRegistryRootstockCollective();
        BackersManagerRootstockCollective _backersManagerImp = new BackersManagerRootstockCollective();
        migrationV2_ = new MigrationV2(backersManager_, _builderRegistryImp, _backersManagerImp);

        if (!writeDeployment_) return migrationV2_;

        persistOutputJson();
        save("BuilderRegistryRootstockCollective", address(_builderRegistryImp));
        save("BuilderRegistryRootstockCollectiveProxy", address(migrationV2_.builderRegistry()));
        save("BackersManagerRootstockCollective", address(_backersManagerImp));
        save("GaugeRootstockCollectiveImplementation", address(migrationV2_.gaugeImplementation()));
        save("MigrationV2", address(migrationV2_));
    }
}
