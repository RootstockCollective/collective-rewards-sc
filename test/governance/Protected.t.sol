// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, SponsorsManager } from "../BaseTest.sol";
import { Governed } from "../../src/governance/Governed.sol";

contract ProtectedTest is BaseTest {
    /**
     * SCENARIO: Governor can execute a change without using the ChangeExecutorRootstockCollective
     */
    function test_GovernorHasPermissions() public {
        // GIVEN there is not a changer authorized
        changeExecutorMock.setIsAuthorized(false);
        //  WHEN Governor calls a function protected by the modifier onlyGovernorOrAuthorizedChanger
        vm.startPrank(governor);
        sponsorsManager.upgradeToAndCall(address(new SponsorsManager()), "");
    }

    /**
     * SCENARIO: upgrade should revert if is not called by the governor or an authorized changer
     */
    function test_RevertUpgrade() public {
        // GIVEN the Governor has not authorized the change
        changeExecutorMock.setIsAuthorized(false);
        //  WHEN tries to upgrade the SponsorsManager
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        address _newImplementation = makeAddr("newImplementation");
        sponsorsManager.upgradeToAndCall(_newImplementation, "0x0");
    }

    /**
     * SCENARIO: ChangeExecutorRootstockCollective upgrade should revert if is not called by the governor
     */
    function test_RevertChangeExecutorUpgradeNotGovernor() public {
        // GIVEN a not Governor address
        //  WHEN tries to upgrade the ChangeExecutorRootstockCollective
        //   THEN tx reverts because NotGovernor
        vm.expectRevert(Governed.NotGovernor.selector);
        address _newImplementation = makeAddr("newImplementation");
        changeExecutorMock.upgradeToAndCall(_newImplementation, "0x0");
    }

    /**
     * SCENARIO: Gauge upgrade should revert if is not called by the governor or an authorized changer
     */
    function test_RevertGaugeUpgradeNotGovernor() public {
        // GIVEN the Governor has not authorized the change
        changeExecutorMock.setIsAuthorized(false);
        //  WHEN tries to upgrade the GaugeBeacon
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        address _newImplementation = makeAddr("newImplementation");
        gaugeBeacon.upgradeTo(_newImplementation);
    }
}
