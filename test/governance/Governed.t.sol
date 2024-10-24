// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IGoverned } from "src/interfaces/IGoverned.sol";
import { BaseTest } from "../BaseTest.sol";

contract GovernedTest is BaseTest {
    function test_Initialize() public view {
        assertEq(governed.governor(), governor);
        assertEq(governed.foundationTreasury(), foundation);
        assertEq(governed.kycApprover(), kycApprover);
        assertEq(governed.changerAdmin(), address(changeExecutor));
    }

    function test_UpdateGovernor() public {
        vm.prank(governor);
        governed.updateGovernor(address(0x7));
        assertEq(governed.governor(), address(0x7));
    }

    function test_FailUpdateGovernorByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IGoverned.NotGovernor.selector);
        governed.updateGovernor(address(0x7));
    }

    function test_UpdateChangerAdmin() public {
        vm.prank(governor);
        governed.updateChangerAdmin(alice);
        assertEq(governed.changerAdmin(), alice);
    }

    function test_FailUpdateChangerAdminByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IGoverned.NotGovernor.selector);
        governed.updateChangerAdmin(alice);
    }

    function test_UpdateChangerByAdmin() public {
        vm.prank(governor);
        governed.updateChangerAdmin(bob);
        vm.prank(bob);
        governed.updateChanger(alice);
        assertEq(governed.changer(), alice);
    }

    function test_FailUpdateChangerByNonChangerAdmin() public {
        vm.prank(alice);
        vm.expectRevert(IGoverned.NotChangerAdmin.selector);
        governed.updateChanger(alice);
    }

    function test_UpdateTreasury() public {
        vm.prank(governor);
        governed.updateFoundationTreasury(address(0x8));
        assertEq(governed.foundationTreasury(), address(0x8));
    }

    function test_FailUpdateTreasuryByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IGoverned.NotGovernor.selector);
        governed.updateFoundationTreasury(address(0x8));
    }

    function test_UpdateKYCApprover() public {
        vm.prank(governor);
        governed.updateKYCApprover(bob);
        assertEq(governed.kycApprover(), bob);
    }

    function test_FailUpdateKYCApproverByNonGovernor() public {
        vm.prank(alice);
        vm.expectRevert(IGoverned.NotGovernor.selector);
        governed.updateKYCApprover(bob);
    }

    function test_ValidateChanger() public {
        governed.validateChanger(governor);
        vm.expectRevert(IGoverned.NotAuthorizedChanger.selector);
        governed.validateChanger(alice);
    }

    function test_ValidateGovernor() public {
        governed.validateGovernor(governor);
        vm.expectRevert(IGoverned.NotGovernor.selector);
        governed.validateGovernor(alice);
    }

    function test_ValidateChangerAdmin() public {
        governed.validateChangerAdmin(address(changeExecutor));
        vm.expectRevert(IGoverned.NotChangerAdmin.selector);
        governed.validateChangerAdmin(alice);
    }

    function test_ValidateKYCApprover() public {
        governed.validateKycApprover(kycApprover);
        vm.expectRevert(IGoverned.NotKycApprover.selector);
        governed.validateKycApprover(alice);
    }

    function test_ValidateFoundationTreasury() public {
        governed.validateFoundationTreasury(foundation);
        vm.expectRevert(IGoverned.NotFoundationTreasury.selector);
        governed.validateFoundationTreasury(alice);
    }
}
