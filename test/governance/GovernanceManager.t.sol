// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IGovernanceManager } from "src/interfaces/IGovernanceManager.sol";
import { BaseTest } from "../BaseTest.sol";

contract GovernanceManagerTest is BaseTest {
    function test_Initialize() public view {
        assertEq(governanceManager.governor(), governor);
        assertEq(governanceManager.foundationTreasury(), foundation);
        assertEq(governanceManager.kycApprover(), kycApprover);
    }

    function test_UpdateGovernor() public {
        vm.prank(governor);
        governanceManager.updateGovernor(address(0x7));
        assertEq(governanceManager.governor(), address(0x7));
    }

    function test_FailUpdateGovernorByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IGovernanceManager.NotGovernor.selector);
        governanceManager.updateGovernor(address(0x7));
    }

    function test_UpdateTreasury() public {
        vm.prank(governor);
        governanceManager.updateFoundationTreasury(address(0x8));
        assertEq(governanceManager.foundationTreasury(), address(0x8));
    }

    function test_FailUpdateTreasuryByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IGovernanceManager.NotGovernor.selector);
        governanceManager.updateFoundationTreasury(address(0x8));
    }

    function test_UpdateKYCApprover() public {
        vm.prank(governor);
        governanceManager.updateKYCApprover(bob);
        assertEq(governanceManager.kycApprover(), bob);
    }

    function test_FailUpdateKYCApproverByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IGovernanceManager.NotGovernor.selector);
        governanceManager.updateKYCApprover(bob);
    }

    function test_ValidateChanger() public {
        governanceManager.validateChanger(governor);
        vm.expectRevert(IGovernanceManager.NotAuthorizedChanger.selector);
        governanceManager.validateChanger(alice);
    }

    function test_ValidateGovernor() public {
        governanceManager.validateGovernor(governor);
        vm.expectRevert(IGovernanceManager.NotGovernor.selector);
        governanceManager.validateGovernor(alice);
    }

    function test_ValidateKYCApprover() public {
        governanceManager.validateKycApprover(kycApprover);
        vm.expectRevert(IGovernanceManager.NotKycApprover.selector);
        governanceManager.validateKycApprover(alice);
    }

    function test_ValidateFoundationTreasury() public {
        governanceManager.validateFoundationTreasury(foundation);
        vm.expectRevert(IGovernanceManager.NotFoundationTreasury.selector);
        governanceManager.validateFoundationTreasury(alice);
    }
}
