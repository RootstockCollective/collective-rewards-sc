// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { MigrationV2 } from "src/migrations/v2/MigrationV2.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { IBackersManagerV1 } from "src/interfaces/V1/IBackersManagerV1.sol";

contract MigrationV2Deployer is Broadcaster, OutputWriter {
    function run() public returns (MigrationV2 migrationV2_) {
        outputWriterSetup();
        address _backersManager = vm.envOr("BackersManagerRootstockCollectiveProxy", address(0));
        if (_backersManager == address(0)) {
            _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        }
        migrationV2_ = run(_backersManager, true);
    }

    function run(
        address backersManagerV1Proxy_,
        bool writeDeployment_
    )
        public
        broadcast
        returns (MigrationV2 migrationV2_)
    {
        require(backersManagerV1Proxy_ != address(0), "Backers Manager address cannot be empty");

        BackersManagerRootstockCollective _backersManagerV2Imp = new BackersManagerRootstockCollective();
        GaugeRootstockCollective _gaugeV2Impl = new GaugeRootstockCollective();

        (
            BuilderRegistryRootstockCollective _builderRegistryProxy,
            BuilderRegistryRootstockCollective _builderRegistryImp
        ) = _deployBuilderRegistry(IBackersManagerV1(backersManagerV1Proxy_));

        migrationV2_ = new MigrationV2(
            IBackersManagerV1(backersManagerV1Proxy_),
            _backersManagerV2Imp,
            _builderRegistryProxy,
            _builderRegistryImp,
            _gaugeV2Impl
        );

        if (!writeDeployment_) return migrationV2_;

        persistOutputJson();
        save("MigrationV2", address(migrationV2_));
        save("BuilderRegistryRootstockCollectiveProxy", address(_builderRegistryProxy));
        save("BuilderRegistryRootstockCollective", address(_builderRegistryImp));
        save("BackersManagerRootstockCollective", address(_backersManagerV2Imp));
        save("GaugeRootstockCollectiveImplementation", address(_gaugeV2Impl));
    }

    function _deployBuilderRegistry(IBackersManagerV1 backersManagerV1Proxy_)
        internal
        returns (
            BuilderRegistryRootstockCollective builderRegistryProxy_,
            BuilderRegistryRootstockCollective builderRegistryImpl_
        )
    {
        builderRegistryImpl_ = new BuilderRegistryRootstockCollective();
        address _gaugeFactory = backersManagerV1Proxy_.gaugeFactory();
        address _rewardDistributor = backersManagerV1Proxy_.rewardDistributor();
        uint128 _rewardPercentageCooldown = backersManagerV1Proxy_.rewardPercentageCooldown();
        bytes memory _builderRegistryInitializerData = abi.encodeCall(
            BuilderRegistryRootstockCollective.initialize,
            (
                BackersManagerRootstockCollective(address(backersManagerV1Proxy_)),
                _gaugeFactory,
                _rewardDistributor,
                _rewardPercentageCooldown
            )
        );
        builderRegistryProxy_ = BuilderRegistryRootstockCollective(
            address(new ERC1967Proxy(address(builderRegistryImpl_), _builderRegistryInitializerData))
        );
    }
}
