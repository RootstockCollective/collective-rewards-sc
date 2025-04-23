// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, GaugeRootstockCollective } from "./BaseTest.sol";
import { BuilderRegistryRootstockCollective } from "../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract BuilderRegistryRootstockCollectiveTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderInitialised(address indexed builder_, address rewardReceiver_, uint64 rewardPercentage_);
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

        // WHEN alice calls initialiseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.initialiseBuilder(builder, builder, 0);

        // WHEN alice calls revokeBuilderKYC
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.revokeBuilderKYC(builder);

        // WHEN alice calls pauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.pauseBuilder(builder, "paused");

        // WHEN alice calls unpauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotKycApprover.selector);
        builderRegistry.unpauseBuilder(builder);
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
        vm.expectRevert(BuilderRegistryRootstockCollective.NotAuthorized.selector);
        builderRegistry.communityApproveBuilder(builder);

        // WHEN alice calls dewhitelistBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        builderRegistry.dewhitelistBuilder(builder);
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
        builderRegistry.revokeBuilder();

        // WHEN alice calls permitBuilder
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        builderRegistry.permitBuilder(1 ether);
        vm.stopPrank();

        // WHEN kycApprover calls approveBuilderKYC for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        vm.prank(kycApprover);
        builderRegistry.approveBuilderKYC(alice);

        // WHEN governor calls dewhitelistBuilder for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderDoesNotExist.selector);
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(alice);
    }

    /**
     * SCENARIO: kycApprover initialises a new builder
     */
    function test_InitialiseBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        address _newRewardReceiver = makeAddr("newRewardReceiver");
        uint64 _backerRewardPercentage = 0.1 ether;
        // AND a kycApprover
        vm.prank(kycApprover);
        // WHEN calls initialiseBuilder
        //  THEN BuilderInitialised event is emitted
        vm.expectEmit();
        emit BuilderInitialised(_newBuilder, _newRewardReceiver, _backerRewardPercentage);
        builderRegistry.initialiseBuilder(_newBuilder, _newRewardReceiver, _backerRewardPercentage);

        // THEN builder is kycApproved
        (, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        assertEq(_kycApproved, true);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);

        // THEN builder rewards receiver is set
        assertEq(builderRegistry.builderRewardReceiver(_newBuilder), _newRewardReceiver);

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
    function test_RevertAlreadyKYCApproved() public {
        // GIVEN a builder KYC approved
        //  AND a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to approveBuilderKYC
        //  THEN tx reverts because is already kycApproved
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyKYCApproved.selector);
        builderRegistry.approveBuilderKYC(builder);
    }

    /**
     * SCENARIO: initialiseBuilder should revert if it is already initialised
     */
    function test_RevertBuilderAlreadyInitialised() public {
        // GIVEN a builder KYC approved
        //  AND a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to initialiseBuilder
        //  THEN tx reverts because is already initialised
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyInitialised.selector);
        builderRegistry.initialiseBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: approveBuilderKYC should revert if it is not initialised
     */
    function test_RevertNotKYCInitialised() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        builderRegistry.communityApproveBuilder(_newBuilder);

        // WHEN tries to approveBuilderKYC
        //  THEN tx reverts because is not initialised
        vm.prank(kycApprover);
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderNotInitialised.selector);
        builderRegistry.approveBuilderKYC(_newBuilder);
    }

    /**
     * SCENARIO: initialiseBuilder should revert if reward percentage is higher than 100
     */
    function test_InitialiseBuilderInvalidBackerRewardPercentage() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a kycApprover
        vm.prank(kycApprover);

        // WHEN tries to initialiseBuilder
        //  THEN tx reverts because is not a valid reward percentage
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBackerRewardPercentage.selector);
        builderRegistry.initialiseBuilder(_newBuilder, _newBuilder, 2 ether);
    }

    /**
     * SCENARIO: Governor community approves a new builder
     */
    function test_CommunityApproveBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a KYCApprover initialises a builder
        vm.prank(kycApprover);
        builderRegistry.initialiseBuilder(_newBuilder, _newBuilder, 0);

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
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyCommunityApproved.selector);
        vm.prank(governor);
        builderRegistry.communityApproveBuilder(builder);
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
        builderRegistry.pauseBuilder(builder, "paused");

        // THEN builder is paused
        (,,, bool _paused,,, bytes20 _reason) = builderRegistry.builderState(builder);
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
        builderRegistry.pauseBuilder(builder, "This is a short test");
        // THEN builder is paused
        (,,, bool _paused,,, bytes20 _reason) = builderRegistry.builderState(builder);
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
        builderRegistry.pauseBuilder(builder, "paused");
        (,,, bool _paused,,, bytes20 _reason) = builderRegistry.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");

        // WHEN is paused again with a different reason
        vm.prank(kycApprover);
        builderRegistry.pauseBuilder(builder, "pausedAgain");
        // THEN builder is still paused
        (,,, _paused,,, _reason) = builderRegistry.builderState(builder);
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
        builderRegistry.pauseBuilder(builder, "paused");
        // WHEN kycApprover calls unpauseBuilder
        //  THEN Unpaused event is emitted
        vm.expectEmit();
        emit Unpaused(builder);
        builderRegistry.unpauseBuilder(builder);

        // THEN builder is not paused
        (,,, bool _paused,,, bytes20 _reason) = builderRegistry.builderState(builder);
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
        builderRegistry.revokeBuilder();

        // WHEN calls permitBuilder
        //  THEN Permitted event is emitted
        vm.expectEmit();
        emit Permitted(builder, 1 ether, block.timestamp + 2 weeks);
        builderRegistry.permitBuilder(1 ether);

        // THEN builder is not revoked
        (,,,, bool _revoked,,) = builderRegistry.builderState(builder);
        assertEq(_revoked, false);
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
     * SCENARIO: permitBuilder should revert if it is not revoked
     */
    function test_PermitBuilderRevert() public {
        // GIVEN a builder not paused
        vm.startPrank(builder);
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.expectRevert(BuilderRegistryRootstockCollective.NotRevoked.selector);
        builderRegistry.permitBuilder(1 ether);
        // AND the builder is paused but not revoked
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilder(builder, "paused");
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotRevoked.selector);
        builderRegistry.permitBuilder(1 ether);
    }

    /**
     * SCENARIO: permitBuilder should revert if reward percentage is higher than 100
     */
    function test_PermitBuilderInvalidBackerRewardPercentage() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        builderRegistry.revokeBuilder();
        //  WHEN tries to permitBuilder with 200% of reward percentage
        //   THEN tx reverts because is not a valid reward percentage
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBackerRewardPercentage.selector);
        builderRegistry.permitBuilder(2 ether);
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
        builderRegistry.revokeBuilder();

        // THEN builder is revoked
        (,,,, bool _revoked,,) = builderRegistry.builderState(builder);
        assertEq(_revoked, true);
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
     * SCENARIO: revokeBuilder should revert if it is already revoked
     */
    function test_RevertAlreadyRevoked() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        builderRegistry.revokeBuilder();
        // WHEN tries to revokeBuilder again
        //  THEN tx reverts because is already revoked
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyRevoked.selector);
        builderRegistry.revokeBuilder();
    }

    /**
     * SCENARIO: builder is whitelisted and KYC gets revoked. Cannot be initialised anymore
     */
    function test_RevertActivatingWhitelistedRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // WHEN kycApprover tries to initialise it again
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyInitialised.selector);
        builderRegistry.initialiseBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: communityApproveBuilder before initialise it
     */
    function test_CommunityApproveBuilderBeforeInitialise() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = builderRegistry.communityApproveBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(builderRegistry.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(builderRegistry.gaugeToBuilder(_newGauge), _newBuilder);
        (bool _initialised, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is community approved
        assertEq(_communityApproved, true);
        // THEN builder is not initialised
        assertEq(_initialised, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is initialised
        vm.prank(kycApprover);
        builderRegistry.initialiseBuilder(_newBuilder, _newBuilder, 0.1 ether);
        (_initialised, _kycApproved, _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is _community approved
        assertEq(_communityApproved, true);
        // THEN builder is initialised
        assertEq(_initialised, true);
        // THEN builder is KYC approved
        assertEq(_kycApproved, true);
    }

    /**
     * SCENARIO: community approved builder can be de-whitelisted without being initialised before
     */
    function test_CommunityRevokedBuilderNotInitialised() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is community approved
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = builderRegistry.communityApproveBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(builderRegistry.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(builderRegistry.gaugeToBuilder(_newGauge), _newBuilder);
        (bool _initialised, bool _kycApproved, bool _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is community approved
        assertEq(_communityApproved, true);
        // THEN builder is not initialised
        assertEq(_initialised, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is de-whitelisted
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(_newBuilder);
        (,, _communityApproved,,,,) = builderRegistry.builderState(_newBuilder);
        // THEN builder is not community approved
        assertEq(_communityApproved, false);
    }

    /**
     * SCENARIO: revokeBuilder reverts if KYC was revoked
     */
    function test_RevertRevokeBuilderNotKYCApproved() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        //  WHEN builders tries to revoke it
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotKYCApproved.selector);
        builderRegistry.revokeBuilder();
    }

    /**
     * SCENARIO: permitBuilder reverts if KYC was revoked
     */
    function test_RevertPermitBuilderNotKYCApproved() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        builderRegistry.revokeBuilder();
        // AND kycApprover revokes it KYC
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        //  WHEN builders tries to permit it
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotKYCApproved.selector);
        builderRegistry.permitBuilder(0.1 ether);
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
        vm.expectRevert(BuilderRegistryRootstockCollective.NotKYCApproved.selector);
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
     * SCENARIO: KYC revoked builder can be paused and unpaused
     */
    function test_PauseKYCRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);
        // AND kycApprover calls pauseBuilder
        builderRegistry.pauseBuilder(builder, "paused");
        (, bool _kycApproved,, bool _paused,,,) = builderRegistry.builderState(builder);
        // THEN builder is not kycApproved
        assertEq(_kycApproved, false);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        builderRegistry.unpauseBuilder(builder);
        (, _kycApproved,, _paused,,,) = builderRegistry.builderState(builder);
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
        builderRegistry.revokeBuilder();
        // AND kycApprover calls pauseBuilder
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilder(builder, "paused");
        (,,, bool _paused, bool _revoked,,) = builderRegistry.builderState(builder);
        // THEN builder is revoked
        assertEq(_revoked, true);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        builderRegistry.unpauseBuilder(builder);
        (,,, _paused, _revoked,,) = builderRegistry.builderState(builder);
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
        builderRegistry.pauseBuilder(builder, "paused");
        // AND builder calls revokeBuilder
        vm.startPrank(builder);
        builderRegistry.revokeBuilder();
        (,,, bool _paused, bool _revoked,,) = builderRegistry.builderState(builder);
        // THEN builder is paused
        assertEq(_paused, true);
        // THEN builder is revoked
        assertEq(_revoked, true);

        // AND builder calls permitBuilder
        builderRegistry.permitBuilder(0.1 ether);
        (,,, _paused, _revoked,,) = builderRegistry.builderState(builder);
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
        builderRegistry.pauseBuilder(builder, "paused");

        // AND kycApprover calls revokeBuilderKYC
        builderRegistry.revokeBuilderKYC(builder);
        (, bool _kycApproved,, bool _paused,,,) = builderRegistry.builderState(builder);
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
        builderRegistry.dewhitelistBuilder(builder);

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
     * SCENARIO: dewhitelist reverts if builder was already de-whitelisted
     */
    function test_RevertsDewhitelistBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);

        //  WHEN governor calls dewhitelistBuilder
        //   THEN tx reverts because is not community approved
        vm.expectRevert(BuilderRegistryRootstockCollective.NotCommunityApproved.selector);
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);
    }

    /**
     * SCENARIO: whitelisted builder is de-whitelisted. Cannot be community approved again
     */
    function test_RevertWhitelistingBuilderTwice() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);

        //  WHEN governor calls communityApproveBuilder
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderAlreadyExists.selector);
        vm.prank(governor);
        builderRegistry.communityApproveBuilder(builder);
    }

    /**
     * SCENARIO: revokeBuilder reverts if it is not community approved
     */
    function test_RevertRevokeBuilderNotWhitelisted() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);

        //  WHEN builders tries to revoke itself
        //   THEN tx reverts because is not community approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotCommunityApproved.selector);
        builderRegistry.revokeBuilder();
    }

    /**
     * SCENARIO: permitBuilder reverts if it is not whitelisted
     */
    function test_RevertPermitBuilderNotWhitelisted() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);

        //  WHEN builders tries to permit it
        //   THEN tx reverts because is not whitelisted
        vm.prank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotCommunityApproved.selector);
        builderRegistry.permitBuilder(0.1 ether);
    }

    /**
     * SCENARIO: de-whitelisted builder can be paused and unpaused
     */
    function test_PauseDewhitelistedBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);

        // AND kycApprover calls pauseBuilder
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilder(builder, "paused");
        (,, bool _communityApproved, bool _paused,,,) = builderRegistry.builderState(builder);
        // THEN builder is not whitelisted
        assertEq(_communityApproved, false);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        builderRegistry.unpauseBuilder(builder);
        (,, _communityApproved, _paused,,,) = builderRegistry.builderState(builder);
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
        builderRegistry.pauseBuilder(builder, "paused");

        // AND governor calls dewhitelistBuilder
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);
        (,, bool _communityApproved, bool _paused,,,) = builderRegistry.builderState(builder);
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
        builderRegistry.dewhitelistBuilder(builder);

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
     * SCENARIO: de-whitelisted and KYC revoked builder is KYC approved again
     * Its gauge remains halted
     */
    function test_KYCApproveDewhitelistedBuilder() public {
        // GIVEN a de-whitelisted and KYC revoked builder
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);
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
}
