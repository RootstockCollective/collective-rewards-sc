// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, BackersManagerRootstockCollective } from "../BaseTest.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract ProtectedTest is BaseTest {
    /**
     * SCENARIO: Governor can execute a change without using the ChangeExecutorRootstockCollective
     */
    function test_GovernorHasPermissions() public {
        //  WHEN Governor calls a function protected by the modifier onlyGovernorOrAuthorizedChanger
        vm.startPrank(governor);
        backersManager.upgradeToAndCall(address(new BackersManagerRootstockCollective()), "");
    }

    /**
     * SCENARIO: upgrade should revert if is not called by the governor or an authorized changer
     */
    function test_RevertUpgrade() public {
        // GIVEN the Governor has not authorized the change
        vm.prank(alice);
        //  WHEN tries to upgrade the BackersManagerRootstockCollective
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        address _newImplementation = makeAddr("newImplementation");
        backersManager.upgradeToAndCall(_newImplementation, "0x0");
    }

    /**
     * SCENARIO: Gauge upgrade should revert if is not called by the governor or an authorized changer
     */
    function test_RevertGaugeUpgradeNotGovernor() public {
        // GIVEN a non-Governor tries to upgrade the GaugeBeaconRootstockCollective
        vm.prank(alice);
        //  THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        address _newImplementation = makeAddr("newImplementation");
        gaugeBeacon.upgradeTo(_newImplementation);
    }

    /**
     * SCENARIO: GovernanceManagerRootstockCollective upgrade should revert if is not called by the governor
     */
    function test_RevertGovernanceManagerRootstockCollectiveUpgradeNotAuthorizedChanger() public {
        // GIVEN a non-Governor tries to upgrade the GovernanceManagerRootstockCollective
        vm.prank(alice);
        //  THEN tx reverts because NotGovernor
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        address _newImplementation = makeAddr("newImplementation");
        governanceManager.upgradeToAndCall(_newImplementation, "0x0");
    }
}
