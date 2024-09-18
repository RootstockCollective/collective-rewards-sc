// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "./BaseTest.sol";
import { BuilderRegistry } from "../src/BuilderRegistry.sol";
import { Governed } from "../src/governance/Governed.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BuilderRegistryTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event KYCApproved(address indexed builder_);
    event Whitelisted(address indexed builder_);
    event Paused(address indexed builder_, bytes20 reason_);
    event Unpaused(address indexed builder_);
    event Revoked(address indexed builder_);
    event Permitted(address indexed builder_, uint256 kickback_, uint256 cooldown_);
    event GaugeCreated(address indexed builder_, address indexed gauge_, address creator_);

    function test_OnlyOnwer() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);

        // WHEN alice calls activateBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        sponsorsManager.activateBuilder(builder, builder, 0);

        // WHEN alice calls pauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        sponsorsManager.pauseBuilder(builder, "paused");

        // WHEN alice calls unpauseBuilder
        //  THEN tx reverts because caller is not the owner
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        sponsorsManager.unpauseBuilder(builder);
    }
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
    }

    /**
     * SCENARIO: should revert if is not called by a builder
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
        (bool _kycApproved,,,,,) = sponsorsManager.builderState(_newBuilder);
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
        (, bool _whitelisted,,,,) = sponsorsManager.builderState(_newBuilder);
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
        (,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
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
        (,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
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
        (,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, true);
        // THEN builder paused reason is "paused"
        assertEq(_reason, "paused");

        // WHEN is paused again with a different reason
        vm.prank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "pausedAgain");
        // THEN builder is still paused
        (,, _paused,,, _reason) = sponsorsManager.builderState(builder);
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
        (,, bool _paused,,, bytes20 _reason) = sponsorsManager.builderState(builder);
        assertEq(_paused, false);
        // THEN builder paused reason is clean
        assertEq(_reason, "");
    }

    /**
     * SCENARIO: Governor permit a builder
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
        (,,, bool _revoked,,) = sponsorsManager.builderState(builder);
        assertEq(_revoked, false);
        // THEN gauge is not halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), false);
        // THEN halted gauges array length is 0
        assertEq(sponsorsManager.getHaltedGaugesLength(), 0);
        // THEN gauge is rewarded
        assertEq(sponsorsManager.isGaugeRewarded(address(gauge)), true);
        // THEN rewarded gauges array length is 2
        assertEq(sponsorsManager.getGaugesLength(), 2);
    }

    /**
     * SCENARIO: permitBuilder should reverts if is not revoked
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
     * SCENARIO: permitBuilder should reverts if kickback is higher than 100
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
        (,,, bool _revoked,,) = sponsorsManager.builderState(builder);
        assertEq(_revoked, true);
        // THEN gauge is halted
        assertEq(sponsorsManager.isGaugeHalted(address(gauge)), true);
        // THEN halted gauges array length is 1
        assertEq(sponsorsManager.getHaltedGaugesLength(), 1);
        // THEN gauge is not rewarded
        assertEq(sponsorsManager.isGaugeRewarded(address(gauge)), false);
        // THEN rewarded gauges array length is 1
        assertEq(sponsorsManager.getGaugesLength(), 1);
    }

    /**
     * SCENARIO: revokeBuilder should reverts if is already revoked
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
}
