// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdError } from "forge-std/Test.sol";
import { BaseTest, Gauge } from "../../BaseTest.sol";
import { Governed } from "../../../src/governance/Governed.sol";
import { ChangeExecutor } from "../../../src/governance/ChangeExecutor.sol";
import { WhitelistBuilderChangerTemplate } from
    "../../../src/governance/changerTemplates/WhitelistBuilderChangerTemplate.sol";

contract WhitelistBuilderChangerTest is BaseTest {
    WhitelistBuilderChangerTemplate internal changer;
    address internal newBuilder = makeAddr("newBuilder");

    function _setUp() internal override {
        // GIVEN the ChangeExecutor without isAuthorized mock
        changeExecutorMock.setIsAuthorized(false);
        // AND a WhitelistBuilderChanger deployed for a new builder
        changer = new WhitelistBuilderChangerTemplate(sponsorsManager, newBuilder);
    }

    /**
     * SCENARIO: execute on the changer should revert if is not called by the ChangerExecutor
     */
    function test_RevertWhenIsNotAuthorized() public {
        //  WHEN tries to directly execute the changer
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        changer.execute();
    }

    /**
     * SCENARIO: execute on the ChangerExecutor should revert if is not called by the governor
     */
    function test_RevertWhenIsNotCalledByGovernor() public {
        //  WHEN tries no governor tries to execute the changer
        //   THEN tx reverts because NotGovernor
        vm.expectRevert(ChangeExecutor.NotGovernor.selector);
        changeExecutorMock.executeChange(changer);
    }

    /**
     * SCENARIO: execute the change by the governor
     */
    function test_ExecuteChange() public {
        //  WHEN governor executes the changer
        vm.prank(governor);
        changeExecutorMock.executeChange(changer);
        //   THEN the change is successfully executed
        Gauge newGauge = changer.newGauge();
        assertEq(address(sponsorsManager.builderToGauge(newBuilder)), address(newGauge));
    }
}
