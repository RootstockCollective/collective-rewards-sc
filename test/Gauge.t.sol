// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { IGauge } from "../src/interfaces/gauges/IGauge.sol";
import { TimeLibrary } from "../src/libraries/TimeLibrary.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 } from "forge-std/src/console2.sol";

contract GaugeTest is BaseTest {
    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed from, uint256 amount);
    event NotifyReward(address indexed from, uint256 amount);

    IGauge internal gauge;

    function _setUp() public override {
        gauge = gauges[0];
    }

    function test_Deposit() public {
        uint256 _depositAmount = 1 ether;

        _deposit(_depositAmount, alice);

        uint256 _epoch = TimeLibrary.epochStart(block.timestamp);

        assertEq(gauge.balanceOf(alice), _depositAmount);
        assertEq(IERC20(gauge.stakingToken()).balanceOf(address(gauge)), _depositAmount);
        assertEq(gauge.totalSupplyByEpoch(_epoch), _depositAmount);
    }

    function test_Withdraw() public {
        uint256 _withdrawAmount = 1 ether;

        _deposit(_withdrawAmount, alice);

        vm.startPrank(address(voter));
        vm.expectEmit();
        emit Withdraw(alice, _withdrawAmount);
        gauge.withdraw(_withdrawAmount, alice);
        vm.stopPrank();

        uint256 _epoch = TimeLibrary.epochStart(block.timestamp);

        assertEq(gauge.balanceOf(alice), 0);
        assertEq(IERC20(gauge.stakingToken()).balanceOf(address(gauge)), 0);
        assertEq(gauge.totalSupplyByEpoch(_epoch), 0);
        assertEq(IERC20(gauge.stakingToken()).balanceOf(alice), _withdrawAmount);
    }

    function test_NotifyRewardAmount() public {
        uint256 _rewardAmount = 100 ether;
        erc20Utils.mintToken(address(rewardToken), address(voter), _rewardAmount);

        vm.startPrank(address(voter));
        rewardToken.approve(address(gauge), _rewardAmount);
        vm.expectEmit();
        emit NotifyReward(address(voter), _rewardAmount);
        gauge.notifyRewardAmount(_rewardAmount);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(address(gauge)), _rewardAmount);
    }

    function _deposit(uint256 _amount, address recipient) private {
        erc20Utils.mintToken(address(builderToken), address(voter), _amount);

        vm.startPrank(address(voter));
        vm.expectEmit();
        emit Deposit(address(voter), recipient, _amount);
        gauge.deposit(_amount, recipient);
        vm.stopPrank();
    }
}
