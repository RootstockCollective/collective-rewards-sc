// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "../../BaseTest.sol";
import { Governed } from "../../../src/governance/Governed.sol";
import { BuilderRegistry } from "../../../src/BuilderRegistry.sol";
import { WhitelistBuilderChangerTemplate } from
    "../../../src/governance/changerTemplates/WhitelistBuilderChangerTemplate.sol";

contract WhitelistBuilderChangerTest is BaseTest {
    WhitelistBuilderChangerTemplate internal _changer;
    address internal _newBuilder = makeAddr("newBuilder");

    function _setUp() internal override {
        // GIVEN the ChangeExecutor without isAuthorized mock
        changeExecutorMock.setIsAuthorized(false);
        // AND a WhitelistBuilderChanger deployed for a new builder
        _changer = new WhitelistBuilderChangerTemplate(sponsorsManager, _newBuilder);
        // AND a newBuilder activated
        vm.prank(kycApprover);
        sponsorsManager.activateBuilder(_newBuilder, _newBuilder, 0);
    }

    /**
     * SCENARIO: execute on the changer should revert if is not called by the ChangerExecutor
     */
    function test_RevertWhenIsNotAuthorized() public {
        //  WHEN tries to directly execute the changer
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        _changer.execute();
    }

    /**
     * SCENARIO: execute on the ChangerExecutor should revert if is not called by the governor
     */
    function test_RevertWhenIsNotCalledByGovernor() public {
        //  WHEN tries no governor tries to execute the changer
        //   THEN tx reverts because NotGovernor
        vm.expectRevert(Governed.NotGovernor.selector);
        changeExecutorMock.executeChange(_changer);
    }

    /**
     * SCENARIO: execute the change by the governor
     */
    function test_ExecuteChange() public {
        //  WHEN governor executes the changer
        vm.prank(governor);
        changeExecutorMock.executeChange(_changer);
        //  THEN the change is successfully executed
        Gauge _newGauge = _changer.newGauge();
        //  THEN gauge is added on SponsorsManager
        assertEq(address(sponsorsManager.builderToGauge(_newBuilder)), address(_newGauge));
        //  THEN the new builder is whitelisted
        assertEq(uint256(sponsorsManager.builderState(_newBuilder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }
}
