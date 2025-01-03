// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";

contract DewhitelistBuilderTest is HaltedBuilderBehavior {
    function _initialState() internal override {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        _initialDistribution();

        // AND builder is dewhitelisted
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);
    }

    function _haltGauge() internal override {
        // AND builder is dewhitelisted
        vm.prank(governor);
        builderRegistry.dewhitelistBuilder(builder);
    }

    /**
     * SCENARIO: builder is dewhitelisted in the middle of an cycle having allocation.
     *  builder receives all the rewards for the current cycle
     */
    function test_BuildersReceiveCurrentRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is dewhitelisted
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
     * SCENARIO: builder is dewhitelisted in the middle of an cycle having allocation.
     *  Builder doesn't receive those rewards on the next cycle
     */
    function test_BuilderDoesNotReceiveNextRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is dewhitelisted
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
}
