// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdError } from "forge-std/src/Test.sol";
import { BaseTest, Gauge } from "../BaseTest.sol";
import { Governed } from "../../src/governance/Governed.sol";

contract ProtectedTest is BaseTest {
    /**
     * SCENARIO: Governor can execute a change without using the ChangeExecutor
     */
    function test_GovernorHasPermissions() public {
        // GIVEN there is not a changer authorized
        changeExecutorMock.setIsAuthorized(false);
        //  WHEN Governor calls a function protected by the modifier onlyGovernorOrAuthorizedChanger
        vm.prank(governor);
        address newBuilder = makeAddr("newBuilder");
        Gauge newGauge = sponsorsManager.createGauge(newBuilder);
        //   THEN the function is successfully executed
        assertEq(address(sponsorsManager.builderToGauge(newBuilder)), address(newGauge));
    }

    /**
     * SCENARIO: createGauge should revert if is not called by the governor or an authorized changer
     */
    function test_RevertSponsorsManagerCreateGauge() public {
        // GIVEN the Governor has not authorized the change
        changeExecutorMock.setIsAuthorized(false);
        //  WHEN tries to create a gauge
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        sponsorsManager.createGauge(builder);
    }
}
