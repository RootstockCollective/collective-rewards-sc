// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";
import { ResumeBuilderBehavior } from "./ResumeBuilderBehavior.t.sol";

contract RevokeBuilderTest is HaltedBuilderBehavior, ResumeBuilderBehavior {
    function _initialState() internal override(HaltedBuilderBehavior, ResumeBuilderBehavior) {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();

        // AND builder is revoked
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        vm.stopPrank();
    }

    function _resumeGauge() internal override {
        // AND builder is permitted
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.5 ether);
    }

    /**
     * SCENARIO: builder is revoked in the middle of an epoch having allocation.
     *  builder receives all the rewards for the current epoch
     */
    function test_BuildersReceiveCurrentRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
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
     * SCENARIO: builder is revoked in the middle of an epoch having allocation.
     *  Builder doesn't receive those rewards on the next epoch
     */
    function test_BuilderDoesNotReceiveNextRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
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
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        // AND builder is permitted
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.5 ether);

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
     * SCENARIO: builder is permitted with a new kickback before the cooldown end time
     *  and it is not applied
     */
    function test_PermitBuilderBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN builder kickback cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time didn't end
        vm.warp(_cooldownEndTime - 1);

        // WHEN gauge is permitted with a new kickback of 80%
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.8 ether);
        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN previous builder kickback is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder kickback is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder kickback cooldown finishes in 1 sec
        assertEq(_cooldownEndTime, block.timestamp + 1);
        // THEN builder kickback to apply is 50%
        assertEq(sponsorsManager.getKickbackToApply(builder), 0.5 ether);

        // THEN cooldown time ends
        skip(1);
        // THEN builder kickback to apply is 80%
        assertEq(sponsorsManager.getKickbackToApply(builder), 0.8 ether);
    }

    /**
     * SCENARIO: builder is permitted with a new kickback after the cooldown end time
     *  and it is applied
     */
    function test_PermitBuilderAfterCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is revoked
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN builder kickback cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time ends
        vm.warp(_cooldownEndTime);

        // WHEN gauge is permitted with a new kickback of 80%
        vm.startPrank(builder);
        sponsorsManager.permitBuilder(0.8 ether);
        (_previous, _next, _cooldownEndTime) = sponsorsManager.builderKickback(builder);
        // THEN previous builder kickback is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next builder kickback is 80%
        assertEq(_next, 0.8 ether);
        // THEN builder kickback cooldown finished
        assertEq(_cooldownEndTime, block.timestamp);
        // THEN builder kickback to apply is 80%
        assertEq(sponsorsManager.getKickbackToApply(builder), 0.8 ether);
    }
}
