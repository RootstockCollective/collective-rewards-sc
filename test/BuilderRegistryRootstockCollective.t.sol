// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, GaugeRootstockCollective } from "./BaseTest.sol";
import { BuilderRegistryRootstockCollective } from "../src/backersManager/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract BuilderRegistryRootstockCollectiveTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event CommunityApproved(address indexed builder_);
    event Dewhitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Unpaused(address indexed builder_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    function test_OnlyKycApprover() public {
        // GIVEN a backer alice
        vm.startPrank(alice);

        // WHEN alice calls activateBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        backersManager.activateBuilder(builder, builder, 0);

        // WHEN alice calls revokeBuilderKYC
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        backersManager.revokeBuilderKYC(builder);

        // WHEN alice calls pauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        backersManager.pauseBuilder(builder, "paused");

        // WHEN alice calls unpauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        backersManager.unpauseBuilder(builder);
        vm.stopPrank();
    }

    /**
     * SCENARIO: functions protected by OnlyGovernor should revert when are not
     *  called by Governor
     */
    function test_OnlyGovernor() public {
        // GIVEN a backer alice
        vm.startPrank(alice);

        // WHEN alice calls communityApproveBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        backersManager.communityApproveBuilder(builder);

        // WHEN alice calls dewhitelistBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        backersManager.dewhitelistBuilder(builder);
        vm.stopPrank();
    }

    /**
     * SCENARIO: should revert if it is not called by a builder
     */
    function test_RevertBuilderDoesNotExist() public {
        // GIVEN  a whitelisted builder
        //  AND a backer alice
        vm.startPrank(alice);

        // WHEN alice calls revokeBuilder
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        backersManager.revokeBuilder();

        // WHEN alice calls permitBuilder
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        backersManager.permitBuilder(1 ether);
        vm.stopPrank();

        // WHEN kycApprover calls approveBuilderKYC for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        vm.prank(kycApprover);
        backersManager.approveBuilderKYC(alice);

        // WHEN governor calls dewhitelistBuilder for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        vm.prank(governor);
        backersManager.dewhitelistBuilder(alice);
    }

    /**
     * SCENARIO: kycApprover activates a new builder
     */
    function test_ActivateBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        address _newRewardReceiver = makeAddr("newRewardReceiver");
        uint64 _backerRewardPercentage = 0.1 ether;
        // AND a kycApprover
        vm.prank(kycApprover);
        // WHEN calls activateBuilder
        //  THEN BuilderActivated event is emitted
        vm.expectEmit();
        emit BuilderActivated(_newBuilder, _newRewardReceiver, _backerRewardPercentage);
        backersManager.activateBuilder(_newBuilder, _newRewardReceiver, _backerRewardPercentage);

        // THEN builder is kycApproved
        (, bool _kycApproved, bool _communityApproved,,,,) = backersManager.builderState(_newBuilder);
        assertEq(_kycApproved, true);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);

        // THEN builder rewards receiver is set
        assertEq(backersManager.builderRewardReceiver(_newBuilder), _newRewardReceiver);

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = backersManager.backerRewardPercentage(_newBuilder);
        // THEN previous backer reward percentage is 10%
        assertEq(_previous, _backerRewardPercentage);
        // THEN next backer reward percentage is 10%
        assertEq(_next, _backerRewardPercentage);
        // THEN backer reward percentage cooldown end time is the current block time
        assertEq(_cooldownEndTime, block.timestamp);
    }

    /**
     * SCENARIO: approveBuilderKYC should revert if it is already approved
     */
    function test_RevertAlreadyKYCApproved() public {
        // GIVEN a builder KYC approved
        //  AND a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to approveBuilderKYC
        //  THEN tx reverts because is already kycApproved
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyKYCApproved.selector);
        backersManager.approveBuilderKYC(builder);
    }

    /**
     * SCENARIO: activateBuilder should revert if it is already activated
     */
    function test_RevertAlreadyKYCActivated() public {
        // GIVEN a builder KYC approved
        //  AND a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is already activated
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyActivated.selector);
        backersManager.activateBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: approveBuilderKYC should revert if it is not activated
     */
    function test_RevertNotKYCActivated() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        backersManager.communityApproveBuilder(_newBuilder);

        // WHEN tries to approveBuilderKYC
        //  THEN tx reverts because is not activated
        vm.prank(kycApprover);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotActivated.selector);
        backersManager.approveBuilderKYC(_newBuilder);
    }

    /**
     * SCENARIO: activateBuilder should revert if reward percentage is higher than 100
     */
    function test_ActivateBuilderInvalidBackerRewardPercentage() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a kycApprover
        vm.prank(kycApprover);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is not a valid reward percentage
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBackerRewardPercentage.selector);
        backersManager.activateBuilder(_newBuilder, _newBuilder, 2 ether);
    }

    /**
     * SCENARIO: Governor community approves a new builder
     */
    function test_CommunityApproveBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a KYCApprover activates a builder
        vm.prank(kycApprover);
        backersManager.activateBuilder(_newBuilder, _newBuilder, 0);

        // WHEN calls communityApproveBuilder
        //  THEN a GaugeCreated event is emitted
        vm.expectEmit(true, false, true, true); // ignore new gauge address
        emit GaugeCreated(_newBuilder, /*ignored*/ address(0), governor);

        //  THEN CommunityApproved event is emitted
        vm.expectEmit();
        emit CommunityApproved(_newBuilder);

        vm.prank(governor);
        GaugeRootstockCollective _newGauge = backersManager.communityApproveBuilder(_newBuilder);

        // THEN new gauge is assigned to the new builder
        assertEq(address(backersManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(_newGauge.builder(), _newBuilder);
        // THEN builder is community approved
        (,, bool _communityApproved,,,,) = backersManager.builderState(_newBuilder);
        assertEq(_communityApproved, true);
    }

    /**
     * SCENARIO: communityApproveBuilder should revert if it is already community approved
     */
    function test_RevertAlreadyCommunityApproved() public {
        // GIVEN an already community approved builder
        //  WHEN it tries to communityApproveBuilder
        //   THEN tx reverts because is already community approved
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyCommunityApproved.selector);
        vm.prank(governor);
        backersManager.communityApproveBuilder(builder);
    }

    /**
     * SCENARIO: kycApprover pause a builder
     */
    function test_PauseBuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN kycApprover calls pauseBuilder
        vm.prank(kycApprover);
        //   THEN Paused event is emitted
        vm.expectEmit();
        emit Paused(builder, "paused");
        backersManager.pauseBuilder(builder, "paused");

        // THEN builder is paused
        (,,, bool _paused,,, bytes20 _reason) = backersManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");
    }

    /**
     * SCENARIO: pause reason is 20 bytes long
     */
    function test_PauseReason20bytes() public {
        // GIVEN a whitelisted builder
        //  WHEN kycApprover calls pauseBuilder
        vm.prank(kycApprover);
        backersManager.pauseBuilder(builder, "This is a short test");
        // THEN builder is paused
        (,,, bool _paused,,, bytes20 _reason) = backersManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "This is a short test"
        assertEq(_reason, "This is a short test");
    }

    /**
     * SCENARIO: pauseBuilder again and overwritten the reason
     */
    function test_PauseWithAnotherReason() public {
        // GIVEN a paused builder
        //  AND kycApprover calls pauseBuilder
        vm.prank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");
        (,,, bool _paused,,, bytes20 _reason) = backersManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");

        // WHEN is paused again with a different reason
        vm.prank(kycApprover);
        backersManager.pauseBuilder(builder, "pausedAgain");
        // THEN builder is still paused
        (,,, _paused,,, _reason) = backersManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "pausedAgain"
        assertEq(_reason, "pausedAgain");
    }

    /**
     * SCENARIO: kycApprover unpauseBuilder a builder
     */
    function test_UnpauseBuilder() public {
        // GIVEN a paused builder
        vm.startPrank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");
        // WHEN kycApprover calls unpauseBuilder
        //  THEN Unpaused event is emitted
        vm.expectEmit();
        emit Unpaused(builder);
        backersManager.unpauseBuilder(builder);

        // THEN builder is not paused
        (,,, bool _paused,,, bytes20 _reason) = backersManager.builderState(builder);
        assertEq(_paused, false);
        // THEN builder paused reason is clean
        assertEq(_reason, "");
    }

    /**
     * SCENARIO: permit a builder
     */
    function test_PermitBuilder() public {
        // GIVEN a Revoked builder
        vm.startPrank(builder);
        backersManager.revokeBuilder();

        // WHEN calls permitBuilder
        //  THEN Permitted event is emitted
        vm.expectEmit();
        emit Permitted(builder, 1 ether, block.timestamp + 2 weeks);
        backersManager.permitBuilder(1 ether);

        // THEN builder is not revoked
        (,,,, bool _revoked,,) = backersManager.builderState(builder);
        assertEq(_revoked, false);
        // THEN gauge is not halted
        assertEq(backersManager.isGaugeHalted(address(gauge)), false);
        // THEN halted gauges array length is 0
        assertEq(backersManager.getHaltedGaugesLength(), 0);
        // THEN gauge is rewarded
        assertEq(backersManager.isGaugeRewarded(address(gauge)), true);
        // THEN rewarded gauges array length is 2
        assertEq(backersManager.getGaugesLength(), 2);
        // THEN haltedGaugeLastPeriodFinish is 0
        assertEq(backersManager.haltedGaugeLastPeriodFinish(gauge), 0);
    }

    /**
     * SCENARIO: permitBuilder should revert if it is not revoked
     */
    function test_PermitBuilderRevert() public {
        // GIVEN a builder not paused
        vm.startPrank(builder);
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.expectRevert(BuilderRegistryRootstockCollective.NotRevoked.selector);
        backersManager.permitBuilder(1 ether);
        // AND the builder is paused but not revoked
        vm.startPrank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotRevoked.selector);
        backersManager.permitBuilder(1 ether);
    }

    /**
     * SCENARIO: permitBuilder should revert if reward percentage is higher than 100
     */
    function test_PermitBuilderInvalidBackerRewardPercentage() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        backersManager.revokeBuilder();
        //  WHEN tries to permitBuilder with 200% of reward percentage
        //   THEN tx reverts because is not a valid reward percentage
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBackerRewardPercentage.selector);
        backersManager.permitBuilder(2 ether);
    }

    /**
     * SCENARIO: Builder revoke itself
     */
    function test_RevokeBuilder() public {
        // GIVEN a whitelisted builder
        vm.startPrank(builder);

        // WHEN calls revokeBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit Revoked(builder);
        backersManager.revokeBuilder();

        // THEN builder is revoked
        (,,,, bool _revoked,,) = backersManager.builderState(builder);
        assertEq(_revoked, true);
        // THEN gauge is halted
        assertEq(backersManager.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(backersManager.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(backersManager.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(backersManager.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(backersManager.haltedGaugeLastPeriodFinish(gauge), backersManager.periodFinish());
    }

    /**
     * SCENARIO: revokeBuilder should revert if it is already revoked
     */
    function test_RevertAlreadyRevoked() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        backersManager.revokeBuilder();
        // WHEN tries to revokeBuilder again
        //  THEN tx reverts because is already revoked
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyRevoked.selector);
        backersManager.revokeBuilder();
    }

    /**
     * SCENARIO: builder is whitelisted and KYC gets revoked. Cannot be activated anymore
     */
    function test_RevertActivatingWhitelistedRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);

        // WHEN kycApprover tries to activating it again
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyActivated.selector);
        backersManager.activateBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: communityApproveBuilder before activating it
     */
    function test_CommunityApproveBuilderBeforeActivate() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = backersManager.communityApproveBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(backersManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(_newGauge.builder(), _newBuilder);
        (bool _activated, bool _kycApproved, bool _communityApproved,,,,) = backersManager.builderState(_newBuilder);
        // THEN builder is community approved
        assertEq(_communityApproved, true);
        // THEN builder is not activated
        assertEq(_activated, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is activated
        vm.prank(kycApprover);
        backersManager.activateBuilder(_newBuilder, _newBuilder, 0.1 ether);
        (_activated, _kycApproved, _communityApproved,,,,) = backersManager.builderState(_newBuilder);
        // THEN builder is _community approved
        assertEq(_communityApproved, true);
        // THEN builder is activated
        assertEq(_activated, true);
        // THEN builder is KYC approved
        assertEq(_kycApproved, true);
    }

    /**
     * SCENARIO: community approved builder can be de-whitelisted without being activated before
     */
    function test_DeWhitelistBuilderWithoutActivate() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = backersManager.communityApproveBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(backersManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(_newGauge.builder(), _newBuilder);
        (bool _activated, bool _kycApproved, bool _communityApproved,,,,) = backersManager.builderState(_newBuilder);
        // THEN builder is community approved
        assertEq(_communityApproved, true);
        // THEN builder is not activated
        assertEq(_activated, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is de-whitelisted
        vm.prank(governor);
        backersManager.dewhitelistBuilder(_newBuilder);
        (,, _communityApproved,,,,) = backersManager.builderState(_newBuilder);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
    }

    /**
     * SCENARIO: revokeBuilder reverts if KYC was revoked
     */
    function test_RevertRevokeBuilderNotKYCApproved() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);

        //  WHEN builders tries to revoke it
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotKYCApproved.selector);
        backersManager.revokeBuilder();
    }

    /**
     * SCENARIO: permitBuilder reverts if KYC was revoked
     */
    function test_RevertPermitBuilderNotKYCApproved() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        backersManager.revokeBuilder();
        // AND kycApprover revokes it KYC
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);

        //  WHEN builders tries to permit it
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotKYCApproved.selector);
        backersManager.permitBuilder(0.1 ether);
    }

    /**
     * SCENARIO: revokeBuilderKYC reverts if KYC was already revoked
     */
    function test_RevertRevokeBuilderKYCNotKYCApproved() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);

        //  WHEN kycApprover tries to revoke it again
        //   THEN tx reverts because is not KYC approved
        vm.expectRevert(BuilderRegistryRootstockCollective.NotKYCApproved.selector);
        backersManager.revokeBuilderKYC(builder);
    }

    /**
     * SCENARIO: kycApprover revokes builder KYC
     */
    function test_RevokeBuilderKYC() public {
        // GIVEN a CommunityApproved builder
        vm.startPrank(kycApprover);

        // WHEN kycApprover calls revokeBuilderKYC
        //  THEN KYCRevoked event is emitted
        vm.expectEmit();
        emit KYCRevoked(builder);
        backersManager.revokeBuilderKYC(builder);

        // THEN builder is not kycApproved
        (, bool _kycApproved,,,,,) = backersManager.builderState(builder);
        assertEq(_kycApproved, false);
        // THEN gauge is halted
        assertEq(backersManager.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(backersManager.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(backersManager.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(backersManager.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(backersManager.haltedGaugeLastPeriodFinish(gauge), backersManager.periodFinish());
    }

    /**
     * SCENARIO: kycApprover approved builder KYC
     */
    function test_ApproveBuilderKYC() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);

        // WHEN calls approveBuilderKYC
        //  THEN KYCApproved event is emitted
        vm.expectEmit();
        emit KYCApproved(builder);
        backersManager.approveBuilderKYC(builder);

        // THEN builder is kycApproved
        (, bool _kycApproved,,,,,) = backersManager.builderState(builder);
        assertEq(_kycApproved, true);
        // THEN gauge is not halted
        assertEq(backersManager.isGaugeHalted(address(gauge)), false);
        // THEN halted gauges array length is 0
        assertEq(backersManager.getHaltedGaugesLength(), 0);
        // THEN gauge is rewarded
        assertEq(backersManager.isGaugeRewarded(address(gauge)), true);
        // THEN rewarded gauges array length is 2
        assertEq(backersManager.getGaugesLength(), 2);
        // THEN haltedGaugeLastPeriodFinish is 0
        assertEq(backersManager.haltedGaugeLastPeriodFinish(gauge), 0);
    }

    /**
     * SCENARIO: KYC revoked builder can be paused and unpaused
     */
    function test_PauseKYCRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);
        // AND kycApprover calls pauseBuilder
        backersManager.pauseBuilder(builder, "paused");
        (, bool _kycApproved,, bool _paused,,,) = backersManager.builderState(builder);
        // THEN builder is not kycApproved
        assertEq(_kycApproved, false);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        backersManager.unpauseBuilder(builder);
        (, _kycApproved,, _paused,,,) = backersManager.builderState(builder);
        // THEN builder is still not kycApproved
        assertEq(_kycApproved, false);
        // THEN builder is not paused
        assertEq(_paused, false);
    }

    /**
     * SCENARIO: revoked builder can be paused and unpaused
     */
    function test_PauseRevokedBuilder() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        backersManager.revokeBuilder();
        // AND kycApprover calls pauseBuilder
        vm.startPrank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");
        (,,, bool _paused, bool _revoked,,) = backersManager.builderState(builder);
        // THEN builder is revoked
        assertEq(_revoked, true);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        backersManager.unpauseBuilder(builder);
        (,,, _paused, _revoked,,) = backersManager.builderState(builder);
        // THEN builder is still revoked
        assertEq(_revoked, true);
        // THEN builder is not paused
        assertEq(_paused, false);
    }

    /**
     * SCENARIO: paused builder can be revoked and permitted
     */
    function test_RevokePausedBuilder() public {
        // GIVEN paused builder
        vm.startPrank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");
        // AND builder calls revokeBuilder
        vm.startPrank(builder);
        backersManager.revokeBuilder();
        (,,, bool _paused, bool _revoked,,) = backersManager.builderState(builder);
        // THEN builder is paused
        assertEq(_paused, true);
        // THEN builder is revoked
        assertEq(_revoked, true);

        // AND builder calls permitBuilder
        backersManager.permitBuilder(0.1 ether);
        (,,, _paused, _revoked,,) = backersManager.builderState(builder);
        // THEN builder is still paused
        assertEq(_paused, true);
        // THEN builder is not revoked
        assertEq(_revoked, false);
    }

    /**
     * SCENARIO: paused builder can be KYC revoked
     */
    function test_KYCRevokePausedBuilder() public {
        // GIVEN paused builder
        vm.startPrank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");

        // AND kycApprover calls revokeBuilderKYC
        backersManager.revokeBuilderKYC(builder);
        (, bool _kycApproved,, bool _paused,,,) = backersManager.builderState(builder);
        // THEN builder is paused
        assertEq(_paused, true);
        // THEN builder is not kyc approved
        assertEq(_kycApproved, false);
    }

    /**
     * SCENARIO: governor dewhitelist a builder
     */
    function test_DewhitelistBuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN governor calls dewhitelistBuilder
        //   THEN Dewhitelisted event is emitted
        vm.expectEmit();
        emit Dewhitelisted(builder);
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);

        // THEN builder is not community approved
        (,, bool _communityApproved,,,,) = backersManager.builderState(builder);
        assertEq(_communityApproved, false);
        // THEN gauge is halted
        assertEq(backersManager.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(backersManager.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(backersManager.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(backersManager.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(backersManager.haltedGaugeLastPeriodFinish(gauge), backersManager.periodFinish());
    }

    /**
     * SCENARIO: dewhitelist reverts if builder was already de-whitelisted
     */
    function test_RevertsDewhitelistBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);

        //  WHEN governor calls dewhitelistBuilder
        //   THEN tx reverts because is not community approved
        vm.expectRevert(BuilderRegistryRootstockCollective.NotCommunityApproved.selector);
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);
    }

    /**
     * SCENARIO: whitelisted builder is de-whitelisted. Cannot be community approved again
     */
    function test_RevertWhitelistingBuilderTwice() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);

        //  WHEN governor calls communityApproveBuilder
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyExists.selector);
        vm.prank(governor);
        backersManager.communityApproveBuilder(builder);
    }

    /**
     * SCENARIO: revokeBuilder reverts if it is not community approved
     */
    function test_RevertRevokeBuilderNotWhitelisted() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);

        //  WHEN builders tries to revoke itself
        //   THEN tx reverts because is not community approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotCommunityApproved.selector);
        backersManager.revokeBuilder();
    }

    /**
     * SCENARIO: permitBuilder reverts if it is not whitelisted
     */
    function test_RevertPermitBuilderNotWhitelisted() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);

        //  WHEN builders tries to permit it
        //   THEN tx reverts because is not whitelisted
        vm.prank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotCommunityApproved.selector);
        backersManager.permitBuilder(0.1 ether);
    }

    /**
     * SCENARIO: de-whitelisted builder can be paused and unpaused
     */
    function test_PauseDewhitelistedBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);

        // AND kycApprover calls pauseBuilder
        vm.startPrank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");
        (,, bool _communityApproved, bool _paused,,,) = backersManager.builderState(builder);
        // THEN builder is not whitelisted
        assertEq(_communityApproved, false);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        backersManager.unpauseBuilder(builder);
        (,, _communityApproved, _paused,,,) = backersManager.builderState(builder);
        // THEN builder is still not community approved
        assertEq(_communityApproved, false);
        // THEN builder is not paused
        assertEq(_paused, false);
    }

    /**
     * SCENARIO: paused builder can be de-whitelisted
     */
    function test_DewhitelistPausedBuilder() public {
        // GIVEN paused builder
        vm.prank(kycApprover);
        backersManager.pauseBuilder(builder, "paused");

        // AND governor calls dewhitelistBuilder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);
        (,, bool _communityApproved, bool _paused,,,) = backersManager.builderState(builder);
        // THEN builder is paused
        assertEq(_paused, true);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
    }

    /**
     * SCENARIO: de-whitelisted builder can be KYC revoked
     */
    function test_KYCRevokeDewhitelistedBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);

        // AND kycApprover calls revokeBuilderKYC
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);
        (, bool _kycApproved, bool _communityApproved,,,,) = backersManager.builderState(builder);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
        // THEN builder is not kyc approved
        assertEq(_kycApproved, false);
    }

    /**
     * SCENARIO: de-whitelisted and KYC revoked builder is KYC approved again
     * Its gauge remains halted
     */
    function test_KYCApproveDewhitelistedBuilder() public {
        // GIVEN a de-whitelisted and KYC revoked builder
        vm.prank(governor);
        backersManager.dewhitelistBuilder(builder);
        vm.startPrank(kycApprover);
        backersManager.revokeBuilderKYC(builder);

        // AND kycApprover calls approveBuilderKYC
        vm.startPrank(kycApprover);
        backersManager.approveBuilderKYC(builder);

        (, bool _kycApproved, bool _communityApproved,,,,) = backersManager.builderState(builder);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
        // THEN builder is kyc approved
        assertEq(_kycApproved, true);
        // THEN gauge remains halted
        assertEq(backersManager.isGaugeHalted(address(gauge)), true);
    }
}
