// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";
import { ResumeBuilderBehavior } from "./ResumeBuilderBehavior.t.sol";

contract PauseSelfBuilderTest is HaltedBuilderBehavior, ResumeBuilderBehavior {
    function _initialState() internal override(HaltedBuilderBehavior, ResumeBuilderBehavior) {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native are distributed
        //   AND half cycle pass
        _initialDistribution();

        // AND builder pauses himself
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        vm.stopPrank();
    }

    function _haltGauge() internal override {
        // AND builder pauses himself
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        vm.stopPrank();
    }

    function _resumeGauge() internal override {
        // AND builder unpauses himself
        vm.startPrank(builder);
        builderRegistry.unpauseSelf(0.5 ether);
        vm.stopPrank();
    }

    /**
     * SCENARIO: builder pauses himself in the middle of an cycle having allocation.
     *  builder receives all the rewards for the current cycle
     */
    function test_BuildersReceiveCurrentRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native are distributed
        //   AND half cycle pass
        //    AND builder is self paused
        _initialState();

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder), 6.25 ether);
        // THEN builder usdrifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder), 6.25 ether);
        // THEN builder native balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rifToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver usdrifToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver native balance is 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 4.375 ether);
    }

    /**
     * SCENARIO: builder pauses himself in the middle of an cycle having allocation.
     *  Builder doesn't receive those rewards on the next cycle
     */
    function test_BuilderDoesNotReceiveNextRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native are distributed
        //   AND half cycle pass
        //    AND builder is self pauses
        _initialState();
        // AND 100 rif, 100 usdrif and 10 native tokens are distributed
        _distribute(100 ether, 100 ether, 10 ether);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rifToken balance is the same. It didn't receive rewards
        assertEq(rifToken.balanceOf(builder), 6.25 ether);
        // THEN builder usdrifToken balance is the same. It didn't receive rewards
        assertEq(usdrifToken.balanceOf(builder), 6.25 ether);
        // THEN builder native balance is the same. It didn't receive rewards
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rifToken balance is 43.75 + 50. All the rewards are to him
        assertEq(rifToken.balanceOf(builder2Receiver), 93.75 ether);
        // THEN builder2Receiver usdrifToken balance is 43.75 + 50. All the rewards are to him
        assertEq(usdrifToken.balanceOf(builder2Receiver), 93.75 ether);
        // THEN builder2Receiver native balance is 43.75 + 50. All the rewards are to him
        assertEq(builder2Receiver.balance, 9.375 ether);
    }

    /**
     * SCENARIO: There is a distribution, builder is halted, is resumed
     *  and there is a new distribution. The builder receives rewards from the two distributions
     */
    function test_ResumedBuilderClaimsAll() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native are distributed
        //   AND half cycle pass
        //    AND builder is self paused
        _initialState();

        // AND builder unpauses himself
        vm.startPrank(builder);
        builderRegistry.unpauseSelf(0.5 ether);

        // AND 100 rif, 100 usdrif and 10 native tokens are distributed
        _distribute(100 ether, 100 ether, 10 ether);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rifToken balance is 12.5 = (200 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder), 12.5 ether);
        // THEN builder usdrifToken balance is 12.5 = (200 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder), 12.5 ether);
        // THEN builder native balance is 1.25 = (20 * 2 / 16) * 0.5
        assertEq(builder.balance, 1.25 ether);

        // THEN builder2Receiver rifToken balance is 87.5 = (200 * 14 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder2Receiver), 87.5 ether);
        // THEN builder2Receiver usdrifToken balance is 87.5 = (200 * 14 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder2Receiver), 87.5 ether);
        // THEN builder2Receiver native balance is 8.75 = (20 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 8.75 ether);
    }

    /**
     * SCENARIO: builder unpauses himself with a new reward percentage before the cooldown end time
     *  and it is not applied
     */
    function test_BuilderUnpauseSelfBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native are distributed
        //   AND half cycle pass
        //    AND builder pauses himself
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = builderRegistry.backerRewardPercentage(builder);
        // THEN backer reward percentage cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time didn't end
        vm.warp(_cooldownEndTime - 12 days); // cannot skip an cycle, unpauseSelf will revert

        // WHEN gauge is self unpaused by the builder with a new reward percentage of 80%
        vm.startPrank(builder);
        builderRegistry.unpauseSelf(0.8 ether);
        (_previous, _next, _cooldownEndTime) = builderRegistry.backerRewardPercentage(builder);
        // THEN previous backer reward percentage is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next backer reward percentage is 80%
        assertEq(_next, 0.8 ether);
        // THEN backer reward percentage cooldown didn't finish
        assertGe(_cooldownEndTime, block.timestamp);
        // THEN backer reward percentage to apply is 50%
        assertEq(builderRegistry.getRewardPercentageToApply(builder), 0.5 ether);

        // THEN cooldown time ends
        skip(12 days);
        // THEN backer reward percentage to apply is 80%
        assertEq(builderRegistry.getRewardPercentageToApply(builder), 0.8 ether);
    }

    /**
     * SCENARIO: builder unpauses himself with a new reward percentage after the cooldown end time
     *  and it is applied
     */
    function test_BuilderUnpauseSelfAfterCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native are distributed
        //   AND half cycle pass
        //    AND builder pauses himself
        _initialState();

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = builderRegistry.backerRewardPercentage(builder);
        // THEN backer reward percentage cooldown end time is 2 weeks from now
        assertEq(_cooldownEndTime, block.timestamp + 2 weeks);

        // AND cooldown time ends
        vm.warp(_cooldownEndTime);

        // AND there is a distribution to set the new periodFinish and allow the self unpause
        _distribute(0, 0, 0);

        // WHEN gauge is self unpause with a new reward percentage of 80%
        vm.startPrank(builder);
        builderRegistry.unpauseSelf(0.8 ether);
        (_previous, _next, _cooldownEndTime) = builderRegistry.backerRewardPercentage(builder);
        // THEN previous backer reward percentage is 50%
        assertEq(_previous, 0.5 ether);
        // THEN next backer reward percentage is 80%
        assertEq(_next, 0.8 ether);
        // THEN backer reward percentage cooldown finished
        assertLe(_cooldownEndTime, block.timestamp);
        // THEN backer reward percentage to apply is 80%
        assertEq(builderRegistry.getRewardPercentageToApply(builder), 0.8 ether);
    }
}
