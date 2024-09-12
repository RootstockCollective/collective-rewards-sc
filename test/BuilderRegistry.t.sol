// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "./BaseTest.sol";
import { BuilderRegistry } from "../src/BuilderRegistry.sol";
import { Governed } from "../src/governance/Governed.sol";

contract BuilderRegistryTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event KYCApproved(address indexed builder_);
    event Whitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes29 reason_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    /**
     * SCENARIO: functions protected by OnlyGovernor should revert when are not
     *  called by Governor
     */
    function test_OnlyGovernor() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);

        // GIVEN mock authorized is false
        changeExecutorMock.setIsAuthorized(false);

        // WHEN alice calls whitelistBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        sponsorsManager.whitelistBuilder(builder);

        // WHEN alice calls pauseBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        sponsorsManager.pauseBuilder(builder, "paused");
    }

    /**
     * SCENARIO: should revert if is not called by the builder
     */
    function test_NotAuthorized() public {
        // GIVEN  a whitelisted builder
        //  AND a sponsor alice
        vm.startPrank(alice);

        // WHEN alice calls revokeBuilder
        //  THEN tx reverts because caller is not the builder
        vm.expectRevert(BuilderRegistry.NotAuthorized.selector);
        sponsorsManager.revokeBuilder(builder);

        // WHEN alice calls permitBuilder
        //  THEN tx reverts because caller is not the builder
        vm.expectRevert(BuilderRegistry.NotAuthorized.selector);
        sponsorsManager.permitBuilder(builder);
    }

    /**
     * SCENARIO: kycApprover activates a new builder
     */
    function test_ActivateBuilder() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // AND a kycApprover
        vm.prank(kycApprover);
        // WHEN calls activateBuilder
        //  THEN KYCApproved event is emitted
        vm.expectEmit();
        emit KYCApproved(_newBuilder);
        sponsorsManager.activateBuilder(_newBuilder, _newBuilder, 0);

        // THEN builder is kycApproved
        (bool _kycApproved,,,) = sponsorsManager.builderState(_newBuilder);
        assertEq(_kycApproved, true);

        // THEN builder rewards receiver is the same as the builder
        assertEq(sponsorsManager.builderRewardReceiver(_newBuilder), _newBuilder);
    }

    /**
     * SCENARIO: activateBuilder should reverts if it is already approved
     */
    function test_RevertAlreadyKYCApproved() public {
        // GIVEN a builder KYC approved
        //  AND a kycApprover
        vm.prank(kycApprover);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is already kycApproved
        vm.expectRevert(BuilderRegistry.AlreadyKYCApproved.selector);
        sponsorsManager.activateBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: activateBuilder should reverts if kickback is higher than 100
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
        // AND a KYCApproved builder
        vm.prank(kycApprover);
        sponsorsManager.activateBuilder(_newBuilder, _newBuilder, 0);

        // WHEN calls whitelistBuilder
        //  THEN a GaugeCreated event is emitted
        vm.expectEmit(true, false, true, true); // ignore new gauge address
        emit GaugeCreated(_newBuilder, /*ignored*/ address(0), address(this));

        //  THEN Whitelisted event is emitted
        vm.expectEmit();
        emit Whitelisted(_newBuilder);

        Gauge _newGauge = sponsorsManager.whitelistBuilder(_newBuilder);

        // THEN new gauge is assigned to the new builder
        assertEq(address(sponsorsManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(sponsorsManager.gaugeToBuilder(_newGauge), _newBuilder);
        // THEN builder is whitelisted
        (, bool _whitelisted,,) = sponsorsManager.builderState(_newBuilder);
        assertEq(_whitelisted, true);
    }

    /**
     * SCENARIO: whitelistBuilder should reverts if it is already whitelisted
     */
    function test_RevertAlreadyWhitelisted() public {
        // GIVEN a builder whitelisted
        //  WHEN tries to whitelistBuilder
        //   THEN tx reverts because is already whitelisted
        vm.expectRevert(BuilderRegistry.AlreadyWhitelisted.selector);
        sponsorsManager.whitelistBuilder(builder);
    }

    /**
     * SCENARIO: Governor pause a builder
     */
    function test_PauseBuilder() public {
        // GIVEN a Whitelisted builder
        //  WHEN calls pauseBuilder
        //   THEN Paused event is emitted
        vm.expectEmit();
        emit Paused(builder, "paused");
        sponsorsManager.pauseBuilder(builder, "paused");

        // THEN builder is paused
        (,, bool _paused, bytes29 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");
    }

    /**
     * SCENARIO: pause reason is 29 bytes long
     */
    function test_PauseReason29bytes() public {
        // GIVEN a Whitelisted builder
        //  WHEN calls pauseBuilder
        sponsorsManager.pauseBuilder(builder, "This is a 29byte string exact");

        // THEN builder is paused
        (,, bool _paused, bytes29 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "This is a 29byte string exact"
        assertEq(_reason, "This is a 29byte string exact");
    }

    /**
     * SCENARIO: pauseBuilder again and overwritten the reason
     */
    function test_PauseWithAnotherReason() public {
        // GIVEN a paused builder
        sponsorsManager.pauseBuilder(builder, "paused");
        (,, bool _paused, bytes29 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");

        // WHEN is paused again with a different reason
        sponsorsManager.pauseBuilder(builder, "pausedAgain");
        // THEN builder is still paused
        (,, _paused, _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "pausedAgain"
        assertEq(_reason, "pausedAgain");
    }

    /**
     * SCENARIO: Governor permit a builder
     */
    function test_PermitBuilder() public {
        // GIVEN a Revoked builder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder(builder);

        // WHEN calls permitBuilder
        //  THEN Permitted event is emitted
        vm.expectEmit();
        emit Permitted(builder);
        sponsorsManager.permitBuilder(builder);

        // THEN builder is not paused
        (,, bool _paused, bytes29 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, false);
        // THEN builder paused reason is clean
        assertEq(_reason, "");
    }

    /**
     * SCENARIO: permitBuilder should reverts if is not paused or not revoked
     */
    function test_PermitBuilderRevert() public {
        // GIVEN a builder not paused
        vm.startPrank(builder);
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.expectRevert(BuilderRegistry.NotRevoked.selector);
        sponsorsManager.permitBuilder(builder);
        // AND the builder is paused but not revoked
        sponsorsManager.pauseBuilder(builder, "paused");
        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not revoked
        vm.expectRevert(BuilderRegistry.NotRevoked.selector);
        sponsorsManager.permitBuilder(builder);
    }

    /**
     * SCENARIO: pauseBuilder should revert if "Revoked" is used as reason
     */
    function test_RevertsRevokeReason() public {
        // GIVEN a Whitelisted builder
        //  WHEN calls pauseBuilder using "Revoked" as reason
        //   THEN tx reverts because cannot revoke on pause method
        vm.expectRevert(BuilderRegistry.CannotRevoke.selector);
        sponsorsManager.pauseBuilder(builder, "Revoked");
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
        sponsorsManager.revokeBuilder(builder);

        // THEN builder is paused
        (,, bool _paused, bytes29 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "Revoked"
        assertEq(_reason, "Revoked");
    }

    /**
     * SCENARIO: revokeBuilder should reverts if is already paused
     */
    function test_RevertAlreadyPaused() public {
        // GIVEN a paused builder
        sponsorsManager.pauseBuilder(builder, "paused");

        vm.startPrank(builder);
        // WHEN tries to revokeBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(BuilderRegistry.AlreadyPaused.selector);
        sponsorsManager.revokeBuilder(builder);
    }
}
