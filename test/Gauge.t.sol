// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { IGauge } from "../src/interfaces/gauges/IGauge.sol";
import { TimeLibrary } from "../src/libraries/TimeLibrary.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GaugeTest is BaseTest {
    event Deposit(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed from, uint256 amount);
    event NotifyReward(address indexed from, uint256 amount);
    event ClaimRewards(address indexed from, uint256 amount);

    IGauge internal gauge;
    uint256 internal constant PRECISION = 10 ** 18;

    function _setUp() public override {
        gauge = gauges[0];
        skip(TimeLibrary.epochNext(block.timestamp) - 1);
    }

    function test_Deposit() public {
        uint256 _depositAmount = 1 ether;

        _deposit(_depositAmount, alice);

        uint256 _epoch = TimeLibrary.epochStart(block.timestamp);

        assertEq(gauge.balanceOf(alice), _depositAmount);
        assertEq(gauge.totalSupplyByEpoch(_epoch), _depositAmount);
    }

    function test_Withdraw() public {
        uint256 _withdrawAmount = 1 ether;

        _deposit(_withdrawAmount, alice);

        _withdraw(_withdrawAmount, alice);

        uint256 _epoch = TimeLibrary.epochStart(block.timestamp);

        assertEq(gauge.balanceOf(alice), 0);
        assertEq(gauge.totalSupplyByEpoch(_epoch), 0);
    }

    function test_NotifyRewardAmount() public {
        uint256 _rewardAmount = 100 ether;
        uint256 _depositAmount = 1 ether;

        _deposit(_depositAmount, alice);

        uint256 _timestamp = block.timestamp;
        uint256 _timeUntilNext = TimeLibrary.epochNext(_timestamp) - _timestamp;
        uint256 _rewardRate = _rewardAmount / _timeUntilNext;

        _notifyRewardAmount(_rewardAmount);

        assertEq(rewardToken.balanceOf(address(gauge)), _rewardAmount);
        assertEq(gauge.rewardPerTokenStored(), 0);
        assertEq(gauge.rewardRate(), _rewardRate);
        assertEq(gauge.lastUpdateTime(), _timestamp);
        assertEq(gauge.periodFinish(), _timestamp + _timeUntilNext);

        skip(1 weeks);

        uint256 _newTimestamp = block.timestamp;
        uint256 _newTimeUntilNext = TimeLibrary.epochNext(_newTimestamp) - _newTimestamp;
        uint256 _rewardPerTokenStored = (_timeUntilNext * _rewardRate * 10 ** 18) / _depositAmount;

        _notifyRewardAmount(_rewardAmount);

        assertEq(rewardToken.balanceOf(address(gauge)), _rewardAmount * 2);
        assertEq(gauge.rewardPerTokenStored(), _rewardPerTokenStored);
        assertEq(gauge.rewardRate(), _rewardRate);
        assertEq(gauge.lastUpdateTime(), _newTimestamp);
        assertEq(gauge.periodFinish(), _newTimestamp + _newTimeUntilNext);
    }

    function test_StuckReward() public {
        uint256 _rewardAmount = 100 ether;
        uint256 _depositAmount = 1 ether;

        _notifyRewardAmount(_rewardAmount);
        _deposit(_depositAmount, alice);

        skip(1 weeks / 2);

        _withdraw(_depositAmount, alice);
        vm.prank(alice);
        gauge.getReward(alice);

        skip(1 weeks / 2);

        assertEq(rewardToken.balanceOf(address(gauge)), _rewardAmount - rewardToken.balanceOf(address(alice)));

        _deposit(_depositAmount, bob);
        _notifyRewardAmount(_rewardAmount);

        skip(1 weeks);

        _withdraw(_depositAmount, bob);
        vm.prank(bob);
        gauge.getReward(bob);

        assertApproxEqRel(
            rewardToken.balanceOf(address(gauge)), _rewardAmount - rewardToken.balanceOf(address(alice)), 1e6
        );
    }

    function test_GetRewardOneDepositor() public {
        uint256 _rewardAmount = 100 ether;
        uint256 _depositAmount = 5 ether;

        _notifyRewardAmount(_rewardAmount);
        _deposit(_depositAmount, alice);

        skip(1 weeks);

        uint256 _earned = _claimRewards(alice);

        assertEq(rewardToken.balanceOf(alice), _earned);
        assertApproxEqRel(rewardToken.balanceOf(alice), _rewardAmount, 1e6);
        assertEq(gauge.earned(alice), 0);
    }

    function test_GetRewardMultipleDepositors() public {
        uint256 _rewardAmount = 10 ether;
        uint256 _depositAmount = 5 ether;

        _notifyRewardAmount(_rewardAmount);
        _deposit(_depositAmount, alice);

        skip(1 weeks / 2);

        uint256 _earned = _claimRewards(alice);

        assertEq(rewardToken.balanceOf(alice), _earned);
        assertApproxEqRel(rewardToken.balanceOf(alice), _rewardAmount / 2, 1e6);
        assertEq(gauge.earned(alice), 0);

        _deposit(_depositAmount, bob);

        skip(1 weeks / 2);

        uint256 _aliceEarned = _claimRewards(alice);
        uint256 _bobEarned = _claimRewards(bob);

        assertEq(rewardToken.balanceOf(alice), _earned + _aliceEarned);
        assertEq(rewardToken.balanceOf(bob), _bobEarned);
        assertApproxEqRel(rewardToken.balanceOf(alice), _rewardAmount * 3 / 4, 1e6);
        assertApproxEqRel(rewardToken.balanceOf(bob), _rewardAmount / 4, 1e6);
        assertEq(gauge.earned(alice), 0);
        assertEq(gauge.earned(bob), 0);
    }

    function test_Earned() public {
        uint256 _rewardAmount = 10 ether;
        uint256 _depositAmount = 5 ether;

        _notifyRewardAmount(_rewardAmount);
        _deposit(_depositAmount, alice);

        skip(1 days);

        assertApproxEqRel(gauge.earned(alice), _rewardAmount / 7, 1e6);
    }

    function test_Left() public {
        uint256 _rewardAmount = 10 ether;
        uint256 _depositAmount = 5 ether;

        _notifyRewardAmount(_rewardAmount);
        _deposit(_depositAmount, alice);

        skip(1 days);

        assertApproxEqRel(gauge.left(), _rewardAmount * 6 / 7, 1e6);
    }

    function test_RewardPerToken() public {
        uint256 _rewardAmount = 10 ether;
        _notifyRewardAmount(_rewardAmount);

        uint256 _depositAmount = 5 ether;
        _deposit(_depositAmount, alice);

        assertEq(gauge.rewardPerToken(), 0);

        uint256 _initialTimestamp = block.timestamp;
        skip(1 weeks);

        uint256 _finalTimestamp = block.timestamp;
        uint256 _rewardRate = _rewardAmount / 1 weeks;

        uint256 _rewardPerToken = ((_finalTimestamp - _initialTimestamp) * _rewardRate * PRECISION) / _depositAmount;

        assertEq(gauge.rewardPerToken(), _rewardPerToken);
        assertApproxEqRel(gauge.earned(alice), _rewardAmount, 1e6);
    }

    function test_RewardPerTokenLateHalfStaking() public {
        uint256 _rewardAmount = 10 ether;
        _notifyRewardAmount(_rewardAmount);

        assertEq(gauge.rewardPerToken(), 0);

        skip(1 weeks / 2);

        uint256 _initialTimestamp = block.timestamp;

        uint256 _depositAmount = 5 ether;
        _deposit(_depositAmount, alice);

        skip(1 weeks / 2);

        uint256 _finalTimestamp = block.timestamp;
        uint256 _rewardRate = _rewardAmount / 1 weeks;

        uint256 _rewardPerToken = ((_finalTimestamp - _initialTimestamp) * _rewardRate * PRECISION) / _depositAmount;

        assertEq(gauge.rewardPerToken(), _rewardPerToken);
        assertApproxEqRel(gauge.earned(alice), _rewardAmount / 2, 1e6);
    }

    function test_RewardPerTokenEarlyHalfStaking() public {
        uint256 _rewardAmount = 10 ether;
        _notifyRewardAmount(_rewardAmount);

        uint256 _depositAmount = 5 ether;
        _deposit(_depositAmount, alice);

        assertEq(gauge.rewardPerToken(), 0);

        skip(1 weeks / 2);

        uint256 _initialTimestamp = block.timestamp;

        _withdraw(_depositAmount, alice);

        skip(1 weeks / 2);

        uint256 _finalTimestamp = block.timestamp;
        uint256 _rewardRate = _rewardAmount / 1 weeks;

        uint256 _finalRewardPerToken =
            ((_finalTimestamp - _initialTimestamp) * _rewardRate * PRECISION) / _depositAmount;

        assertEq(gauge.rewardPerToken(), _finalRewardPerToken);
        assertApproxEqRel(gauge.earned(alice), _rewardAmount / 2, 1e6);
    }

    function test_LastTimeRewardApplicable() public {
        assertEq(gauge.lastTimeRewardApplicable(), 0);

        uint256 _periodFinish = block.timestamp + 1 weeks;

        uint256 _rewardAmount = 10 ether;
        _notifyRewardAmount(_rewardAmount);

        skip(1 weeks / 2);

        uint256 timestamp = block.timestamp;

        assertEq(gauge.lastTimeRewardApplicable(), timestamp);

        skip(1 weeks);

        assertEq(gauge.lastTimeRewardApplicable(), _periodFinish);
    }

    function _claimRewards(address _recipient) internal returns (uint256 _earned) {
        _earned = gauge.earned(_recipient);

        vm.expectEmit();
        emit ClaimRewards(address(_recipient), _earned);
        vm.prank(_recipient);
        gauge.getReward(_recipient);

        return _earned;
    }

    function _withdraw(uint256 _amount, address _recipient) internal {
        vm.startPrank(address(voter));
        vm.expectEmit();
        emit Withdraw(_recipient, _amount);
        gauge.withdraw(_amount, _recipient);
        vm.stopPrank();
    }

    function _deposit(uint256 _amount, address _recipient) private {
        vm.startPrank(address(voter));
        vm.expectEmit();
        emit Deposit(address(voter), _recipient, _amount);
        gauge.deposit(_amount, _recipient);
        vm.stopPrank();
    }

    function _notifyRewardAmount(uint256 _rewardAmount) internal {
        erc20Utils.mintToken(address(rewardToken), address(voter), _rewardAmount);
        vm.startPrank(address(voter));
        rewardToken.approve(address(gauge), _rewardAmount);
        vm.expectEmit();
        emit NotifyReward(address(voter), _rewardAmount);
        gauge.notifyRewardAmount(_rewardAmount);
        vm.stopPrank();
    }
}
