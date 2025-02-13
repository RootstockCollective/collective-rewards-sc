// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { IBackersManagerV1 } from "src/interfaces/V1/IBackersManagerV1.sol";
import { MigrationV2 } from "src/migrations/v2/MigrationV2.sol";
import { MigrationV2Deployer } from "script/migrations/v2/MigrationV2.s.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";

contract MigrationSetupV2Fork is Test {
    IBackersManagerV1 public backersManagerV1;
    IGovernanceManagerRootstockCollective public governanceManager;
    MigrationV2 public migrationV2;
    BuilderRegistryRootstockCollective public builderRegistry;

    function setUp() public {
        address _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        backersManagerV1 = IBackersManagerV1(_backersManager);
        governanceManager = backersManagerV1.governanceManager();

        MigrationV2Deployer _migrationV2Deployer = new MigrationV2Deployer();
        migrationV2 = _migrationV2Deployer.run(_backersManager, false);
    }

    /**
     * SCENARIO: Migration v2 is setup correctly
     */
    function test_fork_migrationV2Setup() public view {
        // GIVEN migration v2 is setup
        // THEN migration v2 should have the expected state
        vm.assertNotEq(address(migrationV2.backersManagerV2Implementation()), address(0));
        vm.assertNotEq(address(migrationV2.builderRegistryImplementation()), address(0));
        vm.assertEq(address(migrationV2.backersManagerV1()), address(backersManagerV1));
        vm.assertEq(address(migrationV2.governanceManager()), address(backersManagerV1.governanceManager()));
        vm.assertEq(migrationV2.rewardDistributor(), address(backersManagerV1.rewardDistributor()));
        vm.assertEq(migrationV2.rewardPercentageCooldown(), backersManagerV1.rewardPercentageCooldown());
        vm.assertEq(migrationV2.upgrader(), address(governanceManager.upgrader()));
        vm.assertEq(migrationV2.gaugeFactory(), address(backersManagerV1.gaugeFactory()));
        vm.assertEq(
            address(migrationV2.gaugeBeacon()),
            address(GaugeFactoryRootstockCollective(backersManagerV1.gaugeFactory()).beacon())
        );
    }

    function test_fork_migrationV2ResetUpgrader() public {
        // GIVEN migration v2 is setup
        address _originalUpgrader = address(backersManagerV1.governanceManager().upgrader());
        // AND the upgrader is set to migration v2
        vm.prank(_originalUpgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        vm.assertEq(address(migrationV2), address(backersManagerV1.governanceManager().upgrader()));
        // WHEN the upgrader is reset
        vm.prank(address(_originalUpgrader));
        migrationV2.resetUpgrader();
        // THEN the upgrader should be reseted to the original upgrader
        vm.assertEq(_originalUpgrader, address(backersManagerV1.governanceManager().upgrader()));
    }

    function test_fork_migrationV2ResetUpgrader_unauthorized() public {
        // GIVEN migration v2 is setup
        // AND the upgrader is set to migration v2
        address _originalUpgrader = address(backersManagerV1.governanceManager().upgrader());
        vm.prank(_originalUpgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        // WHEN the upgrader is reset by an unauthorized address
        // THEN the upgrader should revert with NotUpgrader error
        vm.prank(address(this));
        vm.expectRevert(MigrationV2.NotUpgrader.selector);
        migrationV2.resetUpgrader();
    }
}
