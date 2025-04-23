// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { BaseTest } from "../BaseTest.sol";
import { IChangeContractRootstockCollective } from "src/interfaces/IChangeContractRootstockCollective.sol";

contract GovernanceManagerRootstockCollectiveTest is BaseTest {
    event GovernorUpdated(address governor_, address updatedBy_);
    event FoundationTreasuryUpdated(address foundationTreasury_, address updatedBy_);
    event KycApproverUpdated(address kycApprover_, address updatedBy_);
    event UpgraderUpdated(address upgrader_, address updatedBy_);
    event ChangeExecuted(IChangeContractRootstockCollective changeContract_, address executor_);

    /**
     * SCENARIO: GovernanceManager is initialized correctly
     */
    function test_Initialize() public view {
        // THEN the governor is set correctly
        assertEq(governanceManager.governor(), governor);

        // AND the foundation treasury is set correctly
        assertEq(governanceManager.foundationTreasury(), foundation);

        // AND the KYC approver is set correctly
        assertEq(governanceManager.kycApprover(), kycApprover);

        // AND the upgrader is set correctly
        assertEq(governanceManager.upgrader(), upgrader);
    }

    /**
     * SCENARIO: Governor can update the governor address
     */
    function test_UpdateGovernor() public {
        // WHEN the governor updates the governor address
        vm.prank(governor);
        vm.expectEmit();
        emit GovernorUpdated(bob, governor);
        governanceManager.updateGovernor(bob);

        // THEN the governor address is updated
        assertEq(governanceManager.governor(), bob);
    }

    /**
     * SCENARIO: Unauthorized account cannot update the governor address
     */
    function test_FailUpdateGovernorByNotAuthorizedChanger() public {
        // WHEN an unauthorized account attempts to update the governor address
        vm.prank(alice);
        // THEN tx reverts because NotAuthorizedChanger
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        governanceManager.updateGovernor(bob);
    }

    /**
     * SCENARIO: Governor can update the foundation treasury address
     */
    function test_UpdateFoundationTreasury() public {
        // WHEN the governor updates the foundation treasury
        vm.prank(governor);
        vm.expectEmit();
        emit FoundationTreasuryUpdated(bob, governor);
        governanceManager.updateFoundationTreasury(bob);

        // THEN the foundation treasury address is updated
        assertEq(governanceManager.foundationTreasury(), bob);
    }

    /**
     * SCENARIO: Unauthorized account cannot update the foundation treasury
     */
    function test_FailUpdateFoundationTreasuryByNotAuthorizedChanger() public {
        // WHEN an unauthorized account attempts to update the foundation treasury
        vm.prank(alice);
        // THEN tx reverts because NotAuthorizedChanger
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        governanceManager.updateFoundationTreasury(bob);
    }

    /**
     * SCENARIO: Governor can update the KYC approver address
     */
    function test_UpdateKYCApprover() public {
        // WHEN the governor updates the KYC approver
        vm.prank(governor);
        vm.expectEmit();
        emit KycApproverUpdated(bob, governor);
        governanceManager.updateKYCApprover(bob);

        // THEN the KYC approver address is updated
        assertEq(governanceManager.kycApprover(), bob);
    }

    /**
     * SCENARIO: Unauthorized account cannot update the KYC approver
     */
    function test_FailUpdateKYCApproverByNotAuthorizedChanger() public {
        // WHEN an unauthorized account attempts to update the KYC approver
        vm.prank(alice);
        // THEN tx reverts because NotAuthorizedChanger
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        governanceManager.updateKYCApprover(bob);
    }

    /**
     * SCENARIO: Updater can update the upgrader address
     */
    function test_UpdateUpgrader() public {
        // WHEN the governor updates the upgrader address
        vm.prank(upgrader);
        vm.expectEmit();
        emit UpgraderUpdated(bob, upgrader);
        governanceManager.updateUpgrader(bob);

        // THEN the upgrader address is updated
        assertEq(governanceManager.upgrader(), bob);
    }

    /**
     * SCENARIO: functions should revert by ZeroAddressNotAllowed error when an address is zero
     */
    function test_RevertZeroAddress() public {
        vm.startPrank(governor);
        // WHEN governor calls updateGovernor using an invalid zero address
        //  THEN tx reverts
        vm.expectRevert(abi.encodeWithSelector(IGovernanceManagerRootstockCollective.ZeroAddressNotAllowed.selector));
        governanceManager.updateGovernor(address(0));

        // WHEN governor calls updateGovernor using an invalid zero address
        //  THEN tx reverts
        vm.expectRevert(abi.encodeWithSelector(IGovernanceManagerRootstockCollective.ZeroAddressNotAllowed.selector));
        governanceManager.updateFoundationTreasury(address(0));

        // WHEN governor calls updateKYCApprover using an invalid zero address
        //  THEN tx reverts
        vm.expectRevert(abi.encodeWithSelector(IGovernanceManagerRootstockCollective.ZeroAddressNotAllowed.selector));
        governanceManager.updateKYCApprover(address(0));

        vm.startPrank(upgrader);
        // WHEN governor calls updateUpgrader using an invalid zero address
        //  THEN tx reverts
        vm.expectRevert(abi.encodeWithSelector(IGovernanceManagerRootstockCollective.ZeroAddressNotAllowed.selector));
        governanceManager.updateUpgrader(address(0));
    }

    /**
     * SCENARIO: Unauthorized account cannot update the upgrader address
     */
    function test_FailUpdateUpgraderByNotAuthorizedChanger() public {
        // WHEN an unauthorized account attempts to update the upgrader
        vm.prank(alice);
        // THEN tx reverts because NotAuthorizedChanger
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotUpgrader.selector);
        governanceManager.updateUpgrader(bob);
    }

    /**
     * SCENARIO: AuthorizeChange recognizes authorized and unauthorized changers
     */
    function test_AuthorizeChange() public {
        governanceManager.validateAuthorizedChanger(governor);

        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        governanceManager.validateAuthorizedChanger(alice);
    }

    /**
     * SCENARIO: ValidateGovernor recognizes the governor and unauthorized accounts
     */
    function test_ValidateGovernor() public {
        governanceManager.validateGovernor(governor);

        vm.expectRevert(IGovernanceManagerRootstockCollective.NotGovernor.selector);
        governanceManager.validateGovernor(alice);
    }

    /**
     * SCENARIO: ValidateKYCApprover recognizes the KYC approver and unauthorized accounts
     */
    function test_ValidateKYCApprover() public {
        governanceManager.validateKycApprover(kycApprover);

        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        governanceManager.validateKycApprover(alice);
    }

    /**
     * SCENARIO: ValidateFoundationTreasury recognizes the foundation treasury and unauthorized accounts
     */
    function test_ValidateFoundationTreasury() public {
        governanceManager.validateFoundationTreasury(foundation);

        vm.expectRevert(IGovernanceManagerRootstockCollective.NotFoundationTreasury.selector);
        governanceManager.validateFoundationTreasury(alice);
    }

    /**
     * SCENARIO: AuthorizeUpgrade recognizes the authorized and unauthorized accounts
     */
    function test_AuthorizedUpgrade() public {
        governanceManager.validateAuthorizedUpgrader(upgrader);
        governanceManager.validateAuthorizedUpgrader(governor);

        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedUpgrader.selector);
        governanceManager.validateAuthorizedUpgrader(alice);
    }

    /**
     * SCENARIO: Governor can execute a change contract
     */
    function test_ExecuteChange() public {
        // GIVEN a sample change contract
        SampleChangeContract _changeContract = new SampleChangeContract();

        // WHEN the governor executes the change contract
        vm.prank(governor);
        vm.expectEmit();
        emit ChangeExecuted(_changeContract, governor);
        governanceManager.executeChange(_changeContract);

        // THEN the change contract is executed
        vm.assertTrue(_changeContract.executed());
    }

    /**
     * SCENARIO: Unauthorized account cannot execute a change contract
     */
    function test_FailExecuteChangeByNotGovernor() public {
        // GIVEN a sample change contract
        SampleChangeContract _changeContract = new SampleChangeContract();

        // WHEN an unauthorized account attempts to execute the change contract
        vm.prank(alice);
        // THEN tx reverts because NotGovernor
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotGovernor.selector);
        governanceManager.executeChange(_changeContract);
    }
}

/**
 * @title SampleChangeContract
 * @notice barebones contract that follows IChangeContractRootstockCollective interface
 * used to test the execution of changes
 */
contract SampleChangeContract is IChangeContractRootstockCollective {
    bool public executed = false;

    // solhint-disable-next-line foundry-test-functions
    function execute() external {
        executed = true;
    }
}
