// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, BuilderRegistry } from "./BaseTest.sol";
import { Governed } from "../src/governance/Governed.sol";

contract BuilderRegistryTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdated(
        address indexed builder_, BuilderRegistry.BuilderState previousState_, BuilderRegistry.BuilderState newState_
    );
    event BuilderKickbackUpdated(address indexed builder_, uint256 builderKickback_);

    /**
     * SCENARIO: functions protected by OnlyGovernor should revert when are not
     *  called by Governor
     */
    function test_OnlyGovernor() public {
        // GIVEN a supporter alice
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

        // WHEN alice calls setBuilderKickback
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        builderRegistry.setBuilderKickback(builder, 10);
    }

    /**
     * SCENARIO: revokeBuilder should revert if is not called by the builder
     */
    function test_NotAuthorized() public {
        // GIVEN  a whitelisted builder
        _whitelistBuilder(builder);

        // GIVEN a supporter alice
        vm.startPrank(alice);

        // WHEN alice calls revokeBuilder
        //  THEN tx reverts because caller is not the builder
        vm.expectRevert(BuilderRegistry.NotAuthorized.selector);
        builderRegistry.revokeBuilder(builder);
    }

    /**
     * SCENARIO: kycApprover activates a new builder
     */
    function test_ActivateBuilder() public {
        // GIVEN a kycApprover
        vm.startPrank(kycApprover);

        // WHEN calls activateBuilder
        //  THEN StateUpdated event is emitted
        vm.expectEmit();
        emit StateUpdated(builder, BuilderRegistry.BuilderState.Pending, BuilderRegistry.BuilderState.KYCApproved);
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
        // GIVEN a builder not in Pending state
        _whitelistBuilder(builder);

        // GIVEN a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is not in the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Pending)
        );
        builderRegistry.activateBuilder(builder, builder, 0);
    }

    /**
     * SCENARIO: activateBuilder should reverts if kickback is higher than 100
     */
    function test_ActivateBuilderInvalidBuilderKickback() public {
        // GIVEN a kycApprover
        vm.startPrank(kycApprover);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is not a valid kickback
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickback.selector);
        builderRegistry.activateBuilder(builder, builder, 2 ether);
    }

    /**
     * SCENARIO: Governor whitelist a new builder
     */
    function test_WhitelistBuilder() public {
        // GIVEN  a KYCApproved builder
        vm.startPrank(kycApprover);
        builderRegistry.activateBuilder(builder, builder, 0);

        // WHEN calls whitelistBuilder
        //  THEN StateUpdated event is emitted
        vm.expectEmit();
        emit StateUpdated(builder, BuilderRegistry.BuilderState.KYCApproved, BuilderRegistry.BuilderState.Whitelisted);
        builderRegistry.whitelistBuilder(builder);

        // THEN builder.state is Whitelisted
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }

    /**
     * SCENARIO: whitelistBuilder should reverts if the state is not KYCApproved
     */
    function test_WhitelistBuilderWrongStatus() public {
        // GIVEN a builder not in KYCApproved state
        _whitelistBuilder(builder);

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
        // GIVEN  a Whitelisted builder
        _whitelistBuilder(builder);

        // WHEN calls pauseBuilder
        //  THEN StateUpdated event is emitted
        vm.expectEmit();
        emit StateUpdated(builder, BuilderRegistry.BuilderState.Whitelisted, BuilderRegistry.BuilderState.Paused);
        builderRegistry.pauseBuilder(builder);

        // THEN builder.state is Paused
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Paused));
    }

    /**
     * SCENARIO: pauseBuilder should reverts if the state is not Whitelisted
     */
    function test_PauseBuilderWrongStatus() public {
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
        // GIVEN a Revoked builder
        _whitelistBuilder(builder);
        vm.startPrank(builder);
        builderRegistry.revokeBuilder(builder);

        // WHEN calls permitBuilder
        //  THEN StateUpdated event is emitted
        vm.expectEmit();
        emit StateUpdated(builder, BuilderRegistry.BuilderState.Revoked, BuilderRegistry.BuilderState.Whitelisted);
        builderRegistry.permitBuilder(builder);

        // THEN builder.state is Whitelisted
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }

    /**
     * SCENARIO: permitBuilder should reverts if the state is not Revoked
     */
    function test_PermitBuilderWrongStatus() public {
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
        // GIVEN a Whitelisted builder
        _whitelistBuilder(builder);

        // GIVEN a builder
        vm.startPrank(builder);

        // WHEN calls revokeBuilder
        //  THEN StateUpdated event is emitted
        vm.expectEmit();
        emit StateUpdated(builder, BuilderRegistry.BuilderState.Whitelisted, BuilderRegistry.BuilderState.Revoked);
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

        // WHEN tries to revokeBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.revokeBuilder(builder);
    }

    /**
     * SCENARIO: Governor set new builder kickback
     */
    function test_SetBuilderKickback() public {
        // GIVEN  a Whitelisted builder
        _whitelistBuilder(builder);

        // GIVEN builder.builderKickback is 0
        assertEq(builderRegistry.getBuilderKickback(builder), 0);

        // WHEN calls setBuilderKickback
        //  THEN BuilderKickbackUpdated event is emitted
        vm.expectEmit();
        emit BuilderKickbackUpdated(builder, 5);
        builderRegistry.setBuilderKickback(builder, 5);

        // THEN builder.builderKickback is 5
        assertEq(builderRegistry.getBuilderKickback(builder), 5);
    }

    /**
     * SCENARIO: setBuilderKickback should reverts if the state is not Whitelisted
     */
    function test_SetBuilderKickbackWrongStatus() public {
        // WHEN tries to setBuilderKickback
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        builderRegistry.setBuilderKickback(builder, 5);
    }

    /**
     * SCENARIO: setBuilderKickback should reverts if kickback is higher than 100
     */
    function test_SetBuilderKickbackInvalidBuilderKickback() public {
        // GIVEN  a Whitelisted builder
        _whitelistBuilder(builder);

        // WHEN tries to setBuilderKickback
        //  THEN tx reverts because is not a valid kickback
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickback.selector);
        builderRegistry.setBuilderKickback(builder, 2 ether);
    }

    /**
     * SCENARIO: Getting builder state
     */
    function test_GetState() public {
        // GIVEN  a Whitelisted builder
        _whitelistBuilder(builder);

        // GIVEN a builder
        vm.startPrank(builder);

        // THEN builder.state is Revoked
        assertEq(uint256(builderRegistry.getState(builder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }

    /**
     * SCENARIO: Getting builder reward receiver
     */
    function test_GetRewardReceiver() public {
        // GIVEN a kycApprover
        vm.startPrank(kycApprover);

        // WHEN reward receiver was previously updated to builder
        builderRegistry.activateBuilder(builder, builder, 0);

        // THEN builder.rewardReceiver is builder
        assertEq(builderRegistry.getRewardReceiver(builder), builder);
    }

    /**
     * SCENARIO: Getting builder kickback
     */
    function test_GetBuilderKickback() public {
        // GIVEN a kycApprover
        vm.startPrank(kycApprover);

        // WHEN kickback was previously updated to 10
        builderRegistry.activateBuilder(builder, builder, 10);

        // THEN builder.builderKickback is 10
        assertEq(builderRegistry.getBuilderKickback(builder), 10);
    }

    function _whitelistBuilder(address builder_) internal {
        vm.prank(kycApprover);
        builderRegistry.activateBuilder(builder_, builder_, 0);
        vm.prank(governor);
        builderRegistry.whitelistBuilder(builder_);
    }
}
