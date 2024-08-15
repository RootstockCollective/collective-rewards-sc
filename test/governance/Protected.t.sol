// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, BuilderGauge } from "../BaseTest.sol";
import { Governed } from "../../src/governance/Governed.sol";
import { ChangeExecutor } from "../../src/governance/ChangeExecutor.sol";

contract ProtectedTest is BaseTest {
    /**
     * SCENARIO: Governor can execute a change without using the ChangeExecutor
     */
    function test_GovernorHasPermissions() public {
        // GIVEN there is not a changer authorized
        changeExecutorMock.setIsAuthorized(false);
        //  WHEN Governor calls a function protected by the modifier onlyGovernorOrAuthorizedChanger
        vm.prank(governor);
        address _newBuilder = makeAddr("newBuilder");
        BuilderGauge _newBuilderGauge = sponsorsManager.createBuilderGauge(_newBuilder);
        //   THEN the function is successfully executed
        assertEq(address(sponsorsManager.builderToGauge(_newBuilder)), address(_newBuilderGauge));
    }

    /**
     * SCENARIO: createBuilderGauge should revert if is not called by the governor or an authorized changer
     */
    function test_RevertSponsorsManagerCreateBuilderGauge() public {
        // GIVEN the Governor has not authorized the change
        changeExecutorMock.setIsAuthorized(false);
        //  WHEN tries to create a builderGauge
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        sponsorsManager.createBuilderGauge(builder);
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
     * SCENARIO: ChangeExecutor upgrade should revert if is not called by the governor
     */
    function test_RevertUpgradeNotGovernor() public {
        // GIVEN a not Governor address
        //  WHEN tries to upgrade the ChangeExecutor
        //   THEN tx reverts because NotGovernor
        vm.expectRevert(ChangeExecutor.NotGovernor.selector);
        address _newImplementation = makeAddr("newImplementation");
        changeExecutorMock.upgradeToAndCall(_newImplementation, "0x0");
    }
}
