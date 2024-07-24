// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdStorage, StdStorage } from "forge-std/src/Test.sol";
import { BaseTest, Gauge, BuilderRegistry } from "./BaseTest.sol";
import { Governed } from "../src/governance/Governed.sol";

using stdStorage for StdStorage;

contract BuilderRegistryTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdate(
        address indexed builder_, BuilderRegistry.BuilderState previousState_, BuilderRegistry.BuilderState newState_
    );
    event BuilderKickbackPctUpdate(address indexed builder_, uint256 builderKickbackPct_);

    address newBuilder = makeAddr("newBuilder");

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
        builderRegistry.whitelistBuilder(newBuilder);

        // WHEN alice calls pauseBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        builderRegistry.pauseBuilder(newBuilder);

        // WHEN alice calls permitBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        builderRegistry.permitBuilder(newBuilder);

        // WHEN alice calls setBuilderKickbackPct
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        builderRegistry.setBuilderKickbackPct(newBuilder, 10);
    }

    /**
     * SCENARIO: revokeBuilder should revert if is not called by the builder
     */
    function test_NotAuthorized() public {
        // GIVEN a sponsor alice and a whitelisted builder
        vm.startPrank(alice);

        // WHEN alice calls revokeBuilder
        //  THEN tx reverts because caller is not the builder
        vm.expectRevert(BuilderRegistry.NotAuthorized.selector);
        builderRegistry.revokeBuilder(builder);
    }

    /**
     * SCENARIO: Foundation activates a new builder
     */
    function test_ActivateBuilder() public {
        // GIVEN a Foundation and a new builder
        vm.startPrank(foundation);

        // WHEN calls activateBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(newBuilder, BuilderRegistry.BuilderState.Pending, BuilderRegistry.BuilderState.KYCApproved);
        builderRegistry.activateBuilder(newBuilder, newBuilder, 0);

        // THEN builder.state is KYCApproved
        assertEq(uint256(builderRegistry.getState(newBuilder)), uint256(BuilderRegistry.BuilderState.KYCApproved));

        // THEN builder rewards receiver is the same as the builder
        assertEq(builderRegistry.getRewardReceiver(newBuilder), newBuilder);
    }

    /**
     * SCENARIO: activateBuilder should reverts if the state is not Pending
     */
    function test_ActivateBuilderWrongStatus() public {
        // GIVEN a Foundation and a whitelisted builder
        vm.startPrank(foundation);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is not in the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Pending)
        );
        builderRegistry.activateBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: activateBuilder should reverts if kickback percentage is higher than 100
     */
    function test_ActivateBuilderInvalidBuilderKickbackPct() public {
        // GIVEN a Foundation and a new builder
        vm.startPrank(foundation);

        // WHEN tries to activateBuilder with 200% of kickback
        //  THEN tx reverts because is not a valid kickback percentage
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickbackPct.selector);
        builderRegistry.activateBuilder(newBuilder, newBuilder, 2 ether);
    }

    /**
     * SCENARIO: Governor whitelist a new builder
     */
    function test_WhitelistBuilder() public {
        // GIVEN a new builder
        //  AND state is KYCApproved
        vm.prank(foundation);
        builderRegistry.activateBuilder(newBuilder, newBuilder, 0);

        // WHEN calls whitelistBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(newBuilder, BuilderRegistry.BuilderState.KYCApproved, BuilderRegistry.BuilderState.Whitelisted);
        builderRegistry.whitelistBuilder(newBuilder);

        // THEN builder.state is Whitelisted
        assertEq(uint256(builderRegistry.getState(newBuilder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }

    /**
     * SCENARIO: whitelistBuilder should reverts if the state is not KYCApproved
     */
    function test_WhitelistBuilderWrongStatus() public {
        // GIVEN a whitelisted builder
        //  WHEN governance tries to whitelistBuilder again
        //   THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.KYCApproved)
        );
        builderRegistry.whitelistBuilder(newBuilder);
    }

    /**
     * SCENARIO: Governor pause a builder
     */
    function test_PauseBuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN governance calls pauseBuilder
        //   THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(builder, BuilderRegistry.BuilderState.Whitelisted, BuilderRegistry.BuilderState.Paused);
        builderRegistry.pauseBuilder(builder);

        // THEN builder.state is Paused
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Paused));
    }

    /**
     * SCENARIO: pauseBuilder should reverts if the state is not Whitelisted
     */
    function test_PauseBuilderWrongStatus() public {
        // GIVEN a new builder
        //  WHEN governance tries to pauseBuilder
        //   THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.pauseBuilder(newBuilder);
    }

    /**
     * SCENARIO: setBuilderGauge should reverts if the state is not Whitelisted
     */
    function test_SetBuilderGauge() public {
        // GIVEN a new builder
        //  WHEN governance tries to setBuilderGauge
        //   THEN tx reverts because is not the required state
        Gauge newGauge = gaugeFactory.createGauge(newBuilder, address(rewardToken));
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.setBuilderGauge(newGauge);
    }

    /**
     * SCENARIO: Governor permit a builder
     */
    function test_PermitBuilder() public {
        // GIVEN a revoked builder
        vm.prank(builder);
        builderRegistry.revokeBuilder(builder);

        // WHEN governance calls permitBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(builder, BuilderRegistry.BuilderState.Revoked, BuilderRegistry.BuilderState.Whitelisted);
        builderRegistry.permitBuilder(builder);

        // THEN builder.state is Whitelisted
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }

    /**
     * SCENARIO: permitBuilder should reverts if the state is not Revoked
     */
    function test_PermitBuilderWrongStatus() public {
        // GIVEN a whitelisted builder
        //  WHEN governance tries to permitBuilder
        //   THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Revoked)
        );
        builderRegistry.permitBuilder(builder);
    }

    /**
     * SCENARIO: Builder revoke itself
     */
    function test_RevokeBuilder() public {
        // GIVEN a builder whitelisted
        vm.startPrank(builder);

        // WHEN calls revokeBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(builder, BuilderRegistry.BuilderState.Whitelisted, BuilderRegistry.BuilderState.Revoked);
        builderRegistry.revokeBuilder(builder);

        // THEN builder.state is Revoked
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Revoked));
    }

    /**
     * SCENARIO: revokeBuilder should reverts if the state is not Whitelisted
     */
    function test_RevokeBuilderWrongStatus() public {
        // GIVEN a new builder
        vm.startPrank(newBuilder);

        // WHEN tries to revokeBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.revokeBuilder(newBuilder);
    }

    /**
     * SCENARIO: Governor set new builder kickback percentage
     */
    function test_SetBuilderKickbackPct() public {
        // GIVEN a whitelisted builder
        //  WHEN governance calls setBuilderKickbackPct
        //   THEN BuilderKickbackPctUpdate event is emitted
        vm.expectEmit();
        emit BuilderKickbackPctUpdate(builder, 5);
        builderRegistry.setBuilderKickbackPct(builder, 5);

        // THEN builder.builderKickbackPct is 5
        assertEq(builderRegistry.getBuilderKickbackPct(builder), 5);
    }

    /**
     * SCENARIO: setBuilderKickbackPct should reverts if the state is not Whitelisted
     */
    function test_SetBuilderKickbackPctWrongStatus() public {
        // GIVEN a new builder
        //  WHEN governance tries to setBuilderKickbackPct
        //   THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.setBuilderKickbackPct(newBuilder, 5);
    }

    /**
     * SCENARIO: setBuilderKickbackPct should reverts if kickback percentage is higher than 100
     */
    function test_SetBuilderKickbackPctInvalidBuilderKickbackPct() public {
        // GIVEN a whitelisted builder
        //  WHEN governance tries to setBuilderKickbackPct with 200% of kickback
        //   THEN tx reverts because is not a valid kickback percentage
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickbackPct.selector);
        builderRegistry.setBuilderKickbackPct(builder, 2 ether);
    }
}
