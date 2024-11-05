// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { BuilderRegistryRootstockCollective } from "../src/BuilderRegistryRootstockCollective.sol";

contract setBuilderRewardPercentageTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event BuilderRewardPercentageUpdateScheduled(
        address indexed builder_, uint256 rewardPercentage_, uint256 expiration_
    );

    function _setUp() internal override { }

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

        // AND builder sets a new reward percentage of 10%
        vm.startPrank(builder);
        sponsorsManager.setBuilderRewardPercentage(0.1 ether);
        vm.stopPrank();
    }

    /**
     * SCENARIO: setBuilderRewardPercentage should revert if is not called by the builder
     */
    function test_CallerIsNotABuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN calls setBuilderRewardPercentage
        //   THEN tx reverts because caller is not an operational builder
        vm.expectRevert(BuilderRegistryRootstockCollective.NotOperational.selector);
        sponsorsManager.setBuilderRewardPercentage(0.1 ether);
    }

    /**
     * SCENARIO: Builder sets a new reward percentage
     */
    function test_setBuilderRewardPercentage() public {
        // GIVEN a Whitelisted builder
        //  WHEN builder calls setBuilderRewardPercentage
        vm.prank(builder);
        //   THEN BuilderRewardPercentageUpdateScheduled event is emitted
        vm.expectEmit();
        emit BuilderRewardPercentageUpdateScheduled(builder, 0.1 ether, block.timestamp + 2 weeks);
        sponsorsManager.setBuilderRewardPercentage(0.1 ether);

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        // THEN previous builder reward percentage is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder reward percentage is 10%
        assertEq(_next, 0.1 ether);
        // THEN builder reward percentage cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);
        // THEN builder reward percentage to apply is 50%
        assertEq(sponsorsManager.getRewardPercentageToApply(builder), 0.5 ether);
    }

    /**
     * SCENARIO: Builder sets a new reward percentage with the same value
     */
    function test_setBuilderRewardPercentageSameValue() public {
        // GIVEN a Whitelisted builder with 50% of reward percentage
        //  WHEN builder calls setBuilderRewardPercentage again with 50%
        vm.prank(builder);
        sponsorsManager.setBuilderRewardPercentage(0.5 ether);

        (uint64 _previous, uint64 _next,) = sponsorsManager.builderRewardPercentage(builder);
        // THEN previous and next reward percentages are the same
        assertEq(_previous, _next);
        // THEN builder reward percentage to apply is 50%
        assertEq(sponsorsManager.getRewardPercentageToApply(builder), 0.5 ether);
    }

    /**
     * SCENARIO: setBuilderRewardPercentage reverts if it is not operational
     */
    function test_RevertsetBuilderRewardPercentageWrongStatus() public {
        // GIVEN a Paused builder
        vm.startPrank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");
        // WHEN tries to setBuilderRewardPercentage
        //  THEN tx reverts because is not operational
        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.NotOperational.selector);
        sponsorsManager.setBuilderRewardPercentage(0.1 ether);
    }

    /**
     * SCENARIO: setBuilderRewardPercentage should reverts if reward percentage is higher than 100
     */
    function test_setBuilderRewardPercentageInvalidBuilderRewardPercentage() public {
        // GIVEN a Whitelisted builder
        //  WHEN tries to setBuilderRewardPercentage
        //   THEN tx reverts because is not a valid reward percentage
        vm.prank(builder);
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBuilderRewardPercentage.selector);
        sponsorsManager.setBuilderRewardPercentage(2 ether);
    }

    /**
     * SCENARIO: Builder sets a new reward percentage again before it is applied and needs to wait the cooldown again
     */
    function test_setBuilderRewardPercentageTwiceBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND builder sets a new reward percentage of 10%
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        // AND cooldown time didn't end
        vm.warp(_cooldownEndTime - 1);

        // AND builder sets the reward percentage to 80%
        vm.prank(builder);
        sponsorsManager.setBuilderRewardPercentage(0.8 ether);
        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        // THEN previous builder reward percentage is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder reward percentage is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder reward percentage cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);
        // THEN builder reward percentage to apply is 50%
        assertEq(sponsorsManager.getRewardPercentageToApply(builder), 0.5 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 50% of rewardToken 6.25 = (100 * 2 / 16) * 0.5
        assertEq(_clearERC20Balance(builder), 6.25 ether);
        // THEN builder receives 50% of coinbase 0.625 = (10 * 2 / 16) * 0.5
        assertEq(_clearCoinbaseBalance(builder), 0.625 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewCycle();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 50% of rewardToken 6.25 = (100 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 6.25 ether, 100);
        // THEN alice receives 50% of coinbase 0.625 = (10 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.625 ether, 100);

        // AND cooldown time ends
        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        vm.warp(_cooldownEndTime);
        // THEN builder reward percentage to apply is 80%
        assertEq(sponsorsManager.getRewardPercentageToApply(builder), 0.8 ether);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 20% of rewards 2.5 = (100 * 2 / 16) * 0.2
        assertEq(_clearERC20Balance(builder), 2.5 ether);
        // THEN builder receives 20% of coinbase 0.25 = (10 * 2 / 16) * 0.2
        assertEq(_clearCoinbaseBalance(builder), 0.25 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewCycle();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 80% of rewardToken 10 = (100 * 2 / 16) * 0.8
        assertApproxEqAbs(_clearERC20Balance(alice), 10 ether, 100);
        // THEN alice receives 80% of coinbase 1 = (10 * 2 / 16) * 0.8
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1 ether, 100);
    }

    /**
     * SCENARIO: Builder sets a new reward percentage again after cooldown and previous one it is applied
     */
    function test_setBuilderRewardPercentageTwiceAfterCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND builder sets a new reward percentage of 10%
        _initialState();

        // AND cooldown time ends
        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        vm.warp(_cooldownEndTime);
        // THEN builder reward percentage to apply is 10%
        assertEq(sponsorsManager.getRewardPercentageToApply(builder), 0.1 ether);
        // AND builder sets the reward percentage to 80%
        vm.prank(builder);
        sponsorsManager.setBuilderRewardPercentage(0.8 ether);
        // THEN builderRewardPercentageExpiration is 2 weeks from now
        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        // THEN previous builder reward percentage is 10%
        assertEq(_previous, 0.1 ether);
        // THEN next builder reward percentage is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder reward percentage to apply is still 10%
        assertEq(sponsorsManager.getRewardPercentageToApply(builder), 0.1 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 90% of rewardToken 11.25 = (100 * 2 / 16) * 0.9
        assertEq(_clearERC20Balance(builder), 11.25 ether);
        // THEN builder receives 90% of coinbase 1.125 = (10 * 2 / 16) * 0.9
        assertEq(_clearCoinbaseBalance(builder), 1.125 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewCycle();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 10% of rewardToken 1.25 = (100 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearERC20Balance(alice), 1.25 ether, 100);
        // THEN alice receives 10% of coinbase 0.125 = (10 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.125 ether, 100);
    }

    /**
     * SCENARIO: Builder sets a new reward percentage and there are 2 distributions with the new one
     */
    function test_BuilderRewardPercentageUpdate() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND builder sets a new reward percentage of 10%
        _initialState();
        // AND cooldown time ends
        (,, uint128 _cooldownEndTime) = sponsorsManager.builderRewardPercentage(builder);
        vm.warp(_cooldownEndTime);
        // THEN builder reward percentage to apply is 10%
        assertEq(sponsorsManager.getRewardPercentageToApply(builder), 0.1 ether);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 90% of rewardToken 11.125 = (100 * 2 / 16) * 0.9
        assertEq(_clearERC20Balance(builder), 11.25 ether);
        // THEN builder receives 90% of coinbase 1.125 = (10 * 2 / 16) * 0.9
        assertEq(_clearCoinbaseBalance(builder), 1.125 ether);

        // WHEN alice claims the rewards
        _skipAndStartNewCycle();
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
        _skipAndStartNewCycle();
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 10% of rewardToken 1.25 = (100 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearERC20Balance(alice), 1.25 ether, 100);
        // THEN alice receives 10% of coinbase 0.125 = (10 * 2 / 16) * 0.1
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.125 ether, 100);
    }
}
