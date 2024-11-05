// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "./BaseTest.sol";
import { BuilderRegistry } from "../src/BuilderRegistry.sol";
import { IGovernanceManager } from "src/interfaces/IGovernanceManager.sol";

contract BuilderRegistryTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderActivated(address indexed builder_, address rewardReceiver_, uint64 kickback_);
    event KYCApproved(address indexed builder_);
    event KYCRevoked(address indexed builder_);
    event Whitelisted(address indexed builder_);
    event Dewhitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Unpaused(address indexed builder_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_, uint256 kickback_, uint256 cooldown_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    function test_OnlyKycApprover() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);

        // WHEN alice calls activateBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManager.NotKycApprover.selector);
        sponsorsManager.activateBuilder(builder, builder, 0);

        // WHEN alice calls revokeBuilderKYC
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManager.NotKycApprover.selector);
        sponsorsManager.revokeBuilderKYC(builder);

        // WHEN alice calls pauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManager.NotKycApprover.selector);
        sponsorsManager.pauseBuilder(builder, "paused");

        // WHEN alice calls unpauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(IGovernanceManager.NotKycApprover.selector);
        sponsorsManager.unpauseBuilder(builder);
        vm.stopPrank();
    }
    /**
     * SCENARIO: functions protected by OnlyGovernor should revert when are not
     *  called by Governor
     */

    function test_OnlyGovernor() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);

        // WHEN alice calls whitelistBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(IGovernanceManager.NotAuthorizedChanger.selector);
        sponsorsManager.whitelistBuilder(builder);

        // WHEN alice calls dewhitelistBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(IGovernanceManager.NotAuthorizedChanger.selector);
        sponsorsManager.dewhitelistBuilder(builder);
        vm.stopPrank();
    }

    /**
     * SCENARIO: should revert if it is not called by a builder
     */
    function test_RevertBuilderDoesNotExist() public {
        // GIVEN  a whitelisted builder
        //  AND a sponsor alice
        vm.startPrank(alice);

        // WHEN alice calls revokeBuilder
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistry.BuilderDoesNotExist.selector);
        sponsorsManager.revokeBuilder();

        // WHEN alice calls permitBuilder
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistry.BuilderDoesNotExist.selector);
        sponsorsManager.permitBuilder(1 ether);
        vm.stopPrank();

        // WHEN kycApprover calls approveBuilderKYC for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistry.BuilderDoesNotExist.selector);
        vm.prank(kycApprover);
        sponsorsManager.approveBuilderKYC(alice);

        // WHEN governor calls dewhitelistBuilder for alice
        //  THEN tx reverts because caller is not a builder
        vm.expectRevert(BuilderRegistry.BuilderDoesNotExist.selector);
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(alice);
    }

    /**
     * SCENARIO: kycApprover activates a new builder
     */
    function test_ActivateBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        address _newRewardReceiver = makeAddr("newRewardReceiver");
        // AND a kycApprover
        vm.prank(kycApprover);
        // WHEN calls activateBuilder
        //  THEN BuilderActivated event is emitted
        vm.expectEmit();
        emit BuilderActivated(_newBuilder, _newRewardReceiver, 0.1 ether);
        sponsorsManager.activateBuilder(_newBuilder, _newRewardReceiver, 0.1 ether);

        // THEN builder is kycApproved
        (, bool _kycApproved,,,,,) = sponsorsManager.builderState(_newBuilder);
        assertEq(_kycApproved, true);

        // THEN builder rewards receiver is set
        assertEq(sponsorsManager.builderRewardReceiver(_newBuilder), _newRewardReceiver);
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
        vm.expectRevert(BuilderRegistry.AlreadyKYCApproved.selector);
        sponsorsManager.approveBuilderKYC(builder);
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
        vm.expectRevert(BuilderRegistry.AlreadyActivated.selector);
        sponsorsManager.activateBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: approveBuilderKYC should revert if it is not activated
     */
    function test_RevertNotKYCActivated() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is whitelisted
        vm.prank(governor);
        sponsorsManager.whitelistBuilder(_newBuilder);

        // WHEN tries to approveBuilderKYC
        //  THEN tx reverts because is not activated
        vm.prank(kycApprover);
        vm.expectRevert(BuilderRegistry.NotActivated.selector);
        sponsorsManager.approveBuilderKYC(_newBuilder);
    }

    /**
     * SCENARIO: activateBuilder should revert if kickback is higher than 100
     */
    function test_ActivateBuilderInvalidBuilderKickback() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a kycApprover
        vm.prank(kycApprover);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is not a valid kickback
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickback.selector);
        sponsorsManager.activateBuilder(_newBuilder, _newBuilder, 2 ether);
    }

    /**
     * SCENARIO: Governor whitelist a new builder
     */
    function test_WhitelistBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a KYCApprover activates a builder
        vm.prank(kycApprover);
        sponsorsManager.activateBuilder(_newBuilder, _newBuilder, 0);

        // WHEN calls whitelistBuilder
        //  THEN a GaugeCreated event is emitted
        vm.expectEmit(true, false, true, true); // ignore new gauge address
        emit GaugeCreated(_newBuilder, /*ignored*/ address(0), governor);

        //  THEN Whitelisted event is emitted
        vm.expectEmit();
        emit Whitelisted(_newBuilder);

        vm.prank(governor);
        Gauge _newGauge = sponsorsManager.whitelistBuilder(_newBuilder);

        // THEN new gauge is assigned to the new builder
        assertEq(address(sponsorsManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(sponsorsManager.gaugeToBuilder(_newGauge), _newBuilder);
        // THEN builder is whitelisted
        (,, bool _whitelisted,,,,) = sponsorsManager.builderState(_newBuilder);
        assertEq(_whitelisted, true);
    }

    /**
     * SCENARIO: whitelistBuilder should revert if it is already whitelisted
     */
    function test_RevertAlreadyWhitelisted() public {
        // GIVEN a builder whitelisted
        //  WHEN tries to whitelistBuilder
        //   THEN tx reverts because is already whitelisted
        vm.expectRevert(BuilderRegistry.AlreadyWhitelisted.selector);
        vm.prank(governor);
        sponsorsManager.whitelistBuilder(builder);
    }

    /**
     * SCENARIO: kycApprover pause a builder
     */
    function test_PauseBuilder() public {
        // GIVEN a Whitelisted builder
        //  WHEN kycApprover calls pauseBuilder
        vm.prank(kycApprover);
        //   THEN Paused event is emitted
        vm.expectEmit();
        emit Paused(builder, "paused");
        sponsorsManager.pauseBuilder(builder, "paused");

        // THEN builder is paused
        (,,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");
    }

    /**
     * SCENARIO: pause reason is 20 bytes long
     */
    function test_PauseReason20bytes() public {
        // GIVEN a Whitelisted builder
        //  WHEN calls pauseBuilder
        vm.prank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "This is a short test");
        // THEN builder is paused
        (,,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
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
        sponsorsManager.pauseBuilder(builder, "paused");
        (,,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");

        // WHEN is paused again with a different reason
        vm.prank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "pausedAgain");
        // THEN builder is still paused
        (,,, _paused,,, _reason) = sponsorsManager.builderState(builder);
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
        sponsorsManager.pauseBuilder(builder, "paused");
        // WHEN kycApprover calls unpauseBuilder
        //  THEN Unpaused event is emitted
        vm.expectEmit();
        emit Unpaused(builder);
        sponsorsManager.unpauseBuilder(builder);

        // THEN builder is not paused
        (,,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
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
        sponsorsManager.revokeBuilder();

        // WHEN calls permitBuilder
        //  THEN Permitted event is emitted
        vm.expectEmit();
        emit Permitted(builder, 1 ether, block.timestamp + 2 weeks);
        sponsorsManager.permitBuilder(1 ether);

        // THEN builder is not revoked
        (,,,, bool _revoked,,) = sponsorsManager.builderState(builder);
        assertEq(_revoked, false);
        // THEN gauge is not halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), false);
        // THEN halted gauges array length is 0
        assertEq(sponsorsManager.getHaltedGaugesLength(), 0);
        // THEN gauge is rewarded
        assertEq(sponsorsManager.isGaugeRewarded(address(gauge)), true);
        // THEN rewarded gauges array length is 2
        assertEq(sponsorsManager.getGaugesLength(), 2);
        // THEN haltedGaugeLastPeriodFinish is 0
        assertEq(sponsorsManager.haltedGaugeLastPeriodFinish(gauge), 0);
    }

    /**
     * SCENARIO: permitBuilder should revert if it is not revoked
     */
    function test_PermitBuilderRevert() public {
        // GIVEN a builder not paused
        vm.startPrank(builder);
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.expectRevert(BuilderRegistry.NotRevoked.selector);
        sponsorsManager.permitBuilder(1 ether);
        // AND the builder is paused but not revoked
        vm.startPrank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistry.NotRevoked.selector);
        sponsorsManager.permitBuilder(1 ether);
    }

    /**
     * SCENARIO: permitBuilder should revert if kickback is higher than 100
     */
    function test_PermitBuilderInvalidBuilderKickback() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        //  WHEN tries to permitBuilder with 200% of kickback
        //   THEN tx reverts because is not a valid kickback
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickback.selector);
        sponsorsManager.permitBuilder(2 ether);
    }

    /**
     * SCENARIO: Builder revoke itself
     */
    function test_RevokeBuilder() public {
        // GIVEN a Whitelisted builder
        vm.startPrank(builder);

        // WHEN calls revokeBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit Revoked(builder);
        sponsorsManager.revokeBuilder();

        // THEN builder is revoked
        (,,,, bool _revoked,,) = sponsorsManager.builderState(builder);
        assertEq(_revoked, true);
        // THEN gauge is halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(sponsorsManager.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(sponsorsManager.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(sponsorsManager.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(sponsorsManager.haltedGaugeLastPeriodFinish(gauge), sponsorsManager.periodFinish());
    }

    /**
     * SCENARIO: revokeBuilder should revert if it is already revoked
     */
    function test_RevertAlreadyRevoked() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        // WHEN tries to revokeBuilder again
        //  THEN tx reverts because is already revoked
        vm.expectRevert(BuilderRegistry.AlreadyRevoked.selector);
        sponsorsManager.revokeBuilder();
    }

    /**
     * SCENARIO: builder is whitelisted and KYC revoked. Cannot be activated anymore
     */
    function test_RevertActivatingWhitelistedRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);

        // WHEN kycApprover tries to activating it again
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistry.AlreadyActivated.selector);
        sponsorsManager.activateBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: whitelistBuilder before activate it
     */
    function test_WhitelistBuilderBeforeActivate() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is whitelisted
        vm.prank(governor);
        Gauge _newGauge = sponsorsManager.whitelistBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(sponsorsManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(sponsorsManager.gaugeToBuilder(_newGauge), _newBuilder);
        (bool _activated, bool _kycApproved, bool _whitelisted,,,,) = sponsorsManager.builderState(_newBuilder);
        // THEN builder is whitelisted
        assertEq(_whitelisted, true);
        // THEN builder is not activated
        assertEq(_activated, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is activated
        vm.prank(kycApprover);
        sponsorsManager.activateBuilder(_newBuilder, _newBuilder, 0.1 ether);
        (_activated, _kycApproved, _whitelisted,,,,) = sponsorsManager.builderState(_newBuilder);
        // THEN builder is whitelisted
        assertEq(_whitelisted, true);
        // THEN builder is activated
        assertEq(_activated, true);
        // THEN builder is KYC approved
        assertEq(_kycApproved, true);
    }

    /**
     * SCENARIO: whitelistBuilder can be de-whitelisted without being activated before
     */
    function test_DeWhitelistBuilderWithoutActivate() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        //  AND is whitelisted
        vm.prank(governor);
        Gauge _newGauge = sponsorsManager.whitelistBuilder(_newBuilder);
        // THEN new gauge is assigned to the new builder
        assertEq(address(sponsorsManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(sponsorsManager.gaugeToBuilder(_newGauge), _newBuilder);
        (bool _activated, bool _kycApproved, bool _whitelisted,,,,) = sponsorsManager.builderState(_newBuilder);
        // THEN builder is whitelisted
        assertEq(_whitelisted, true);
        // THEN builder is not activated
        assertEq(_activated, false);
        // THEN builder is not KYC approved
        assertEq(_kycApproved, false);

        // WHEN new builder is de-whitelisted
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(_newBuilder);
        (,, _whitelisted,,,,) = sponsorsManager.builderState(_newBuilder);
        // THEN builder is not whitelisted
        assertEq(_whitelisted, false);
    }

    /**
     * SCENARIO: revokeBuilder reverts if KYC was revoked
     */
    function test_RevertRevokeBuilderNotKYCApproved() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);

        //  WHEN builders tries to revoke it
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistry.NotKYCApproved.selector);
        sponsorsManager.revokeBuilder();
    }

    /**
     * SCENARIO: permitBuilder reverts if KYC was revoked
     */
    function test_RevertPermitBuilderNotKYCApproved() public {
        // GIVEN a revoked builder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        // AND kycApprover revokes it KYC
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);

        //  WHEN builders tries to permit it
        //   THEN tx reverts because is not KYC approved
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistry.NotKYCApproved.selector);
        sponsorsManager.permitBuilder(0.1 ether);
    }

    /**
     * SCENARIO: revokeBuilderKYC reverts if KYC was already revoked
     */
    function test_RevertRevokeBuilderKYCNotKYCApproved() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);

        //  WHEN kycApprover tries to revoke it again
        //   THEN tx reverts because is not KYC approved
        vm.expectRevert(BuilderRegistry.NotKYCApproved.selector);
        sponsorsManager.revokeBuilderKYC(builder);
    }

    /**
     * SCENARIO: kycApprover revokes builder KYC
     */
    function test_RevokeBuilderKYC() public {
        // GIVEN a Whitelisted builder
        vm.startPrank(kycApprover);

        // WHEN kycApprover calls revokeBuilderKYC
        //  THEN KYCRevoked event is emitted
        vm.expectEmit();
        emit KYCRevoked(builder);
        sponsorsManager.revokeBuilderKYC(builder);

        // THEN builder is not kycApproved
        (, bool _kycApproved,,,,,) = sponsorsManager.builderState(builder);
        assertEq(_kycApproved, false);
        // THEN gauge is halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(sponsorsManager.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(sponsorsManager.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(sponsorsManager.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(sponsorsManager.haltedGaugeLastPeriodFinish(gauge), sponsorsManager.periodFinish());
    }

    /**
     * SCENARIO: kycApprover approved builder KYC
     */
    function test_ApproveBuilderKYC() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);

        // WHEN calls approveBuilderKYC
        //  THEN KYCApproved event is emitted
        vm.expectEmit();
        emit KYCApproved(builder);
        sponsorsManager.approveBuilderKYC(builder);

        // THEN builder is kycApproved
        (, bool _kycApproved,,,,,) = sponsorsManager.builderState(builder);
        assertEq(_kycApproved, true);
        // THEN gauge is not halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), false);
        // THEN halted gauges array length is 0
        assertEq(sponsorsManager.getHaltedGaugesLength(), 0);
        // THEN gauge is rewarded
        assertEq(sponsorsManager.isGaugeRewarded(address(gauge)), true);
        // THEN rewarded gauges array length is 2
        assertEq(sponsorsManager.getGaugesLength(), 2);
        // THEN haltedGaugeLastPeriodFinish is 0
        assertEq(sponsorsManager.haltedGaugeLastPeriodFinish(gauge), 0);
    }

    /**
     * SCENARIO: KYC revoked builder can be paused and unpaused
     */
    function test_PauseKYCRevokedBuilder() public {
        // GIVEN a KYC revoked builder
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);
        // AND kycApprover calls pauseBuilder
        sponsorsManager.pauseBuilder(builder, "paused");
        (, bool _kycApproved,, bool _paused,,,) = sponsorsManager.builderState(builder);
        // THEN builder is not kycApproved
        assertEq(_kycApproved, false);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        sponsorsManager.unpauseBuilder(builder);
        (, _kycApproved,, _paused,,,) = sponsorsManager.builderState(builder);
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
        sponsorsManager.revokeBuilder();
        // AND kycApprover calls pauseBuilder
        vm.startPrank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");
        (,,, bool _paused, bool _revoked,,) = sponsorsManager.builderState(builder);
        // THEN builder is revoked
        assertEq(_revoked, true);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        sponsorsManager.unpauseBuilder(builder);
        (,,, _paused, _revoked,,) = sponsorsManager.builderState(builder);
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
        sponsorsManager.pauseBuilder(builder, "paused");
        // AND builder calls revokeBuilder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        (,,, bool _paused, bool _revoked,,) = sponsorsManager.builderState(builder);
        // THEN builder is paused
        assertEq(_paused, true);
        // THEN builder is revoked
        assertEq(_revoked, true);

        // AND builder calls permitBuilder
        sponsorsManager.permitBuilder(0.1 ether);
        (,,, _paused, _revoked,,) = sponsorsManager.builderState(builder);
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
        sponsorsManager.pauseBuilder(builder, "paused");

        // AND kycApprover calls revokeBuilderKYC
        sponsorsManager.revokeBuilderKYC(builder);
        (, bool _kycApproved,, bool _paused,,,) = sponsorsManager.builderState(builder);
        // THEN builder is paused
        assertEq(_paused, true);
        // THEN builder is not kyc approved
        assertEq(_kycApproved, false);
    }

    /**
     * SCENARIO: governor dewhitelist a builder
     */
    function test_DewhitelistBuilder() public {
        // GIVEN a Whitelisted builder
        //  WHEN governor calls dewhitelistBuilder
        //   THEN Dewhitelisted event is emitted
        vm.expectEmit();
        emit Dewhitelisted(builder);
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);

        // THEN builder is not whitelisted
        (,, bool _whitelisted,,,,) = sponsorsManager.builderState(builder);
        assertEq(_whitelisted, false);
        // THEN gauge is halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(sponsorsManager.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(sponsorsManager.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(sponsorsManager.getGaugesLength(), 1);
        // THEN haltedGaugeLastPeriodFinish is periodFinish
        assertEq(sponsorsManager.haltedGaugeLastPeriodFinish(gauge), sponsorsManager.periodFinish());
    }

    /**
     * SCENARIO: dewhitelist reverts if builder was already de-whitelisted
     */
    function test_RevertsDewhitelistBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);

        //  WHEN governor calls dewhitelistBuilder
        //   THEN tx reverts because is not whitelisted
        vm.expectRevert(BuilderRegistry.NotWhitelisted.selector);
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);
    }

    /**
     * SCENARIO: whitelisted builder is de-whitelisted. Cannot be whitelisted again
     */
    function test_RevertWhitelistingBuilderTwice() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);

        //  WHEN governor calls whitelistBuilder
        //  THEN tx reverts because builder already exists
        vm.expectRevert(BuilderRegistry.BuilderAlreadyExists.selector);
        vm.prank(governor);
        sponsorsManager.whitelistBuilder(builder);
    }

    /**
     * SCENARIO: revokeBuilderKYC reverts if it is not whitelisted
     */
    function test_RevertRevokeBuilderKYCNotWhitelisted() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);

        //  WHEN builders tries to revoke itself
        //   THEN tx reverts because is not whitelisted
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistry.NotWhitelisted.selector);
        sponsorsManager.revokeBuilder();
    }

    /**
     * SCENARIO: permitBuilder reverts if it is not whitelisted
     */
    function test_RevertPermitBuilderNotWhitelisted() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);

        //  WHEN builders tries to permit it
        //   THEN tx reverts because is not whitelisted
        vm.prank(builder);
        vm.expectRevert(BuilderRegistry.NotWhitelisted.selector);
        sponsorsManager.permitBuilder(0.1 ether);
    }

    /**
     * SCENARIO: de-whitelisted builder can be paused and unpaused
     */
    function test_PauseDewhitelistedBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);

        // AND kycApprover calls pauseBuilder
        vm.startPrank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");
        (,, bool _whitelisted, bool _paused,,,) = sponsorsManager.builderState(builder);
        // THEN builder is not whitelisted
        assertEq(_whitelisted, false);
        // THEN builder is paused
        assertEq(_paused, true);

        // AND kycApprover calls unpauseBuilder
        sponsorsManager.unpauseBuilder(builder);
        (,, _whitelisted, _paused,,,) = sponsorsManager.builderState(builder);
        // THEN builder is still not whitelisted
        assertEq(_whitelisted, false);
        // THEN builder is not paused
        assertEq(_paused, false);
    }

    /**
     * SCENARIO: paused builder can be de-whitelisted
     */
    function test_DewhitelistPausedBuilder() public {
        // GIVEN paused builder
        vm.prank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");

        // AND governor calls dewhitelistBuilder
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);
        (,, bool _whitelisted, bool _paused,,,) = sponsorsManager.builderState(builder);
        // THEN builder is paused
        assertEq(_paused, true);
        // THEN builder is not whitelisted
        assertEq(_whitelisted, false);
    }

    /**
     * SCENARIO: de-whitelisted builder can be KYC revoked
     */
    function test_KYCRevokeDewhitelistedBuilder() public {
        // GIVEN a de-whitelisted builder
        vm.prank(governor);
        sponsorsManager.dewhitelistBuilder(builder);

        // AND kycApprover calls revokeBuilderKYC
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);
        (, bool _kycApproved, bool _whitelisted,,,,) = sponsorsManager.builderState(builder);
        // THEN builder is not whitelisted
        assertEq(_whitelisted, false);
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
        sponsorsManager.dewhitelistBuilder(builder);
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder);

        // AND kycApprover calls approveBuilderKYC
        vm.startPrank(kycApprover);
        sponsorsManager.approveBuilderKYC(builder);

        (, bool _kycApproved, bool _whitelisted,,,,) = sponsorsManager.builderState(builder);
        // THEN builder is not whitelisted
        assertEq(_whitelisted, false);
        // THEN builder is kyc approved
        assertEq(_kycApproved, true);
        // THEN gauge remains halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), true);
    }
}
