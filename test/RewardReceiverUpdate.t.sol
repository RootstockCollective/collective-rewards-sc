// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "./BaseTest.sol";
import { BuilderRegistryRootstockCollective } from "../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract RewardReceiverUpdateTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event RewardReceiverUpdateRequested(address indexed builder_, address newRewardReceiver_);
    event RewardReceiverUpdateCancelled(address indexed builder_, address newRewardReceiver_);
    event RewardReceiverUpdated(address indexed builder_, address newRewardReceiver_);

    address internal _newRewardReceiver = makeAddr("newRewardReceiver");

    function _setUp() internal override { }

    function _initialState() internal {
        // GIVEN alice allocates to builder and builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
    }

    /**
     * SCENARIO: requestRewardReceiverUpdate should revert if is not called by the builder
     */
    function test_requesterIsNotABuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN calls requestRewardReceiverUpdate
        //   THEN tx reverts because caller is not an operational builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotOperational.selector);
        vm.prank(alice);
        builderRegistry.requestRewardReceiverUpdate(alice);
    }

    /**
     * SCENARIO: cancelRewardReceiverUpdate should revert if is not called by the builder
     */
    function test_cancellerIsNotABuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN calls cancelRewardReceiverUpdate
        //   THEN tx reverts because caller is not an operational builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotOperational.selector);
        vm.prank(alice);
        builderRegistry.cancelRewardReceiverUpdate();
    }

    /**
     * SCENARIO: approveNewRewardReceiver should revert if is not called by the kycApprover
     */
    function test_approverIsNotKYCApprover() public {
        // GIVEN a whitelisted builder
        //  WHEN alice calls approveNewRewardReceiver
        //   THEN tx reverts because caller is not an the KYC Approver
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        vm.prank(alice);
        builderRegistry.approveNewRewardReceiver(builder, alice);
    }

    /**
     * SCENARIO: approveNewRewardReceiver should revert if builder is not Operational
     */
    function test_approveANonOperationalBuilder() public {
        // GIVEN a none existent builder
        //  WHEN kycApprover calls approveNewRewardReceiver
        //   THEN tx reverts because Builder is not operational
        vm.prank(kycApprover);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotOperational.selector);
        builderRegistry.approveNewRewardReceiver(alice, alice);
    }

    /**
     * SCENARIO: Builder submits a new rewardReceiver update request
     */
    function test_requestRewardReceiverUpdate() public {
        // GIVEN a Whitelisted builder
        //  WHEN builder calls requestRewardReceiverUpdate
        vm.prank(builder);
        //   THEN RewardReceiverUpdateRequested event is emitted
        vm.expectEmit();
        emit RewardReceiverUpdateRequested(builder, _newRewardReceiver);
        builderRegistry.requestRewardReceiverUpdate(_newRewardReceiver);

        //   THEN his original rewardReceiver address is not afected
        assertEq(builderRegistry.rewardReceiver(builder), builder);
        //   THEN the _newRewardReceiver address is stored
        assertEq(builderRegistry.rewardReceiverUpdate(builder), _newRewardReceiver);
        //   THEN isRewardReceiverUpdatePending returns true
        assertEq(builderRegistry.isRewardReceiverUpdatePending(builder), true);
    }

    /**
     * SCENARIO: Builder cancels an request rewardReceiver update
     */
    function test_cancelRewardReceiverUpdate() public {
        // GIVEN a Whitelisted builder
        // AND builder has submitted a RewardReceiverUpdate
        vm.prank(builder);
        builderRegistry.requestRewardReceiverUpdate(_newRewardReceiver);
        //  WHEN Builder cancels the request
        //   THEN RewardReceiverUpdateCancelled event is emitted
        vm.prank(builder);
        vm.expectEmit();
        emit RewardReceiverUpdateCancelled(builder, builder);
        builderRegistry.cancelRewardReceiverUpdate();
        //   THEN the new rewardReceiver address is back to the original
        assertEq(builderRegistry.rewardReceiverUpdate(builder), builder);
        //   THEN isRewardReceiverUpdatePending returns false
        assertEq(builderRegistry.isRewardReceiverUpdatePending(builder), false);
    }

    /**
     * SCENARIO: KYCApprover approves an open rewardReceiver update request
     */
    function test_approveRewardReceiverUpdate() public {
        // GIVEN a Whitelisted builder
        // AND builder has submitted a RewardReceiverUpdate
        vm.prank(builder);
        builderRegistry.requestRewardReceiverUpdate(_newRewardReceiver);
        //  WHEN kycApprover approves the request, confirming the _newRewardReceiver
        //   THEN RewardReceiverUpdated event is emitted
        vm.prank(kycApprover);
        vm.expectEmit();
        emit RewardReceiverUpdated(builder, _newRewardReceiver);
        builderRegistry.approveNewRewardReceiver(builder, _newRewardReceiver);
        //   THEN the new rewardReceiver address is official
        assertEq(builderRegistry.rewardReceiver(builder), _newRewardReceiver);
        //   THEN isRewardReceiverUpdatePending returns false
        assertEq(builderRegistry.isRewardReceiverUpdatePending(builder), false);
    }
}
