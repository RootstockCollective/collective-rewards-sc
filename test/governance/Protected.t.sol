// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, SponsorsManager } from "../BaseTest.sol";
import { IGovernanceManager } from "src/interfaces/IGovernanceManager.sol";

contract ProtectedTest is BaseTest {
    /**
     * SCENARIO: Governor can execute a change without using the ChangeExecutorRootstockCollective
     */
    function test_GovernorHasPermissions() public {
        //  WHEN Governor calls a function protected by the modifier onlyGovernorOrAuthorizedChanger
        vm.startPrank(governor);
        sponsorsManager.upgradeToAndCall(address(new SponsorsManager()), "");
    }

    /**
     * SCENARIO: upgrade should revert if is not called by the governor or an authorized changer
     */
    function test_RevertUpgrade() public {
        // GIVEN the Governor has not authorized the change
        vm.prank(alice);
        //  WHEN tries to upgrade the SponsorsManager
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(IGovernanceManager.NotAuthorizedChanger.selector);
        address _newImplementation = makeAddr("newImplementation");
        sponsorsManager.upgradeToAndCall(_newImplementation, "0x0");
    }

    /**
     * SCENARIO: Gauge upgrade should revert if is not called by the governor or an authorized changer
     */
    function test_RevertGaugeUpgradeNotGovernor() public {
        // GIVEN a non-Governor tries to upgrade the GaugeBeacon
        vm.prank(alice);
        //  THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(IGovernanceManager.NotAuthorizedChanger.selector);
        address _newImplementation = makeAddr("newImplementation");
        gaugeBeacon.upgradeTo(_newImplementation);
    }

    /**
     * SCENARIO: GovernanceManager upgrade should revert if is not called by the governor
     */
    function test_RevertGovernanceManagerUpgradeNotGovernor() public {
        // GIVEN a non-Governor tries to upgrade the GovernanceManager
        vm.prank(alice);
        //  THEN tx reverts because NotGovernor
        vm.expectRevert(IGovernanceManager.NotGovernor.selector);
        address _newImplementation = makeAddr("newImplementation");
        governanceManager.upgradeToAndCall(_newImplementation, "0x0");
    }
}
