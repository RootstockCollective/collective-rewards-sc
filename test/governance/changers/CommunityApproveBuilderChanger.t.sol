// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, GaugeRootstockCollective } from "../../BaseTest.sol";
import { BuilderState } from "../../../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { CommunityApproveBuilderChangerTemplateRootstockCollective } from "../../../src/governance/changerTemplates/CommunityApproveBuilderChangerTemplateRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract CommunityApproveBuilderChangerTest is BaseTest {
    CommunityApproveBuilderChangerTemplateRootstockCollective internal _changer;
    address internal _newBuilder = makeAddr("newBuilder");

    function _setUp() internal override {
        // GIVEN CommunityApproveBuilderChanger deployed for a new builder
        _changer = new CommunityApproveBuilderChangerTemplateRootstockCollective(builderRegistry, _newBuilder);
    }

    /**
     * SCENARIO: execute on the changer should revert if is not called by the ChangerExecutor
     * ??? TODO: Does this test make sense, if we cannot enforce code on the changer contract?
     */
    function test_RevertWhenIsNotAuthorized() public {
        //  WHEN tries to directly execute the changer
        //   THEN tx reverts because NotGovernorOrAuthorizedChanger
        vm.prank(alice);
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        _changer.execute();
    }

    /**
     * SCENARIO: execute on the ChangerExecutor should revert if is not called by the governor
     */
    function test_RevertWhenIsNotCalledByGovernor() public {
        //  WHEN tries no governor tries to execute the changer
        //   THEN tx reverts because NotGovernor
        vm.prank(alice);
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotGovernor.selector);
        governanceManager.executeChange(_changer);
    }

    /**
     * SCENARIO: execute the change by the governor
     */
    function test_ExecuteChange() public {
        //  WHEN governor executes the changer
        vm.prank(governor);
        governanceManager.executeChange(_changer);
        //  THEN the change is successfully executed
        GaugeRootstockCollective _newGauge = _changer.newGauge();
        //  THEN gauge is added on BackersManagerRootstockCollective
        assertEq(address(builderRegistry.builderToGauge(_newBuilder)), address(_newGauge));
        //  THEN the new builder is community approved
        BuilderState builderState = builderRegistry.builderState(_newBuilder);
        assertEq(uint8(BuilderState.CommunityApproved), uint8(builderState));
    }
}
