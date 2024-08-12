// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "./BaseTest.sol";
import { BuilderRegistry } from "../src/BuilderRegistry.sol";
import { Governed } from "../src/governance/Governed.sol";

contract BuilderRegistryTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdate(
        address indexed builder_, BuilderRegistry.BuilderState previousState_, BuilderRegistry.BuilderState newState_
    );
    event BuilderKickbackUpdate(address indexed builder_, uint256 builderKickback_);
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
        sponsorsManager.pauseBuilder(builder);

        // WHEN alice calls permitBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        sponsorsManager.permitBuilder(builder);

        // WHEN alice calls setBuilderKickback
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        sponsorsManager.setBuilderKickback(builder, 10);
    }

    /**
     * SCENARIO: revokeBuilder should revert if is not called by the builder
     */
    function test_NotAuthorized() public {
        // GIVEN  a whitelisted builder
        //  AND a sponsor alice
        vm.startPrank(alice);

        // WHEN alice calls revokeBuilder
        //  THEN tx reverts because caller is not the builder
        vm.expectRevert(BuilderRegistry.NotAuthorized.selector);
        sponsorsManager.revokeBuilder(builder);
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
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(_newBuilder, BuilderRegistry.BuilderState.Pending, BuilderRegistry.BuilderState.KYCApproved);
        sponsorsManager.activateBuilder(_newBuilder, _newBuilder, 0);

        // THEN builder.state is KYCApproved
        assertEq(uint256(sponsorsManager.builderState(_newBuilder)), uint256(BuilderRegistry.BuilderState.KYCApproved));

        // THEN builder rewards receiver is the same as the builder
        assertEq(sponsorsManager.builderRewardReceiver(_newBuilder), _newBuilder);
    }

    /**
     * SCENARIO: activateBuilder should reverts if the state is not Pending
     */
    function test_ActivateBuilderWrongStatus() public {
        // GIVEN a builder not in Pending state
        //  AND a kycApprover
        vm.prank(kycApprover);

        // WHEN tries to activateBuilder
        //  THEN tx reverts because is not in the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Pending)
        );
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

        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(
            _newBuilder, BuilderRegistry.BuilderState.KYCApproved, BuilderRegistry.BuilderState.Whitelisted
        );

        Gauge _newGauge = sponsorsManager.whitelistBuilder(_newBuilder);

        // THEN new gauge is assigned to the new builder
        assertEq(address(sponsorsManager.builderToGauge(_newBuilder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(sponsorsManager.gaugeToBuilder(_newGauge), _newBuilder);
        // THEN builder.state is Whitelisted
        assertEq(uint256(sponsorsManager.builderState(_newBuilder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
    }

    /**
     * SCENARIO: whitelistBuilder should reverts if the state is not KYCApproved
     */
    function test_WhitelistBuilderWrongStatus() public {
        // GIVEN a builder not in KYCApproved state
        //  WHEN tries to whitelistBuilder
        //   THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.KYCApproved)
        );
        sponsorsManager.whitelistBuilder(builder);
    }

    /**
     * SCENARIO: Governor pause a builder
     */
    function test_PauseBuilder() public {
        // GIVEN a Whitelisted builder
        //  WHEN calls pauseBuilder
        //   THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(builder, BuilderRegistry.BuilderState.Whitelisted, BuilderRegistry.BuilderState.Paused);
        sponsorsManager.pauseBuilder(builder);

        // THEN builder.state is Paused
        assertEq(uint256(sponsorsManager.builderState(builder)), uint256(BuilderRegistry.BuilderState.Paused));
    }

    /**
     * SCENARIO: pauseBuilder should reverts if the state is not Whitelisted
     */
    function test_PauseBuilderWrongStatus() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");
        // WHEN tries to pauseBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        sponsorsManager.pauseBuilder(_newBuilder);
    }

    /**
     * SCENARIO: Governor permit a builder
     */
    function test_PermitBuilder() public {
        // GIVEN a Revoked builder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder(builder);

        // WHEN calls permitBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(builder, BuilderRegistry.BuilderState.Revoked, BuilderRegistry.BuilderState.Whitelisted);
        sponsorsManager.permitBuilder(builder);

        // THEN builder.state is Whitelisted
        assertEq(uint256(sponsorsManager.builderState(builder)), uint256(BuilderRegistry.BuilderState.Whitelisted));
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
        sponsorsManager.permitBuilder(builder);
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
        emit StateUpdate(builder, BuilderRegistry.BuilderState.Whitelisted, BuilderRegistry.BuilderState.Revoked);
        sponsorsManager.revokeBuilder(builder);

        // THEN builder.state is Revoked
        assertEq(uint256(sponsorsManager.builderState(builder)), uint256(BuilderRegistry.BuilderState.Revoked));
    }

    /**
     * SCENARIO: revokeBuilder should reverts if the state is not Whitelisted
     */
    function test_RevokeBuilderWrongStatus() public {
        // GIVEN a new builder
        address _newBuilder = makeAddr("newBuilder");

        // WHEN tries to revokeBuilder
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        sponsorsManager.revokeBuilder(_newBuilder);
    }

    /**
     * SCENARIO: Governor set new builder kickback
     */
    function test_SetBuilderKickback() public {
        // GIVEN a Whitelisted builder
        //  WHEN calls setBuilderKickback
        //   THEN BuilderKickbackUpdate event is emitted
        vm.expectEmit();
        emit BuilderKickbackUpdate(builder, 5);
        sponsorsManager.setBuilderKickback(builder, 5);

        // THEN builder.builderKickback is 5
        assertEq(sponsorsManager.builderKickback(builder), 5);
    }

    /**
     * SCENARIO: setBuilderKickback should reverts if the state is not Whitelisted
     */
    function test_SetBuilderKickbackWrongStatus() public {
        // GIVEN a Revoked builder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder(builder);
        // WHEN tries to setBuilderKickback
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        sponsorsManager.setBuilderKickback(builder, 5);
    }

    /**
     * SCENARIO: setBuilderKickback should reverts if kickback is higher than 100
     */
    function test_SetBuilderKickbackInvalidBuilderKickback() public {
        // GIVEN a Whitelisted builder
        //  WHEN tries to setBuilderKickback
        //   THEN tx reverts because is not a valid kickback
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickback.selector);
        sponsorsManager.setBuilderKickback(builder, 2 ether);
    }
}
