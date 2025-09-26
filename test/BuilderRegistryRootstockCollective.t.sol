// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { BaseTest, GaugeRootstockCollective } from "./BaseTest.sol";
import { BuilderRegistryRootstockCollective } from "../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract BuilderRegistryRootstockCollectiveTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderInitialized(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event CommunityApproved(address indexed builder_);
    event CommunityBanned(address indexed builder_);
    event KYCPaused(address indexed builder_, bytes20 reason_);
    event KYCResumed(address indexed builder_);
    event SelfPaused(address indexed builder_);
    event SelfResumed(address indexed builder_, uint256 rewardPercentage_, uint256 cooldown_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    function test_OnlyKycApprover() public {
        // GIVEN a backer alice
        vm.startPrank(alice);

        // WHEN alice calls initializeBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.initializeBuilder(builder, builder, 0);

        // WHEN alice calls revokeBuilderKYC
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.revokeBuilderKYC(builder);

        // WHEN alice calls pauseBuilderKYC
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.pauseBuilderKYC(builder, "paused");

        // WHEN alice calls unpauseBuilderKYC
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.unpauseBuilderKYC(builder);
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
        builderRegistry.communityApproveBuilder(builder);

        // WHEN alice calls communityBanBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        builderRegistry.communityBanBuilder(builder);
        vm.stopPrank();
    }

    /**
     * SCENARIO: should revert if it is not called by a builder
     */
    function test_RevertBuilderDoesNotExist() public {
        // GIVEN  a whitelisted builder
        //  AND a backer alice
        vm.startPrank(alice);

        // WHEN alice calls pauseSelf
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        builderRegistry.pauseSelf();

        // WHEN alice calls unpauseSelf
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        builderRegistry.unpauseSelf(1 ether);
        vm.stopPrank();

        // WHEN kycApprover calls approveBuilderKYC for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        vm.prank(kycApprover);
        builderRegistry.approveBuilderKYC(alice);

        // WHEN governor calls communityBanBuilder for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        vm.prank(governor);
        builderRegistry.communityBanBuilder(alice);
    }

    /**
     * SCENARIO: kycApprover initializes a new builder
     */
    function test_InitializeBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        address _newRewardReceiver = makeAddr("newRewardReceiver");
        uint64 _backerRewardPercentage = 0.1 ether;
        // AND a kycApprover
        vm.prank(kycApprover);
        // WHEN calls initializeBuilder
        //  THEN BuilderInitialized event is emitted
        vm.expectEmit();
        emit BuilderInitialized(_newBuilder, _newRewardReceiver, _backerRewardPercentage);
        builderRegistry.initializeBuilder(_newBuilder, _newRewardReceiver, _backerRewardPercentage);

        // THEN builder is kycApproved
        (, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        assertEq(_kycApproved, true);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);

        // THEN builder rewards receiver is set
        assertEq(builderRegistry.rewardReceiver(_newBuilder), _newRewardReceiver);

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = builderRegistry.backerRewardPercentage(_newBuilder);
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
    function test_RevertBuilderAlreadyKYCApproved() public {
        // GIVEN a builder KYC approved
        //  AND a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to approveBuilderKYC
        //  THEN tx reverts because is already kycApproved
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyKYCApproved.selector);
        builderRegistry.approveBuilderKYC(builder);
    }

    /**
     * SCENARIO: initializeBuilder should revert if it is already initialized
     */
    function test_RevertBuilderAlreadyInitialized() public {
        // GIVEN a builder KYC approved
        //  AND a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to initializeBuilder
        //  THEN tx reverts because is already initialized
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyInitialized.selector);
        builderRegistry.initializeBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: approveBuilderKYC should revert if it is not initialized
     */
    function test_RevertNotKYCInitialized() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        builderRegistry.communityApproveBuilder(_newBuilder);

        // WHEN tries to approveBuilderKYC
        //  THEN tx reverts because is not initialized
        vm.prank(kycApprover);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotInitialized.selector);
        builderRegistry.approveBuilderKYC(_newBuilder);
    }

    /**
     * SCENARIO: initializeBuilder should revert if reward percentage is higher than 100
     */
    function test_InitializeBuilderInvalidBackerRewardPercentage() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a kycApprover
        vm.prank(kycApprover);

        // WHEN tries to initializeBuilder
        //  THEN tx reverts because is not a valid reward percentage
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBackerRewardPercentage.selector);
        builderRegistry.initializeBuilder(_newBuilder, _newBuilder, 2 ether);
    }

    /**
     * SCENARIO: Governor community approves a new builder
     */
    function test_CommunityApproveBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a KYCApprover initializes a builder
        vm.prank(kycApprover);
        builderRegistry.initializeBuilder(_newBuilder, _newBuilder, 0);

        // WHEN calls communityApproveBuilder
        //  THEN a GaugeCreated event is emitted
        vm.expectEmit(true, false, true, true); // ignore new gauge address
        emit GaugeCreated(_newBuilder, /*ignored*/ address(0), governor);

        //  THEN CommunityApproved event is emitted
        vm.expectEmit();
        emit CommunityApproved(_newBuilder);

        vm.prank(governor);
        GaugeRootstockCollective _newGauge = builderRegistry.communityApproveBuilder(_newBuilder);

        // THEN new gauge is assigned to the new builder
        assertEq(address(builderRegistry.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(builderRegistry.gaugeToBuilder(_newGauge), _newBuilder);
        // THEN builder is community approved
        (,, bool _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        assertEq(_communityApproved, true);
    }

    /**
     * SCENARIO: communityApproveBuilder should revert if it is already community approved
     */
    function test_RevertAlreadyCommunityApproved() public {
        // GIVEN an already community approved builder
        //  WHEN it tries to communityApproveBuilder
        //   THEN tx reverts because is already community approved
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyCommunityApproved.selector);
        vm.prank(governor);
        builderRegistry.communityApproveBuilder(builder);
    }

    /**
     * SCENARIO: kycApprover pauses a builder KYC
     */
    function test_PauseBuilderKyc() public {
        // GIVEN a whitelisted builder
        //  WHEN kycApprover calls pauseBuilderKYC
        vm.prank(kycApprover);
        //   THEN KYCPaused event is emitted
        vm.expectEmit();
        emit KYCPaused(builder, "paused");
        builderRegistry.pauseBuilderKYC(builder, "paused");

        // THEN builder is paused
        (,,, bool _kycPaused,,, bytes20 _reason) = builderRegistry.builderState(builder);
        assertEq(_kycPaused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");
    }

    /**
     * SCENARIO: KYC pause reason is 20 bytes long
     */
    function test_PauseReason20bytes() public {
        // GIVEN a whitelisted builder
        //  WHEN kycApprover calls pauseBuilderKYC
        vm.prank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "This is a short test");
        // THEN builder is paused
        (,,, bool _kycPaused,,, bytes20 _reason) = builderRegistry.builderState(builder);
        assertEq(_kycPaused, true);
        // THEN builder paused reason is "This is a short test"
        assertEq(_reason, "This is a short test");
    }

    /**
     * SCENARIO: pauseBuilderKYC again and overwritten the reason
     */
    function test_PauseWithAnotherReason() public {
        // GIVEN a KYC paused builder
        vm.prank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        (,,, bool _kycPaused,,, bytes20 _reason) = builderRegistry.builderState(builder);
        assertEq(_kycPaused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");

        // WHEN is paused again with a different reason
        vm.prank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "pausedAgain");
        // THEN builder is still paused
        (,,, _kycPaused,,, _reason) = builderRegistry.builderState(builder);
        assertEq(_kycPaused, true);
        // THEN builder paused reason is "pausedAgain"
        assertEq(_reason, "pausedAgain");
    }

    /**
     * SCENARIO: kycApprover unpauses Builder KYC
     */
    function test_UnpauseBuilderKYC() public {
        // GIVEN a KYC paused builder
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        // WHEN kycApprover calls unpauseBuilderKYC
        //  THEN KYCResumed event is emitted
        vm.expectEmit();
        emit KYCResumed(builder);
        builderRegistry.unpauseBuilderKYC(builder);

        // THEN builder is not paused
        (,,, bool _kycPaused,,, bytes20 _reason) = builderRegistry.builderState(builder);
        assertEq(_kycPaused, false);
        // THEN builder paused reason is clean
        assertEq(_reason, "");
    }

    /**
     * SCENARIO: self unpause a builder
     */
    function test_SelfResumeBuilder() public {
        // GIVEN a self paused builder
        vm.startPrank(builder);
        builderRegistry.pauseSelf();

        // WHEN calls unpauseSelf
        //  THEN SelfResumed event is emitted
        vm.expectEmit();
        emit SelfResumed(builder, 1 ether, block.timestamp + 2 weeks);
        builderRegistry.unpauseSelf(1 ether);

        // THEN builder is not self paused
        (,,,, bool _selfPaused,,) = builderRegistry.builderState(builder);
        assertEq(_selfPaused, false);
        // THEN gauge is not halted
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), false);
        // THEN halted gauges array length is 0
        assertEq(builderRegistry.getHaltedGaugesLength(), 0);
        // THEN gauge is rewarded
        assertEq(builderRegistry.isGaugeRewarded(address(gauge)), true);
        // THEN rewarded gauges array length is 2
        assertEq(builderRegistry.getGaugesLength(), 2);
        // THEN haltedGaugeLastPeriodFinish is 0
        assertEq(builderRegistry.haltedGaugeLastPeriodFinish(gauge), 0);
    }

    /**
     * SCENARIO: unpauseSelf should revert if it is not self paused
     */
    function test_UnpauseSelfBuilderRevert() public {
        // GIVEN a builder not paused
        vm.startPrank(builder);
        // WHEN tries to unpauseSelf
        //  THEN tx reverts because is not self paused
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotSelfPaused.selector);
        builderRegistry.unpauseSelf(1 ether);
        // AND the builder KYC is paused but not revoked
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        // WHEN tries to unpauseSelf
        //  THEN tx reverts because is not self paused
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotSelfPaused.selector);
        builderRegistry.unpauseSelf(1 ether);
    }

    /**
     * SCENARIO: unpauseSelf should revert if reward percentage is higher than 100
     */
    function test_UnpauseSelfBuilderInvalidBackerRewardPercentage() public {
        // GIVEN a self paused builder
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        //  WHEN tries to unpauseSelf with 200% of reward percentage
        //   THEN tx reverts because is not a valid reward percentage
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBackerRewardPercentage.selector);
        builderRegistry.unpauseSelf(2 ether);
    }

    /**
     * SCENARIO: Builder pauses itself
     */
    function test_PauseSelfBuilder() public {
        // GIVEN a whitelisted builder
        vm.startPrank(builder);

        // WHEN calls pauseSelf
        //  THEN SelfPaused event is emitted
        vm.expectEmit();
        emit SelfPaused(builder);
        builderRegistry.pauseSelf();

        // THEN builder is self paused
        (,,,, bool _selfPaused,,) = builderRegistry.builderState(builder);
        assertEq(_selfPaused, true);
        // THEN gauge is halted
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(builderRegistry.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(builderRegistry.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(builderRegistry.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(builderRegistry.haltedGaugeLastPeriodFinish(gauge), backersManager.periodFinish());
    }

    /**
     * SCENARIO: pauseSelf should revert if it is already self paused
     */
    function test_RevertBuilderAlreadySelfPaused() public {
        // GIVEN a self paused builder
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        // WHEN tries to pauseSelf again
        //  THEN tx reverts because is already self paused
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadySelfPaused.selector);
        builderRegistry.pauseSelf();
    }

    /**
     * SCENARIO: builder is whitelisted and KYC gets revoked. Cannot be initialized anymore
     */
    function test_RevertActivatingWhitelistedRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // WHEN kycApprover tries to initialize it again
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyInitialized.selector);
        builderRegistry.initializeBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: communityApproveBuilder before initialize it
     */
    function test_CommunityApproveBuilderBeforeInitialize() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = builderRegistry.communityApproveBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(builderRegistry.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(builderRegistry.gaugeToBuilder(_newGauge), _newBuilder);
        (bool _initialized, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is community approved
        assertEq(_communityApproved, true);
        // THEN builder is not initialized
        assertEq(_initialized, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is initialized
        vm.prank(kycApprover);
        builderRegistry.initializeBuilder(_newBuilder, _newBuilder, 0.1 ether);
        (_initialized, _kycApproved, _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is _community approved
        assertEq(_communityApproved, true);
        // THEN builder is initialized
        assertEq(_initialized, true);
        // THEN builder is KYC approved
        assertEq(_kycApproved, true);
    }

    /**
     * SCENARIO: community approved builder can be banned without being activated before
     */
    function test_communityBanBuilderWithoutActivate() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = builderRegistry.communityApproveBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(builderRegistry.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(builderRegistry.gaugeToBuilder(_newGauge), _newBuilder);
        (bool _initialized, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is community approved
        assertEq(_communityApproved, true);
        // THEN builder is not initialized
        assertEq(_initialized, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is banned
        vm.prank(governor);
        builderRegistry.communityBanBuilder(_newBuilder);
        (,, _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
    }

    /**
     * SCENARIO: pauseSelf reverts if KYC was revoked
     */
    function test_RevertRevokeBuilderNotKYCApproved() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        //  WHEN builders tries to self pause
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotKYCApproved.selector);
        builderRegistry.pauseSelf();
    }

    /**
     * SCENARIO: unpauseSelf reverts if KYC was revoked
     */
    function test_RevertUnpauseSelfBuilderNotKYCApproved() public {
        // GIVEN a self paused builder
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        // AND kycApprover revokes it KYC
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        //  WHEN builders tries to unpause itself
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotKYCApproved.selector);
        builderRegistry.unpauseSelf(0.1 ether);
    }

    /**
     * SCENARIO: revokeBuilderKYC reverts if KYC was already revoked
     */
    function test_RevertRevokeBuilderKYCNotKYCApproved() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        //  WHEN kycApprover tries to revoke it again
        //   THEN tx reverts because is not KYC approved
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotKYCApproved.selector);
        builderRegistry.revokeBuilderKYC(builder);
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
        builderRegistry.revokeBuilderKYC(builder);

        // THEN builder is not kycApproved
        (, bool _kycApproved,,,,,) = builderRegistry.builderState(builder);
        assertEq(_kycApproved, false);
        // THEN gauge is halted
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(builderRegistry.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(builderRegistry.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(builderRegistry.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(builderRegistry.haltedGaugeLastPeriodFinish(gauge), backersManager.periodFinish());
    }

    /**
     * SCENARIO: kycApprover approved builder KYC
     */
    function test_ApproveBuilderKYC() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // WHEN calls approveBuilderKYC
        //  THEN KYCApproved event is emitted
        vm.expectEmit();
        emit KYCApproved(builder);
        builderRegistry.approveBuilderKYC(builder);

        // THEN builder is kycApproved
        (, bool _kycApproved,,,,,) = builderRegistry.builderState(builder);
        assertEq(_kycApproved, true);
        // THEN gauge is not halted
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), false);
        // THEN halted gauges array length is 0
        assertEq(builderRegistry.getHaltedGaugesLength(), 0);
        // THEN gauge is rewarded
        assertEq(builderRegistry.isGaugeRewarded(address(gauge)), true);
        // THEN rewarded gauges array length is 2
        assertEq(builderRegistry.getGaugesLength(), 2);
        // THEN haltedGaugeLastPeriodFinish is 0
        assertEq(builderRegistry.haltedGaugeLastPeriodFinish(gauge), 0);
    }

    /**
     * SCENARIO: KYC revoked builder can be KYC paused and unpaused
     */
    function test_PauseKycOnKycRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);
        // AND kycApprover calls pauseBuilderKYC
        builderRegistry.pauseBuilderKYC(builder, "paused");
        (, bool _kycApproved,, bool _kycPaused,,,) = builderRegistry.builderState(builder);
        // THEN builder is not kycApproved
        assertEq(_kycApproved, false);
        // THEN builder is paused
        assertEq(_kycPaused, true);

        // AND kycApprover calls unpauseBuilderKYC
        builderRegistry.unpauseBuilderKYC(builder);
        (, _kycApproved,, _kycPaused,,,) = builderRegistry.builderState(builder);
        // THEN builder is still not kycApproved
        assertEq(_kycApproved, false);
        // THEN builder is not paused
        assertEq(_kycPaused, false);
    }

    /**
     * SCENARIO: self paused builder can be paused and unpaused by the kycApprover
     */
    function test_PauseSelfPausedBuilder() public {
        // GIVEN a self paused builder
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        // AND kycApprover calls pauseBuilderKYC
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        (,,, bool _kycPaused, bool _selfPaused,,) = builderRegistry.builderState(builder);
        // THEN builder is self paused
        assertEq(_selfPaused, true);
        // THEN builder is paused
        assertEq(_kycPaused, true);

        // AND kycApprover calls unpauseBuilderKYC
        builderRegistry.unpauseBuilderKYC(builder);
        (,,, _kycPaused, _selfPaused,,) = builderRegistry.builderState(builder);
        // THEN builder is still self paused
        assertEq(_selfPaused, true);
        // THEN builder is not paused
        assertEq(_kycPaused, false);
    }

    /**
     * SCENARIO: paused builder can be self paused and unpaused
     */
    function test_SelfPausePausedBuilder() public {
        // GIVEN paused builder
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        // AND builder pauses himself
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        (,,, bool _kycPaused, bool _selfPaused,,) = builderRegistry.builderState(builder);
        // THEN builder is paused
        assertEq(_kycPaused, true);
        // THEN builder is self paused
        assertEq(_selfPaused, true);

        // AND builder calls unpauseSelf
        builderRegistry.unpauseSelf(0.1 ether);
        (,,, _kycPaused, _selfPaused,,) = builderRegistry.builderState(builder);
        // THEN builder is still paused
        assertEq(_kycPaused, true);
        // THEN builder is not self paused
        assertEq(_selfPaused, false);
    }

    /**
     * SCENARIO: KYC paused builder can be KYC revoked
     */
    function test_KYCRevokePausedBuilder() public {
        // GIVEN KYC paused builder
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");

        // AND kycApprover calls revokeBuilderKYC
        builderRegistry.revokeBuilderKYC(builder);
        (, bool _kycApproved,, bool _kycPaused,,,) = builderRegistry.builderState(builder);
        // THEN builder is paused
        assertEq(_kycPaused, true);
        // THEN builder is not kyc approved
        assertEq(_kycApproved, false);
    }

    /**
     * SCENARIO: governor bans a builder
     */
    function test_CommunityBanBuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN governor calls communityBanBuilder
        //   THEN CommunityBanned event is emitted
        vm.expectEmit();
        emit CommunityBanned(builder);
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);

        // THEN builder is not community approved
        (,, bool _communityApproved,,,,) = builderRegistry.builderState(builder);
        assertEq(_communityApproved, false);
        // THEN gauge is halted
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(builderRegistry.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(builderRegistry.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(builderRegistry.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(builderRegistry.haltedGaugeLastPeriodFinish(gauge), backersManager.periodFinish());
    }

    /**
     * SCENARIO: communityBanBuilder reverts if builder was already banned
     */
    function test_RevertsCommunityBanBuilder() public {
        // GIVEN a banned builder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);

        //  WHEN governor calls communityBanBuilder
        //   THEN tx reverts because is not community approved
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotCommunityApproved.selector);
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);
    }

    /**
     * SCENARIO: whitelisted builder is banned. Cannot be community approved again
     */
    function test_RevertWhitelistingBuilderTwice() public {
        // GIVEN a banned builder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);

        //  WHEN governor calls communityApproveBuilder
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyExists.selector);
        vm.prank(governor);
        builderRegistry.communityApproveBuilder(builder);
    }

    /**
     * SCENARIO: pauseSelf reverts if it is not community approved
     */
    function test_RevertSelfPauseBuilderNotWhitelisted() public {
        // GIVEN a banned builder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);

        //  WHEN builders tries to pause itself
        //   THEN tx reverts because is not community approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotCommunityApproved.selector);
        builderRegistry.pauseSelf();
    }

    /**
     * SCENARIO: unpauseSelf reverts if it is not whitelisted
     */
    function test_RevertUnpauseSelfBuilderNotWhitelisted() public {
        // GIVEN a banned builder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);

        //  WHEN builders tries to unpause itself
        //   THEN tx reverts because is not whitelisted
        vm.prank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotCommunityApproved.selector);
        builderRegistry.unpauseSelf(0.1 ether);
    }

    /**
     * SCENARIO: banned builder can be paused and unpaused
     */
    function test_PauseBannedBuilder() public {
        // GIVEN a banned builder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);

        // AND kycApprover calls pauseBuilderKYC
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        (,, bool _communityApproved, bool _kycPaused,,,) = builderRegistry.builderState(builder);
        // THEN builder is not whitelisted
        assertEq(_communityApproved, false);
        // THEN builder is paused
        assertEq(_kycPaused, true);

        // AND kycApprover calls unpauseBuilderKYC
        builderRegistry.unpauseBuilderKYC(builder);
        (,, _communityApproved, _kycPaused,,,) = builderRegistry.builderState(builder);
        // THEN builder is still not community approved
        assertEq(_communityApproved, false);
        // THEN builder is not paused
        assertEq(_kycPaused, false);
    }

    /**
     * SCENARIO: paused builder can be banned
     */
    function test_BanPausedBuilder() public {
        // GIVEN a KYC paused builder
        vm.prank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");

        // AND governor calls communityBanBuilder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);
        (,, bool _communityApproved, bool _kycPaused,,,) = builderRegistry.builderState(builder);
        // THEN builder is paused
        assertEq(_kycPaused, true);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
    }

    /**
     * SCENARIO: banned builder can be KYC revoked
     */
    function test_KYCRevokeBannedBuilder() public {
        // GIVEN a banned builder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);

        // AND kycApprover calls revokeBuilderKYC
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);
        (, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(builder);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
        // THEN builder is not kyc approved
        assertEq(_kycApproved, false);
    }

    /**
     * SCENARIO: banned and KYC revoked builder is KYC approved again
     * Its gauge remains halted
     */
    function test_KYCApproveBannedBuilder() public {
        // GIVEN a banned and KYC revoked builder
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // AND kycApprover calls approveBuilderKYC
        vm.startPrank(kycApprover);
        builderRegistry.approveBuilderKYC(builder);

        (, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(builder);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
        // THEN builder is kyc approved
        assertEq(_kycApproved, true);
        // THEN gauge remains halted
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), true);
    }

    /**
     * SCENARIO: get gauges in range with start and length
     */
    function test_GetGaugesInRange() public {
        // GIVEN a builder with 5 gauges
        _prepareGauges();

        // WHEN getGaugesInRange is called
        //  THEN it returns the gauges in the range
        address[] memory _gauges = builderRegistry.getGaugesInRange(4, 5);
        assertEq(_gauges.length, 1);
        assertEq(builderRegistry.getGaugeAt(4), _gauges[0]);
    }

    /**
     * SCENARIO: get gauges in range with start and length
     */
    function test_GetGaugesInRangeAllGauges() public {
        // GIVEN a builder with 5 gauges
        _prepareGauges();

        // WHEN getGaugesInRange is called
        //  THEN it returns the gauges in the range
        address[] memory _gauges = builderRegistry.getGaugesInRange(0, 4);
        assertEq(_gauges.length, 4);
        assertEq(builderRegistry.getGaugeAt(0), _gauges[0]);
        assertEq(builderRegistry.getGaugeAt(1), _gauges[1]);
        assertEq(builderRegistry.getGaugeAt(2), _gauges[2]);
        assertEq(builderRegistry.getGaugeAt(3), _gauges[3]);
    }

    /**
     * SCENARIO: get gauges with length exceeds available gauges
     */
    function test_GetGaugesInRangeLengthExceedsAvailable() public {
        // GIVEN a builder with 5 gauges
        _prepareGauges();

        // WHEN getGaugesInRange is called
        //  THEN it returns the gauges in the range
        address[] memory _gauges = builderRegistry.getGaugesInRange(3, 10);
        assertEq(_gauges.length, 2);
        assertEq(builderRegistry.getGaugeAt(3), _gauges[0]);
        assertEq(builderRegistry.getGaugeAt(4), _gauges[1]);
    }

    /**
     * SCENARIO: get gauges in range with start out of bounds
     */
    function test_GetGaugesInRangeStartOutOfBounds() public {
        // GIVEN a builder with 5 gauges
        _prepareGauges();

        // WHEN getGaugesInRange is called
        //  THEN tx reverts because start is out of bounds
        vm.expectRevert(abi.encodeWithSelector(BuilderRegistryRootstockCollective.InvalidIndex.selector));
        builderRegistry.getGaugesInRange(5, 2);
    }

    function _prepareGauges() internal {
        for (uint256 i = 0; i < 3; i++) {
            address _gauge = makeAddr(string(abi.encode(i)));
            _whitelistBuilder(_gauge, builder, 1 ether);
        }
    }
}
