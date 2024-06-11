// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Base } from "./utils/Base.sol";

contract StakingTest is Base {
    function testStaking() public {
        _stake(alice, 10 ether);
        assertEq(rifToken.balanceOf(alice), 90 ether);
        assertEq(rgovToken.balanceOf(alice), 10 ether);
    }

    function testUnstaking() public {
        _stake(alice, 10 ether);
        _unstake(alice, 10 ether);
        assertEq(rifToken.balanceOf(alice), 100 ether);
        assertEq(rgovToken.balanceOf(alice), 0 ether);
    }
}
