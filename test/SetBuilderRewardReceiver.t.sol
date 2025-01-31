// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { BuilderErrors } from "../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract SetBuilderRewardReceiverTest is BaseTest {
    // // -----------------------------
    // // ----------- Events ----------
    // // -----------------------------
    // event BuilderRewardReceiverReplacementRequested(address indexed builder_, address newRewardReceiver_);
    // event BuilderRewardReceiverReplacementCancelled(address indexed builder_, address cuuRewardReceiver_);
    // event BuilderRewardReceiverReplacementApproved(address indexed builder_, address newRewardReceiver_);
    // address internal _newRewardReceiver = makeAddr("newRewardReceiver");
    // function _setUp() internal override {}
    // function _initialState() internal {
    //     // GIVEN alice allocates to builder and builder2
    //     vm.startPrank(alice);
    //     allocationsArray[0] = 2 ether;
    //     allocationsArray[1] = 6 ether;
    //     backersManager.allocateBatch(gaugesArray, allocationsArray);
    //     vm.stopPrank();
    //     // AND bob allocates to builder2
    //     vm.startPrank(bob);
    //     allocationsArray[0] = 0 ether;
    //     allocationsArray[1] = 8 ether;
    //     backersManager.allocateBatch(gaugesArray, allocationsArray);
    //     vm.stopPrank();
    // }
    // /**
    //  * SCENARIO: submitRewardReceiverReplacementRequest should revert if is not called by the builder
    //  */
    // function test_submitterIsNotABuilder() public {
    //     // GIVEN a whitelisted builder
    //     //  WHEN calls submitRewardReceiverReplacementRequest
    //     //   THEN tx reverts because caller is not an operational builder
    //     vm.expectRevert(BuilderErrors.NotOperational.selector);
    //     vm.prank(alice);
    //     builderRegistry.submitRewardReceiverReplacementRequest(alice);
    // }
    // /**
    //  * SCENARIO: cancelRewardReceiverReplacementRequest should revert if is not called by the builder
    //  */
    // function test_cancellerIsNotABuilder() public {
    //     // GIVEN a whitelisted builder
    //     //  WHEN calls cancelRewardReceiverReplacementRequest
    //     //   THEN tx reverts because caller is not an operational builder
    //     vm.expectRevert(BuilderErrors.NotOperational.selector);
    //     vm.prank(alice);
    //     builderRegistry.cancelRewardReceiverReplacementRequest();
    // }
    // /**
    //  * SCENARIO: approveBuilderRewardReceiverReplacement should revert if is not called by the kycApprover
    //  */
    // function test_approverIsNotKYCApprover() public {
    //     // GIVEN a whitelisted builder
    //     //  WHEN alice calls approveBuilderRewardReceiverReplacement
    //     //   THEN tx reverts because caller is not an the KYC Approver
    //     vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
    //     vm.prank(alice);
    //     builderRegistry.approveBuilderRewardReceiverReplacement(activeBuilder, alice);
    // }
    // /**
    //  * SCENARIO: approveBuilderRewardReceiverReplacement should revert if builder is not Operational
    //  */
    // function test_approveANonOperationalBuilder() public {
    //     // GIVEN a none existent builder
    //     //  WHEN kycApprover calls approveBuilderRewardReceiverReplacement
    //     //   THEN tx reverts because Builder is not operational
    //     vm.prank(kycApprover);
    //     vm.expectRevert(BuilderErrors.NotOperational.selector);
    //     builderRegistry.approveBuilderRewardReceiverReplacement(alice, alice);
    // }
    // /**
    //  * SCENARIO: Builder submits a new rewardReceiver replacement request
    //  */
    // function test_submitRewardReceiverReplacementRequest() public {
    //     // GIVEN a Whitelisted builder
    //     //  WHEN builder calls submitRewardReceiverReplacementRequest
    //     vm.prank(activeBuilder);
    //     //   THEN BuilderRewardReceiverReplacementRequested event is emitted
    //     vm.expectEmit();
    //     emit BuilderRewardReceiverReplacementRequested(activeBuilder, _newRewardReceiver);
    //     builderRegistry.submitRewardReceiverReplacementRequest(_newRewardReceiver);
    //     //   THEN his original rewardReceiver address is not afected
    //     assertEq(builderRegistry.builderRewardReceiver(activeBuilder), activeBuilder);
    //     //   THEN the _newRewardReceiver address is stored on the replacement storage for him
    //     assertEq(builderRegistry.builderRewardReceiverReplacement(activeBuilder), _newRewardReceiver);
    //     //   THEN hasBuilderRewardReceiverPendingApproval returns true
    //     assertEq(builderRegistry.hasBuilderRewardReceiverPendingApproval(activeBuilder), true);
    // }
    // /**
    //  * SCENARIO: Builder cancels an open rewardReceiver replacement request
    //  */
    // function test_cancelRewardReceiverReplacementRequest() public {
    //     // GIVEN a Whitelisted builder
    //     // AND builder has submitted a RewardReceiverReplacementRequest
    //     vm.prank(activeBuilder);
    //     builderRegistry.submitRewardReceiverReplacementRequest(_newRewardReceiver);
    //     //  WHEN Builder cancels the request
    //     //   THEN BuilderRewardReceiverReplacementCancelled event is emitted
    //     vm.prank(activeBuilder);
    //     vm.expectEmit();
    //     emit BuilderRewardReceiverReplacementCancelled(activeBuilder, activeBuilder);
    //     builderRegistry.cancelRewardReceiverReplacementRequest();
    //     //   THEN the new rewardReceiver address is back to the original
    //     assertEq(builderRegistry.builderRewardReceiverReplacement(activeBuilder), activeBuilder);
    //     //   THEN hasBuilderRewardReceiverPendingApproval returns false
    //     assertEq(builderRegistry.hasBuilderRewardReceiverPendingApproval(activeBuilder), false);
    // }
    // /**
    //  * SCENARIO: KYCApprover approves an open rewardReceiver replacement request
    //  */
    // function test_approveRewardReceiverReplacementRequest() public {
    //     // GIVEN a Whitelisted builder
    //     // AND builder has submitted a RewardReceiverReplacementRequest
    //     vm.prank(activeBuilder);
    //     builderRegistry.submitRewardReceiverReplacementRequest(_newRewardReceiver);
    //     //  WHEN kycApprover approves the request, confirming the _newRewardReceiver
    //     //   THEN BuilderRewardReceiverReplacementApproved event is emitted
    //     vm.prank(kycApprover);
    //     vm.expectEmit();
    //     emit BuilderRewardReceiverReplacementApproved(activeBuilder, _newRewardReceiver);
    //     builderRegistry.approveBuilderRewardReceiverReplacement(activeBuilder, _newRewardReceiver);
    //     //   THEN the new rewardReceiver address is official
    //     assertEq(builderRegistry.builderRewardReceiver(activeBuilder), _newRewardReceiver);
    //     //   THEN hasBuilderRewardReceiverPendingApproval returns false
    //     assertEq(builderRegistry.hasBuilderRewardReceiverPendingApproval(activeBuilder), false);
    // }
}
