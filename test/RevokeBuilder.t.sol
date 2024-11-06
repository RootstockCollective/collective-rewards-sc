// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";
import { ResumeBuilderBehavior } from "./ResumeBuilderBehavior.t.sol";

contract RevokeBuilderTest is HaltedBuilderBehavior, ResumeBuilderBehavior {
    function _initialState() internal override(HaltedBuilderBehavior, ResumeBuilderBehavior) {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        _initialDistribution();

        // AND builder is revoked
        vm.startPrank(builder);
        backersManager.revokeBuilder();
        vm.stopPrank();
    }

    function _haltGauge() internal override {
        // AND builder is revoked
        vm.startPrank(builder);
        backersManager.revokeBuilder();
        vm.stopPrank();
    }

    function _resumeGauge() internal override {
        // AND builder is permitted
        vm.startPrank(builder);
        backersManager.permitBuilder(0.5 ether);
        vm.stopPrank();
    }

    /**
     * SCENARIO: builder is revoked in the middle of an cycle having allocation.
     *  builder receives all the rewards for the current cycle
     */
    function test_BuildersReceiveCurrentRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is revoked
        _initialState();

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 6.25 ether);
        // THEN builder coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rewardToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver coinbase balance is 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 4.375 ether);
    }

    /**
     * SCENARIO: builder is revoked in the middle of an cycle having allocation.
     *  Builder doesn't receive those rewards on the next cycle
     */
    function test_BuilderDoesNotReceiveNextRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is revoked
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is the same. It didn't receive rewards
        assertEq(rewardToken.balanceOf(builder), 6.25 ether);
        // THEN builder coinbase balance is the same. It didn't receive rewards
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rewardToken balance is 43.75 + 50. All the rewards are to him
        assertEq(rewardToken.balanceOf(builder2Receiver), 93.75 ether);
        // THEN builder2Receiver coinbase balance is 43.75 + 50. All the rewards are to him
        assertEq(builder2Receiver.balance, 9.375 ether);
    }

    /**
     * SCENARIO: There is a distribution, builder is halted, is resumed
     *  and there is a new distribution. The builder receives rewards from the two distributions
     */
    function test_ResumedBuilderClaimsAll() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is revoked
        _initialState();

        // AND builder is permitted
        vm.startPrank(builder);
        backersManager.permitBuilder(0.5 ether);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rewardToken balance is 12.5 = (200 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 12.5 ether);
        // THEN builder coinbase balance is 1.25 = (20 * 2 / 16) * 0.5
        assertEq(builder.balance, 1.25 ether);

        // THEN builder2Receiver rewardToken balance is 87.5 = (200 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 87.5 ether);
        // THEN builder2Receiver coinbase balance is 8.75 = (20 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 8.75 ether);
    }

    /**
     * SCENARIO: builder is permitted with a new reward percentage before the cooldown end time
     *  and it is not applied
     */
    function test_PermitBuilderBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is revoked
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = backersManager.builderRewardPercentage(builder);
        // THEN builder reward percentage cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time didn't end
        vm.warp(_cooldownEndTime - 12 days); // cannot skip an cycle, permit will revert

        // WHEN gauge is permitted with a new reward percentage of 80%
        vm.startPrank(builder);
        backersManager.permitBuilder(0.8 ether);
        (_previous, _next, _cooldownEndTime) = backersManager.builderRewardPercentage(builder);
        // THEN previous builder reward percentage is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder reward percentage is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder reward percentage cooldown didn't finish
        assertGe(_cooldownEndTime, block.timestamp);
        // THEN builder reward percentage to apply is 50%
        assertEq(backersManager.getRewardPercentageToApply(builder), 0.5 ether);

        // THEN cooldown time ends
        skip(12 days);
        // THEN builder reward percentage to apply is 80%
        assertEq(backersManager.getRewardPercentageToApply(builder), 0.8 ether);
    }

    /**
     * SCENARIO: builder is permitted with a new reward percentage after the cooldown end time
     *  and it is applied
     */
    function test_PermitBuilderAfterCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is revoked
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = backersManager.builderRewardPercentage(builder);
        // THEN builder reward percentage cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time ends
        vm.warp(_cooldownEndTime);

        // AND there is a distribution to set the new periodFinish and allow the permit
        _distribute(0, 0);

        // WHEN gauge is permitted with a new reward percentage of 80%
        vm.startPrank(builder);
        backersManager.permitBuilder(0.8 ether);
        (_previous, _next, _cooldownEndTime) = backersManager.builderRewardPercentage(builder);
        // THEN previous builder reward percentage is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder reward percentage is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder reward percentage cooldown finished
        assertLe(_cooldownEndTime, block.timestamp);
        // THEN builder reward percentage to apply is 80%
        assertEq(backersManager.getRewardPercentageToApply(builder), 0.8 ether);
    }
}
