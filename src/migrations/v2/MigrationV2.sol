// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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

    IBackersManagerV1 public backersManagerV1;
    BackersManagerRootstockCollective public backersManagerV2Implementation;
    BuilderRegistryRootstockCollective public builderRegistry;
    BuilderRegistryRootstockCollective public builderRegistryImplementation;
    IGovernanceManagerRootstockCollective public governanceManager;
    GaugeBeaconRootstockCollective public gaugeBeacon;
    address public upgrader;
    address public gaugeFactory;
    address public rewardDistributor;
    uint128 public rewardPercentageCooldown;

    constructor(
        address backersManagerV1_,
        BuilderRegistryRootstockCollective builderRegistryImplementation_,
        BackersManagerRootstockCollective backersManagerV2Implementation_
    ) {
        backersManagerV1 = IBackersManagerV1(backersManagerV1_);
        governanceManager = backersManagerV1.governanceManager();
        gaugeBeacon =
            GaugeBeaconRootstockCollective(GaugeFactoryRootstockCollective(backersManagerV1.gaugeFactory()).beacon());
        upgrader = governanceManager.upgrader();
        gaugeFactory = backersManagerV1.gaugeFactory();
        rewardDistributor = backersManagerV1.rewardDistributor();
        rewardPercentageCooldown = backersManagerV1.rewardPercentageCooldown();
        builderRegistryImplementation = builderRegistryImplementation_;
        backersManagerV2Implementation = backersManagerV2Implementation_;
    }

    function run() public returns (BuilderRegistryRootstockCollective builderRegistry_) {
        if (governanceManager.upgrader() != address(this)) revert NotUpgrader();

        builderRegistry_ = _deployBuilderRegistry();

        builderRegistry_.migrateAllBuildersV2();

        _upgradeBackersManager(builderRegistry_);

        _upgradeGauges();

        _resetUpgrader();
    }

    function _deployBuilderRegistry() internal returns (BuilderRegistryRootstockCollective builderRegistry_) {
        // deploy builders registry v2
        bytes memory _builderRegistryInitializerData = abi.encodeCall(
            BuilderRegistryRootstockCollective.initialize,
            (
                BackersManagerRootstockCollective(address(backersManagerV1)),
                gaugeFactory,
                rewardDistributor,
                rewardPercentageCooldown
            )
        );
        builderRegistry_ = BuilderRegistryRootstockCollective(
            address(new ERC1967Proxy(address(builderRegistryImplementation), _builderRegistryInitializerData))
        );
        builderRegistry = builderRegistry_;
    }

    function _upgradeBackersManager(BuilderRegistryRootstockCollective builderRegistry_) internal {
        bytes memory _backersManagerInitializeData = abi.encodeCall(
            BackersManagerRootstockCollective.initializeV2, (BuilderRegistryRootstockCollective(builderRegistry_))
        );

        backersManagerV1.upgradeToAndCall(address(backersManagerV2Implementation), _backersManagerInitializeData);
    }

    function _upgradeGauges() internal {
        // deploy gauge implementation v2
        GaugeRootstockCollective _gaugeImplementation = new GaugeRootstockCollective();
        // upgrade gauge beacon to point to the new v2 implementation
        gaugeBeacon.upgradeTo(address(_gaugeImplementation));
        // initialize all the gauges proxies to v2
        uint256 _gaugesLength = BuilderRegistryRootstockCollective(builderRegistry).getGaugesLength();
        for (uint256 i = 0; i < _gaugesLength; i++) {
            GaugeRootstockCollective _gauge =
                GaugeRootstockCollective(BuilderRegistryRootstockCollective(builderRegistry).getGaugeAt(i));
            _gauge.initializeV2();
        }
    }

    function _resetUpgrader() internal {
        // Reset upgrader role back to the original address
        governanceManager.updateUpgrader(upgrader);
    }
}
