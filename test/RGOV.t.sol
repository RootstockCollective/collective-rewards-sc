// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Base, RGOV } from "./utils/Base.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract RGOVTest is Base {
    /// @dev A function invoked before each test case is run.
    function setUp() public override {
        super.setUp();
        _stake(alice, 10 ether);
        _stake(bob, 10 ether);
        vm.prank(alice);
        voter.increaseVotes(aliceProposals, aliceVotes);
        assertEq(voter.getStakerAllocation(alice), 6 ether);
    }

    function testTransferLessThanAllocation() public {
        vm.prank(alice);
        rgovToken.transfer(bob, 4 ether);

        assertEq(rgovToken.balanceOf(alice), 6 ether);
        assertEq(rgovToken.balanceOf(bob), 14 ether);
    }

    function testCannotTransferMoreThanAllocation() public {
        vm.prank(alice);
        vm.expectRevert(RGOV.TokensUsedToVote.selector);
        rgovToken.transfer(bob, 5 ether);
    }

    function testCannotTransferMoreThanBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 10 ether, 11 ether)
        );
        rgovToken.transfer(bob, 11 ether);
    }

    function testCannotUnstakeMoreThanAllocation() public {
        vm.startPrank(alice);
        rgovToken.approve(address(staking), 5 ether);

        vm.expectRevert(RGOV.TokensUsedToVote.selector);
        staking.unstake(5 ether);
    }

    function testCannotUnstakeMoreThanBalance() public {
        vm.startPrank(alice);
        rgovToken.approve(address(staking), 11 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 10 ether, 11 ether)
        );
        staking.unstake(11 ether);
    }
}
