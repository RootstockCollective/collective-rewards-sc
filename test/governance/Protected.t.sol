// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, BackersManagerRootstockCollective, BuilderRegistryRootstockCollective } from "../BaseTest.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";

contract ProtectedTest is BaseTest {
    /**
     * SCENARIO: Governor can execute a change without using the ChangeExecutorRootstockCollective
     */
    function test_GovernorHasPermissions() public {
        //  WHEN Governor calls a function protected by the modifier onlyAuthorizedUpgrader
        vm.startPrank(governor);
        builderRegistry.upgradeToAndCall(address(new BuilderRegistryRootstockCollective()), "");
    }

    /**
     * SCENARIO: Upgrader can upgrade the BackersManager contract
     */
    function test_UpgraderCanUpgradeBackersManager() public {
        //  WHEN Upgrader calls a function function to update the contract, protected by the modifier
        // onlyAuthorizedUpgrader
        vm.startPrank(upgrader);
        builderRegistry.upgradeToAndCall(address(new BuilderRegistryRootstockCollective()), "");
    }

    /**
     * SCENARIO: Upgrader can upgrade the GovernanceManager contract
     */
    function test_UpgraderCanUpgradeGovernanceManager() public {
        //  WHEN Governor calls a function protected by the modifier onlyAuthorizedUpgrader
        vm.startPrank(upgrader);
        governanceManager.upgradeToAndCall(address(new GovernanceManagerRootstockCollective()), "");
    }

    /**
     * SCENARIO: New upgrader can upgrade the GovernanceManager contract
     */
    function test_NewUpgraderCanUpgradeGovernanceManager() public {
        //  WHEN Governor updates the upgrader
        address _newUpgrader = makeAddr("newUpgrader");
        vm.prank(upgrader);
        governanceManager.updateUpgrader(_newUpgrader);

        // THEN the new upgrader can upgrade the GovernanceManager contract
        address _newImplementation = address(new GovernanceManagerRootstockCollective());
        vm.prank(_newUpgrader);
        governanceManager.upgradeToAndCall(_newImplementation, "");

        // AND the old upgrader can't upgrade the GovernanceManager contract
        _newImplementation = address(new GovernanceManagerRootstockCollective());
        vm.prank(upgrader);
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedUpgrader.selector);
        governanceManager.upgradeToAndCall(_newImplementation, "");
    }

    /**
     * SCENARIO: upgrade should revert if is not called by the governor or an authorized upgrader
     */
    function test_RevertUpgrade() public {
        // GIVEN the Governor has not authorized the change
        vm.prank(alice);
        //  WHEN tries to upgrade the BackersManagerRootstockCollective
        //   THEN tx reverts because is not an authorized upgrader
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedUpgrader.selector);
        address _newImplementation = makeAddr("newImplementation");
        builderRegistry.upgradeToAndCall(_newImplementation, "0x0");
    }

    /**
     * SCENARIO: Gauge upgrade should revert if is not an authorized upgrader
     */
    function test_RevertGaugeUpgradeNotAuthorizedUpgrader() public {
        // GIVEN a non-Governor tries to upgrade the GaugeBeaconRootstockCollective
        vm.prank(alice);
        //  THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedUpgrader.selector);
        address _newImplementation = makeAddr("newImplementation");
        gaugeBeacon.upgradeTo(_newImplementation);
    }

    /**
     * SCENARIO: GovernanceManagerRootstockCollective upgrade should revert if is not called by an authorized upgrader
     */
    function test_RevertGovernanceManagerUpgradeNotAuthorizedUpgrader() public {
        // GIVEN a non-Governor tries to upgrade the GovernanceManagerRootstockCollective
        vm.prank(alice);
        //  THEN tx reverts because NotGovernor
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedUpgrader.selector);
        address _newImplementation = makeAddr("newImplementation");
        governanceManager.upgradeToAndCall(_newImplementation, "0x0");
    }
}
