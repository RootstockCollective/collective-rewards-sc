// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { UpgradeV3 } from "src/upgrades/UpgradeV3.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { UpgradeV3Deployer } from "script/upgrades/UpgradeV3.s.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";
import { GaugeBeaconRootstockCollective } from "src/gauge/GaugeBeaconRootstockCollective.sol";

contract UpgradeV3Test is Test {
    BackersManagerRootstockCollective public backersManager;
    BuilderRegistryRootstockCollective public builderRegistry;
    IGovernanceManagerRootstockCollective public governanceManager;
    RewardDistributorRootstockCollective public rewardDistributor;
    GaugeBeaconRootstockCollective public gaugeBeacon;
    UpgradeV3 public upgradeV3;
    address public upgrader;
    address public configurator = makeAddr("configurator");
    address public alice = makeAddr("alice");

    function setUp() public {
        backersManager =
            BackersManagerRootstockCollective(vm.envOr("BackersManagerRootstockCollectiveProxy", address(0)));
        builderRegistry =
            BuilderRegistryRootstockCollective(vm.envOr("BuilderRegistryRootstockCollectiveProxy", address(0)));
        governanceManager =
            IGovernanceManagerRootstockCollective(vm.envOr("GovernanceManagerRootstockCollectiveProxy", address(0)));
        rewardDistributor = RewardDistributorRootstockCollective(
            payable(vm.envOr("RewardDistributorRootstockCollectiveProxy", address(0)))
        );
        GaugeFactoryRootstockCollective _gaugeFactory =
            GaugeFactoryRootstockCollective(vm.envOr("GaugeFactoryRootstockCollective", address(0)));
        gaugeBeacon = GaugeBeaconRootstockCollective(_gaugeFactory.beacon());

        upgrader = governanceManager.upgrader();

        // Setup UpgradeV3
        UpgradeV3Deployer _upgradeV3Deployer = new UpgradeV3Deployer();
        upgradeV3 = _upgradeV3Deployer.run(backersManager, rewardDistributor, configurator, false);
    }

    /**
     * SCENARIO: Upgrade v3 is setup correctly
     */
    function test_fork_upgradeV3Setup() public view {
        // GIVEN UpgradeV3 is setup
        // THEN UpgradeV3 should have the expected initialization state
        vm.assertEq(address(upgradeV3.backersManagerProxy()), address(backersManager));
        vm.assertNotEq(address(upgradeV3.backersManagerImplV3()), address(0));

        vm.assertEq(address(upgradeV3.builderRegistryProxy()), address(builderRegistry));
        vm.assertNotEq(address(upgradeV3.builderRegistryImplV3()), address(0));

        vm.assertEq(address(upgradeV3.governanceManagerProxy()), address(governanceManager));
        vm.assertNotEq(address(upgradeV3.governanceManagerImplV3()), address(0));

        vm.assertEq(address(upgradeV3.gaugeBeacon()), address(gaugeBeacon));
        vm.assertNotEq(address(upgradeV3.gaugeImplV3()), address(0));

        vm.assertEq(address(upgradeV3.rewardDistributorProxy()), address(rewardDistributor));
        vm.assertNotEq(address(upgradeV3.rewardDistributorImplV3()), address(0));

        vm.assertEq(upgradeV3.upgrader(), upgrader);

        vm.assertNotEq(address(upgradeV3.configurator()), address(0));
        vm.assertGt(upgradeV3.MAX_DISTRIBUTIONS_PER_BATCH(), 0);
    }

    /**
     * SCENARIO: original upgrader can reclaim UpgradeV3 upgrader role
     */
    function test_fork_upgradeV3ResetUpgrader() public {
        // GIVEN UpgradeV3 is setup
        // AND the upgrader is set to UpgradeV3 address
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(upgradeV3));
        vm.assertEq(address(backersManager.governanceManager().upgrader()), address(upgradeV3));

        // WHEN the upgrader is reset
        vm.prank(upgrader);
        upgradeV3.resetUpgrader();
        // THEN the upgrader should match the original upgrader
        vm.assertEq(address(backersManager.governanceManager().upgrader()), upgrader);
    }

    /**
     * SCENARIO: only original upgrader can reclaim UpgradeV3 upgrader role
     */
    function test_fork_upgradeV3ResetUpgrader_unauthorized() public {
        // GIVEN UpgradeV3 is setup
        // AND the upgrader is set to UpgradeV3 address
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(upgradeV3));

        // WHEN the upgrader is reset by an unauthorized address
        // THEN the upgrader should revert with NotUpgrader error
        vm.prank(address(this));
        vm.expectRevert(UpgradeV3.NotUpgrader.selector);
        upgradeV3.resetUpgrader();
    }

    /**
     * SCENARIO: BackersManager is upgraded to v3
     */
    function test_fork_upgradeBackersManager() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN BackersManager should have the new implementation
        vm.assertEq(_getImplementation(address(backersManager)), address(upgradeV3.backersManagerImplV3()));
        // AND should follow v3 interface
        vm.assertEq(backersManager.maxDistributionsPerBatch(), upgradeV3.MAX_DISTRIBUTIONS_PER_BATCH());
    }

    /**
     * SCENARIO: BuilderRegistry is upgraded to v3
     */
    function test_fork_upgradeBuilderRegistry() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN BackersManager should have the new implementation
        vm.assertEq(_getImplementation(address(builderRegistry)), address(upgradeV3.builderRegistryImplV3()));
        // AND should follow v3 interface
        vm.assertEq(builderRegistry.rewardReceiver(alice), address(0));
    }

    /**
     * SCENARIO: GovernanceManager is upgraded to v3
     */
    function test_fork_upgradeGovernanceManager() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN governanceManager should have the new implementation
        vm.assertEq(_getImplementation(address(governanceManager)), address(upgradeV3.governanceManagerImplV3()));
        // AND should follow v3 interface
        vm.assertNotEq(governanceManager.configurator(), address(0));
    }

    /**
     * SCENARIO: Gauge is upgraded to v3
     */
    function test_fork_upgradeGauge() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN gaugeBeacon should have the new implementation
        vm.assertEq(gaugeBeacon.implementation(), address(upgradeV3.gaugeImplV3()));
    }
    /**
     * SCENARIO: RewardDistributor is upgraded to v3
     */

    function test_fork_upgradeRewardDistributor() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN rewardDistributor should have the new implementation
        vm.assertEq(_getImplementation(address(rewardDistributor)), address(upgradeV3.rewardDistributorImplV3()));
    }

    /**
     * @dev Upgrades the contracts to v3
     */
    function _upgradeV3() internal {
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(upgradeV3));
        upgradeV3.run();
    }

    /**
     * @dev Returns the implementation address of a proxy contract.
     * @param proxy_ The address of the proxy contract.
     * @return The implementation address of the proxy contract.
     */
    function _getImplementation(address proxy_) internal view returns (address) {
        return
            address(uint160(uint256(vm.load(proxy_, bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)))));
    }
}
