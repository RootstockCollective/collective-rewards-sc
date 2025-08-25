// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";

contract CommunityBanBuilderTest is HaltedBuilderBehavior {
    function _initialState() internal override {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        _initialDistribution();

        // AND builder is community banned
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);
    }

    function _haltGauge() internal override {
        // AND builder is community banned
        vm.prank(governor);
        builderRegistry.communityBanBuilder(builder);
    }

    /**
     * SCENARIO: builder is community banned in the middle of an cycle having allocation.
     *  builder receives all the rewards for the current cycle
     */
    function test_BuildersReceiveCurrentRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is community banned
        _initialState();

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder), 6.25 ether);
        // THEN builder usdrifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder), 6.25 ether);
        // THEN builder native tokens balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rifToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver usdrifToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver native tokens balance is 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 4.375 ether);
    }

    /**
     * SCENARIO: builder is community banned in the middle of an cycle having allocation.
     *  Builder doesn't receive those rewards on the next cycle
     */
    function test_BuilderDoesNotReceiveNextRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is community banned
        _initialState();
        // AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        _distribute(100 ether, 100 ether, 10 ether);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN builder rifToken balance is the same. It didn't receive rewards
        assertEq(rifToken.balanceOf(builder), 6.25 ether);
        // THEN builder usdrifToken balance is the same. It didn't receive rewards
        assertEq(usdrifToken.balanceOf(builder), 6.25 ether);
        // THEN builder native tokens balance is the same. It didn't receive rewards
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rifToken balance is 43.75 + 50. All the rewards are to him
        assertEq(rifToken.balanceOf(builder2Receiver), 93.75 ether);
        // THEN builder2Receiver usdrifToken balance is 43.75 + 50. All the rewards are to him
        assertEq(usdrifToken.balanceOf(builder2Receiver), 93.75 ether);
        // THEN builder2Receiver native tokens balance is 43.75 + 50. All the rewards are to him
        assertEq(builder2Receiver.balance, 9.375 ether);
    }
}
