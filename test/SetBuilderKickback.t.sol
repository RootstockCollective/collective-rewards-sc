// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { BuilderRegistry } from "../src/BuilderRegistry.sol";

contract SetBuilderKickbackTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderKickbackUpdateScheduled(address indexed builder_, uint256 kickback_, uint256 expiration_);

    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(sponsorsManager), 100_000 ether);
    }

    function _initialState() internal {
        // GIVEN alice allocates to builder and builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND builder sets a new kickback of 10%
        vm.startPrank(builder);
        sponsorsManager.setBuilderKickback(builder, 0.1 ether);
        vm.stopPrank();
    }

    /**
     * SCENARIO: setBuilderKickback should revert if is not called by the builder
     */
    function test_NotAuthorized() public {
        // GIVEN a whitelisted builder
        //  WHEN calls setBuilderKickback
        //   THEN tx reverts because caller is not the builder
        vm.expectRevert(BuilderRegistry.NotAuthorized.selector);
        sponsorsManager.setBuilderKickback(builder, 0.1 ether);
    }

    /**
     * SCENARIO: Builder sets a new kickback
     */
    function test_SetBuilderKickback() public {
        // GIVEN a Whitelisted builder
        //  WHEN builder calls setBuilderKickback
        vm.prank(builder);
        //   THEN BuilderKickbackUpdateScheduled event is emitted
        vm.expectEmit();
        emit BuilderKickbackUpdateScheduled(builder, 0.1 ether, block.timestamp + 2 weeks);
        sponsorsManager.setBuilderKickback(builder, 0.1 ether);

        (uint64 _previous, uint64 _latests, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN previous builder kickback is 50%
        assertEq(_previous, 0.5 ether);
        // THEN latest builder kickback is 10%
        assertEq(_latests, 0.1 ether);
        // THEN builder kickback cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);
    }

    /**
     * SCENARIO: setBuilderKickback reverts if the state is not Whitelisted
     */
    function test_RevertSetBuilderKickbackWrongStatus() public {
        // GIVEN a Revoked builder
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder(builder);
        // WHEN tries to setBuilderKickback
        //  THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(BuilderRegistry.RequiredState.selector, BuilderRegistry.BuilderState.Whitelisted)
        );
        sponsorsManager.setBuilderKickback(builder, 0.1 ether);
    }

    /**
     * SCENARIO: setBuilderKickback should reverts if kickback is higher than 100
     */
    function test_SetBuilderKickbackInvalidBuilderKickback() public {
        // GIVEN a Whitelisted builder
        //  WHEN tries to setBuilderKickback
        //   THEN tx reverts because is not a valid kickback
        vm.prank(builder);
        vm.expectRevert(BuilderRegistry.InvalidBuilderKickback.selector);
        sponsorsManager.setBuilderKickback(builder, 2 ether);
    }

    /**
     * SCENARIO: Builder sets a new kickback again before it is applied and needs to wait the cooldown again
     */
    function test_SetBuilderKickbackTwiceBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND builder sets a new kickback of 10%
        _initialState();

        (uint64 _previous, uint64 _latests, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // AND cooldown time didn't end
        vm.warp(_cooldownEndTime - 1);

        // AND builder sets the kickback to 80%
        vm.prank(builder);
        sponsorsManager.setBuilderKickback(builder, 0.8 ether);
        (_previous, _latests, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN previous builder kickback is 50%
        assertEq(_previous, 0.5 ether);
        // THEN latest builder kickback is 80%
        assertEq(_latests, 0.8 ether);
        // THEN builder kickback cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 50% of rewardToken 6.25 = (100 * 2 / 16) * 0.5
        assertEq(_clearERC20Balance(builder), 6.25 ether);
        // THEN builder receives 50% of coinbase 0.625 = (10 * 2 / 16) * 0.5
        assertEq(_clearCoinbaseBalance(builder), 0.625 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewEpoch();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 50% of rewardToken 6.25 = (100 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 6.25 ether, 100);
        // THEN alice receives 50% of coinbase 0.625 = (10 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.625 ether, 100);

        // AND cooldown time ends
        (_previous, _latests, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        vm.warp(_cooldownEndTime);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 20% of rewards 2.5 = (100 * 2 / 16) * 0.2
        assertEq(_clearERC20Balance(builder), 2.5 ether);
        // THEN builder receives 20% of coinbase 0.25 = (10 * 2 / 16) * 0.2
        assertEq(_clearCoinbaseBalance(builder), 0.25 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewEpoch();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 80% of rewardToken 10 = (100 * 2 / 16) * 0.8
        assertApproxEqAbs(_clearERC20Balance(alice), 10 ether, 100);
        // THEN alice receives 80% of coinbase 1 = (10 * 2 / 16) * 0.8
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1 ether, 100);
    }

    /**
     * SCENARIO: Builder sets a new kickback again after cooldown and previous one it is applied
     */
    function test_SetBuilderKickbackTwiceAfterCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND builder sets a new kickback of 10%
        _initialState();

        // AND cooldown time ends
        (uint64 _previous, uint64 _latests, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        vm.warp(_cooldownEndTime);
        // AND builder sets the kickback to 80%
        vm.prank(builder);
        sponsorsManager.setBuilderKickback(builder, 0.8 ether);
        // THEN builderKickbackExpiration is 2 weeks from now
        (_previous, _latests, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        (_previous, _latests, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN previous builder kickback is 10%
        assertEq(_previous, 0.1 ether);
        // THEN latest builder kickback is 80%
        assertEq(_latests, 0.8 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 90% of rewardToken 11.25 = (100 * 2 / 16) * 0.9
        assertEq(_clearERC20Balance(builder), 11.25 ether);
        // THEN builder receives 90% of coinbase 1.125 = (10 * 2 / 16) * 0.9
        assertEq(_clearCoinbaseBalance(builder), 1.125 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewEpoch();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 10% of rewardToken 1.25 = (100 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearERC20Balance(alice), 1.25 ether, 100);
        // THEN alice receives 10% of coinbase 0.125 = (10 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.125 ether, 100);
    }

    /**
     * SCENARIO: Builder sets a new kickback and there are 2 distributions with the new one
     */
    function test_BuilderKickbackUpdate() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND builder sets a new kickback of 10%
        _initialState();
        // AND cooldown time ends
        (,, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        vm.warp(_cooldownEndTime);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 90% of rewardToken 11.125 = (100 * 2 / 16) * 0.9
        assertEq(_clearERC20Balance(builder), 11.25 ether);
        // THEN builder receives 90% of coinbase 1.125 = (10 * 2 / 16) * 0.9
        assertEq(_clearCoinbaseBalance(builder), 1.125 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewEpoch();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 10% of rewardToken 1.25 = (100 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearERC20Balance(alice), 1.25 ether, 100);
        // THEN alice receives 10% of coinbase 0.125 = (10 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.125 ether, 100);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 90% of rewardToken 11.125 = (100 * 2 / 16) * 0.9
        assertEq(_clearERC20Balance(builder), 11.25 ether);
        // THEN builder receives 90% of coinbase 1.125 = (10 * 2 / 16) * 0.9
        assertEq(_clearCoinbaseBalance(builder), 1.125 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewEpoch();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 10% of rewardToken 1.25 = (100 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearERC20Balance(alice), 1.25 ether, 100);
        // THEN alice receives 10% of coinbase 0.125 = (10 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.125 ether, 100);
    }
}
