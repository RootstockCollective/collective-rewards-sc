// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, StakingTokenMock } from "./BaseTest.sol";

contract StakingTokenWithdrawabilityTest is BaseTest {
    function _setUp() internal override {
        stakingToken.setCollectiveRewardsAddress(address(sponsorsManager));
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();

        assertEq(stakingToken.balanceOf(alice), 100_000 ether);
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 8 ether);
        assertEq(stakingToken.balanceOf(bob), 100_000 ether);
        assertEq(sponsorsManager.sponsorTotalAllocation(bob), 8 ether);
    }

    /**
     * SCENARIO: canWithdraw should return true if staker has no allocations
     */
    function test_NoSponsorCanWithdrawAlwaysTrue() public view {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        //  THEN addresses with no allocation can withdraw anything
        assertEq(sponsorsManager.canWithdraw(address(0), 1_000_000 ether), true);
        assertEq(sponsorsManager.canWithdraw(address(1), 1_000_000 ether), true);
    }

    /**
     * SCENARIO: canWithdraw should return true for values not allocated
     */
    function test_CanWithdrawNoAllocatedAmount() public view {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        // THEN alice can withdraw 99992
        assertEq(sponsorsManager.canWithdraw(alice, 99_992 ether), true);
        // THEN alice cannot withdraw 99993
        assertEq(sponsorsManager.canWithdraw(alice, 99_993 ether), false);
    }

    /**
     * SCENARIO: canWithdraw should return false is value is greater than the balance
     */
    function test_CanWithdrawNoEnoughBalance() public view {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        // THEN alice cannot withdraw 100001
        assertEq(sponsorsManager.canWithdraw(alice, 100_001 ether), false);
    }

    /**
     * SCENARIO: alice has 100000 stakingToken and 8 allocated, she can transfer 99992 tokens
     */
    function test_WithdrawAll() public {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        // WHEN alice transfers 99992 tokens to bob
        vm.prank(alice);
        stakingToken.transfer(bob, 99_992 ether);

        // THEN alice stakingToken balance is 8
        assertEq(stakingToken.balanceOf(alice), 8 ether);
        // THEN bob stakingToken balance is 199_992
        assertEq(stakingToken.balanceOf(bob), 199_992 ether);
        // THEN alice allocation is still 8
        assertEq(sponsorsManager.sponsorTotalAllocation(alice), 8 ether);
        // THEN bob allocation is still 8
        assertEq(sponsorsManager.sponsorTotalAllocation(bob), 8 ether);
    }

    /**
     * SCENARIO: alice has 100000 stakingToken and 8 allocated, revert trying to transfer 99993 tokens
     */
    function test_RevertWithdraw() public {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        // WHEN alice transfers 99993 tokens to bob
        //  THEN tx reverts because amount exceeds the tokens allocated
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(StakingTokenMock.STRIFStakedInCollectiveRewardsCanWithdraw.selector, false)
        );
        stakingToken.transfer(bob, 99_993 ether);
    }
}
