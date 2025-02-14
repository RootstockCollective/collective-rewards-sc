// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { GaugeRootstockCollective } from "../../gauge/GaugeRootstockCollective.sol";
import { GaugeBeaconRootstockCollective } from "../../gauge/GaugeBeaconRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "../../gauge/GaugeFactoryRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "../../builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "../../backersManager/BackersManagerRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../../interfaces/IGovernanceManagerRootstockCollective.sol";
import { IBackersManagerV1 } from "../../interfaces/V1/IBackersManagerV1.sol";

/**
 * @title MigrationV2
 * @notice Migrate the mainnet live system to V2
 */
contract MigrationV2 {
    error NotUpgrader();

    IBackersManagerV1 public backersManagerV1Proxy;
    BackersManagerRootstockCollective public backersManagerV2Impl;
    BuilderRegistryRootstockCollective public builderRegistryV2Proxy;
    BuilderRegistryRootstockCollective public builderRegistryV2Impl;
    IGovernanceManagerRootstockCollective public governanceManager;
    GaugeRootstockCollective public gaugev2Impl;
    GaugeBeaconRootstockCollective public gaugeBeacon;
    address public upgrader;

    constructor(
        IBackersManagerV1 backersManagerV1Proxy_,
        BackersManagerRootstockCollective backersManagerV2Impl_,
        BuilderRegistryRootstockCollective builderRegistryV2Proxy_,
        BuilderRegistryRootstockCollective builderRegistryV2Impl_,
        GaugeRootstockCollective gaugeV2Imp_
    ) {
        backersManagerV1Proxy = backersManagerV1Proxy_;
        builderRegistryV2Proxy = builderRegistryV2Proxy_;
        backersManagerV2Impl = backersManagerV2Impl_;
        builderRegistryV2Impl = builderRegistryV2Impl_;
        governanceManager = backersManagerV1Proxy.governanceManager();
        gaugev2Impl = gaugeV2Imp_;
        gaugeBeacon = GaugeBeaconRootstockCollective(
            GaugeFactoryRootstockCollective(backersManagerV1Proxy.gaugeFactory()).beacon()
        );
        upgrader = governanceManager.upgrader();
    }

    function run() public returns (BuilderRegistryRootstockCollective) {
        if (governanceManager.upgrader() != address(this)) revert NotUpgrader();

        builderRegistryV2Proxy.migrateAllBuildersV2();

        _upgradeBackersManager(builderRegistryV2Proxy);

        _upgradeGauges();

        _resetUpgrader();

        return builderRegistryV2Proxy;
    }

    function resetUpgrader() public {
        if (msg.sender != upgrader) revert NotUpgrader();
        _resetUpgrader();
    }

    function _upgradeBackersManager(BuilderRegistryRootstockCollective builderRegistry_) internal {
        bytes memory _backersManagerInitializeData = abi.encodeCall(
            BackersManagerRootstockCollective.initializeV2, (BuilderRegistryRootstockCollective(builderRegistry_))
        );

        backersManagerV1Proxy.upgradeToAndCall(address(backersManagerV2Impl), _backersManagerInitializeData);
    }

    function _upgradeGauges() internal {
        // upgrade gauge beacon to point to the new v2 implementation
        gaugeBeacon.upgradeTo(address(gaugev2Impl));
        // initialize all the gauges proxies to v2
        uint256 _gaugesLength = BuilderRegistryRootstockCollective(builderRegistryV2Proxy).getGaugesLength();
        for (uint256 i = 0; i < _gaugesLength; i++) {
            GaugeRootstockCollective _gauge =
                GaugeRootstockCollective(BuilderRegistryRootstockCollective(builderRegistryV2Proxy).getGaugeAt(i));
            _gauge.initializeV2();
        }
    }

    function _resetUpgrader() internal {
        // Reset upgrader role back to the original address
        governanceManager.updateUpgrader(upgrader);
    }
}
