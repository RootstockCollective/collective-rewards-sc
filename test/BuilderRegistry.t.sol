// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdStorage, StdStorage } from "forge-std/src/Test.sol";
import { BaseTest, BuilderRegistry } from "./BaseTest.sol";
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
        builderRegistry.whitelistBuilder(builder);

        // WHEN alice calls pauseBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        builderRegistry.pauseBuilder(builder);

        // WHEN alice calls permitBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        builderRegistry.permitBuilder(builder);

        // WHEN alice calls setBuilderKickbackPct
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        builderRegistry.setBuilderKickbackPct(builder, 10);
    }

    /**
     * SCENARIO: revokeBuilder should revert if is not called by the builder
     */
    function test_NotAuthorized() public {
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

        // GIVEN a sponsor alice
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
        // GIVEN a Foundation
        vm.startPrank(foundation);

        // WHEN calls activateBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(builder, BuilderRegistry.BuilderState.Pending, BuilderRegistry.BuilderState.KYCApproved);
        builderRegistry.activateBuilder(builder, builder, 0);

        // THEN builder.state is KYCApproved
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.KYCApproved));

        // THEN builder rewards receiver is the same as the builder
        assertEq(builderRegistry.getRewardReceiver(builder), builder);
    }

    /**
     * SCENARIO: activateBuilder should reverts if the state is not Pending
     */
    function test_ActivateBuilderWrongStatus() public {
        // GIVEN a Foundation
        vm.startPrank(foundation);

        // WHEN state is not Pending
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

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
        // GIVEN a Foundation
        vm.startPrank(foundation);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is not a valid kickback percentage
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickbackPct.selector);
        builderRegistry.activateBuilder(builder, builder, 2 ether);
    }

    /**
     * SCENARIO: Governor whitelist a new builder
     */
    function test_WhitelistBuilder() public {
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is KYCApproved
        _setBuilderState(builder, BuilderRegistry.BuilderState.KYCApproved);

        // WHEN calls whitelistBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(builder, BuilderRegistry.BuilderState.KYCApproved, BuilderRegistry.BuilderState.Whitelisted);
        builderRegistry.whitelistBuilder(builder);

        // THEN builder.state is Whitelisted
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }

    /**
     * SCENARIO: whitelistBuilder should reverts if the state is not KYCApproved
     */
    function test_WhitelistBuilderWrongStatus() public {
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is not KYCApproved
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

        // WHEN tries to whitelistBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.KYCApproved)
        );
        builderRegistry.whitelistBuilder(builder);
    }

    /**
     * SCENARIO: Governor pause a builder
     */
    function test_PauseBuilder() public {
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is Whitelisted
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

        // WHEN calls pauseBuilder
        //  THEN StateUpdate event is emitted
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
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is not Whitelisted
        _setBuilderState(builder, BuilderRegistry.BuilderState.Revoked);

        // WHEN tries to pauseBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.pauseBuilder(builder);
    }

    /**
     * SCENARIO: Governor permit a builder
     */
    function test_PermitBuilder() public {
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is Revoked
        _setBuilderState(builder, BuilderRegistry.BuilderState.Revoked);

        // WHEN calls permitBuilder
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
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is not Revoked
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

        // WHEN tries to permitBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Revoked)
        );
        builderRegistry.permitBuilder(builder);
    }

    /**
     * SCENARIO: Builder revoke itself
     */
    function test_RevokeBuilder() public {
        // GIVEN a builder
        vm.startPrank(builder);

        // WHEN state is Whitelisted
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

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
        // GIVEN a builder
        vm.startPrank(builder);

        // WHEN state is not Whitelisted
        _setBuilderState(builder, BuilderRegistry.BuilderState.Revoked);

        // WHEN tries to revokeBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.revokeBuilder(builder);
    }

    /**
     * SCENARIO: Governor set new builder kickback percentage
     */
    function test_SetBuilderKickbackPct() public {
        // GIVEN a Governor
        vm.startPrank(governor);

        // GIVEN builder.builderKickbackPct is 0
        assertEq(builderRegistry.getBuilderKickbackPct(builder), 0);

        // WHEN state is Whitelisted
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

        // WHEN calls setBuilderKickbackPct
        //  THEN BuilderKickbackPctUpdate event is emitted
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
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is not Whitelisted
        _setBuilderState(builder, BuilderRegistry.BuilderState.Revoked);

        // WHEN tries to setBuilderKickbackPct
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.setBuilderKickbackPct(builder, 5);
    }

    /**
     * SCENARIO: setBuilderKickbackPct should reverts if kickback percentage is higher than 100
     */
    function test_SetBuilderKickbackPctInvalidBuilderKickbackPct() public {
        // GIVEN a Governor
        vm.startPrank(governor);

        // WHEN state is Whitelisted
        _setBuilderState(builder, BuilderRegistry.BuilderState.Whitelisted);

        // WHEN tries to setBuilderKickbackPct
        //  THEN tx reverts because is not a valid kickback percentage
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickbackPct.selector);
        builderRegistry.setBuilderKickbackPct(builder, 2 ether);
    }

    /**
     * SCENARIO: Getting builder state
     */
    function test_GetState() public {
        // GIVEN a builder
        vm.startPrank(builder);

        // WHEN state is was previously updated to Revoked
        _setBuilderState(builder, BuilderRegistry.BuilderState.Revoked);

        // THEN builder.state is Revoked
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Revoked));
    }

    /**
     * SCENARIO: Getting builder reward receiver
     */
    function test_GetRewardReceiver() public {
        // GIVEN a foundation
        vm.startPrank(foundation);

        // WHEN reward receiver was previously updated to builder
        _setRewardReceiver(builder, builder);

        // THEN builder.rewardReceiver is builder
        assertEq(builderRegistry.getRewardReceiver(builder), builder);
    }

    /**
     * SCENARIO: Getting builder kickback percentage
     */
    function test_GetBuilderKickbackPct() public {
        // GIVEN a governor
        vm.startPrank(governor);

        // WHEN kickback percentage was previously updated to 10
        _setBuilderBuilderKickbackPct(builder, 10);

        // THEN builder.builderKickbackPct is 10
        assertEq(builderRegistry.getBuilderKickbackPct(builder), 10);
    }

    function _setBuilderState(address builder_, BuilderRegistry.BuilderState state_) internal {
        stdstore.target(address(builderRegistry)).sig("builderState(address)").with_key(builder_).checked_write(
            uint256(state_)
        );
    }

    function _setRewardReceiver(address builder_, address rewardReceiver_) internal {
        stdstore.target(address(builderRegistry)).sig("builderRewardReceiver(address)").with_key(builder_).checked_write(
            rewardReceiver_
        );
    }

    function _setBuilderBuilderKickbackPct(address builder_, uint256 builderKickbackPct_) internal {
        stdstore.target(address(builderRegistry)).sig("builderKickbackPct(address)").with_key(builder_).checked_write(
            builderKickbackPct_
        );
    }
}
