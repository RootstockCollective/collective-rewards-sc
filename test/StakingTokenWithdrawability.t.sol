// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, StakingTokenMock } from "./BaseTest.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract StakingTokenWithdrawabilityTest is BaseTest {
    function _setUp() internal override {
        stakingToken.setCollectiveRewardsAddress(address(backersManager));
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        _initialDistribution();

        assertEq(stakingToken.balanceOf(alice), 100_000 ether);
        assertEq(backersManager.backerTotalAllocation(alice), 8 ether);
        assertEq(stakingToken.balanceOf(bob), 100_000 ether);
        assertEq(backersManager.backerTotalAllocation(bob), 8 ether);
    }

    /**
     * SCENARIO: canWithdraw should return true if staker has no allocations
     */
    function test_NoBackerCanWithdrawAlwaysTrue(uint256 value_) public view {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        //  THEN addresses with no allocation can withdraw anything
        assertEq(backersManager.canWithdraw(address(0), value_), true);
        assertEq(backersManager.canWithdraw(address(1), value_), true);
    }

    /**
     * SCENARIO: canWithdraw should return true if user balance is bigger than allocation
     */
    function test_CanWithdrawNoAllocatedAmount(uint256 value_) public view {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        assertEq(backersManager.canWithdraw(alice, value_), true);
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
        assertEq(backersManager.backerTotalAllocation(alice), 8 ether);
        // THEN bob allocation is still 8
        assertEq(backersManager.backerTotalAllocation(bob), 8 ether);
    }

    /**
     * SCENARIO: alice has 100000 stakingToken and 8 allocated, revert trying to transfer 99993 tokens
     * with custom STRIFStakedInCollectiveRewardsCanWithdraw error
     */
    function test_RevertWithdraw() public {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        // WHEN alice tries to transfer 99993 tokens to bob
        //  THEN tx reverts because amount exceeds the tokens allocated
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(StakingTokenMock.STRIFStakedInCollectiveRewardsCanWithdraw.selector, false)
        );
        stakingToken.transfer(bob, 99_993 ether);
    }

    /**
     * SCENARIO: alice has 100000 stakingToken and 8 allocated, revert trying to transfer 100001 tokens
     * with default ERC20InsufficientBalance error
     */
    function test_RevertWithdrawWithInsufficietBalance() public {
        // GIVEN alice and bob have 100000 stakingToken and 8 allocated
        // WHEN alice tries to transfer 100001 tokens to bob
        //  THEN tx reverts because amount exceeds the tokens allocated
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(alice), 100_000 ether, 100_001 ether
            )
        );
        stakingToken.transfer(bob, 100_001 ether);
    }
}
