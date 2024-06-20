// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { IVoter } from "../src/interfaces/IVoter.sol";

contract VoterTest is BaseTest {
    event Voted(address indexed voter, address indexed builder, uint256 totalWeight, uint256 timestamp);

    event DistributeReward(address indexed sender, address indexed gauge, uint256 amount);

    event Abstained(address indexed voter, address indexed builder, uint256 totalWeight, uint256 timestamp);

    address[] builderVote;
    uint256[] weights;
    uint256 stakeAmount = 6 ether;

    function _setUp() public override {
        builderVote.push(address(builders[0]));
        builderVote.push(address(builders[1]));
        weights.push(1 ether);
        weights.push(2 ether);
    }

    function test_Vote() public {
        _vote(alice);
        assertEq(voter.lastVoted(alice), block.timestamp);
        assertEq(gauges[0].balanceOf(alice), weights[0]);
        assertEq(gauges[1].balanceOf(alice), weights[1]);
        assertEq(voter.voterBuilders(alice, 0), address(builders[0]));
        assertEq(voter.voterBuilders(alice, 1), address(builders[1]));
        assertTrue(voter.voterBuildersVoted(alice, builders[0]));
        assertTrue(voter.voterBuildersVoted(alice, builders[1]));
        assertEq(stakeToken.balanceOf(alice), stakeAmount);

        _vote(bob);
        assertEq(voter.lastVoted(bob), block.timestamp);
        assertEq(gauges[0].balanceOf(bob), weights[0]);
        assertEq(gauges[1].balanceOf(bob), weights[1]);
        assertEq(voter.voterBuilders(bob, 0), address(builders[0]));
        assertEq(voter.voterBuilders(bob, 1), address(builders[1]));
        assertTrue(voter.voterBuildersVoted(bob, builders[0]));
        assertTrue(voter.voterBuildersVoted(bob, builders[1]));
        assertEq(stakeToken.balanceOf(bob), stakeAmount);

        uint256 totalWeight = _getTotalWeight(builderVote, weights);

        assertEq(voter.totalWeight(), totalWeight * 2);
        assertEq(gauges[0].totalSupply(), weights[0] * 2);
        assertEq(gauges[1].totalSupply(), weights[1] * 2);
    }

    function test_Vote2x() public {
        _vote(alice);
        assertEq(voter.lastVoted(alice), block.timestamp);
        assertEq(gauges[0].balanceOf(alice), weights[0]);
        assertEq(gauges[1].balanceOf(alice), weights[1]);
        assertEq(voter.voterBuilders(alice, 0), address(builders[0]));
        assertEq(voter.voterBuilders(alice, 1), address(builders[1]));
        assertTrue(voter.voterBuildersVoted(alice, builders[0]));
        assertTrue(voter.voterBuildersVoted(alice, builders[1]));
        assertEq(stakeToken.balanceOf(alice), stakeAmount);

        skipAndRoll(1);

        _vote(alice);
        assertEq(voter.lastVoted(alice), block.timestamp);
        assertEq(gauges[0].balanceOf(alice), weights[0] * 2);
        assertEq(gauges[1].balanceOf(alice), weights[1] * 2);
        assertEq(voter.voterBuilders(alice, 0), address(builders[0]));
        assertEq(voter.voterBuilders(alice, 1), address(builders[1]));
        assertTrue(voter.voterBuildersVoted(alice, builders[0]));
        assertTrue(voter.voterBuildersVoted(alice, builders[1]));
        assertEq(stakeToken.balanceOf(alice), stakeAmount);

        uint256 _totalWeight = _getTotalWeight(builderVote, weights);

        assertEq(voter.totalWeight(), _totalWeight * 2);
        assertEq(gauges[0].totalSupply(), weights[0] * 2);
        assertEq(gauges[1].totalSupply(), weights[1] * 2);
    }

    function test_Distribute() public {
        weights[0] = 1 ether;
        weights[1] = 1 ether;

        _vote(alice);

        uint256 _amountToDistribute = 100 ether;
        erc20Utils.mintToken(address(rewardToken), voter.minter(), _amountToDistribute);
        rewardToken.approve(address(voter), _amountToDistribute);
        voter.notifyRewardAmount(_amountToDistribute);

        _distribute(_amountToDistribute, 1);
    }

    function test_Distribute2x() public {
        weights[0] = 1 ether;
        weights[1] = 1 ether;

        _vote(alice);
        _vote(bob);

        uint256 _amountToDistribute = 100 ether;
        erc20Utils.mintToken(address(rewardToken), voter.minter(), _amountToDistribute);
        rewardToken.approve(address(voter), _amountToDistribute);
        voter.notifyRewardAmount(_amountToDistribute);

        _distribute(_amountToDistribute, 1);

        erc20Utils.mintToken(address(rewardToken), voter.minter(), _amountToDistribute);
        rewardToken.approve(address(voter), _amountToDistribute);
        voter.notifyRewardAmount(_amountToDistribute);

        _distribute(_amountToDistribute, 2);
    }

    function test_Distribute2xReward() public {
        weights[0] = 1 ether;
        weights[1] = 1 ether;

        _vote(alice);
        _vote(bob);

        uint256 _amountToDistribute = 100 ether;
        erc20Utils.mintToken(address(rewardToken), voter.minter(), _amountToDistribute * 2);
        rewardToken.approve(address(voter), _amountToDistribute * 2);
        voter.notifyRewardAmount(_amountToDistribute);
        voter.notifyRewardAmount(_amountToDistribute);

        _distribute(_amountToDistribute * 2, 1);
    }

    function test_CannotVoteIfUnequalLengths() public {
        weights.push(2 ether);

        vm.startPrank(alice);
        vm.expectRevert(IVoter.UnequalLengths.selector);
        voter.vote(builderVote, weights);
        vm.stopPrank();
    }

    function test_CannotVoteIfNotEnoughVotingPower() public {
        vm.startPrank(alice);
        vm.expectRevert(IVoter.NotEnoughVotingPower.selector);
        voter.vote(builderVote, weights);
        vm.stopPrank();
    }

    function test_CannotVoteIfGaugeDoesNotExist() public {
        builderVote[0] = address(5);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVoter.GaugeDoesNotExist.selector, builderVote[0]));
        voter.vote(builderVote, weights);
        vm.stopPrank();
    }

    function test_CannotVoteIfGaugeNotAlive() public {
        vm.prank(voter.emergencyCouncil());
        voter.killGauge(address(gauges[0]));

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IVoter.GaugeNotAlive.selector, address(gauges[0])));
        voter.vote(builderVote, weights);
        vm.stopPrank();
    }

    function test_CannotVoteIfZeroBalance() public {
        weights[0] = 0;

        vm.startPrank(alice);
        vm.expectRevert(IVoter.ZeroBalance.selector);
        voter.vote(builderVote, weights);
        vm.stopPrank();
    }

    function test_Reset() public {
        _vote(alice);
        assertEq(voter.lastVoted(alice), block.timestamp);
        assertEq(gauges[0].balanceOf(alice), weights[0]);
        assertEq(gauges[1].balanceOf(alice), weights[1]);
        assertEq(voter.voterBuilders(alice, 0), address(builders[0]));
        assertEq(voter.voterBuilders(alice, 1), address(builders[1]));
        assertTrue(voter.voterBuildersVoted(alice, builders[0]));
        assertTrue(voter.voterBuildersVoted(alice, builders[1]));
        assertEq(stakeToken.balanceOf(alice), stakeAmount);

        vm.startPrank(alice);
        vm.expectEmit();
        emit Abstained(address(alice), address(builders[0]), weights[0], block.timestamp);
        vm.expectEmit();
        emit Abstained(address(alice), address(builders[1]), weights[1], block.timestamp);
        voter.reset();

        assertEq(gauges[0].balanceOf(alice), 0);
        assertEq(gauges[1].balanceOf(alice), 0);
        assertFalse(voter.voterBuildersVoted(alice, builders[0]));
        assertFalse(voter.voterBuildersVoted(alice, builders[1]));
        assertEq(stakeToken.balanceOf(alice), stakeAmount);
    }

    function _getTotalWeight(address[] memory _builderVote, uint256[] memory _weights) private pure returns (uint256) {
        uint256 _builderCnt = _builderVote.length;
        uint256 _totalWeight = 0;

        for (uint256 i = 0; i < _builderCnt; i++) {
            _totalWeight += _weights[i];
        }

        return _totalWeight;
    }

    function _vote(address _voterAddress) private {
        erc20Utils.mintToken(address(stakeToken), _voterAddress, stakeAmount);

        vm.startPrank(_voterAddress);
        vm.expectEmit();
        emit Voted(address(_voterAddress), address(builders[0]), weights[0], block.timestamp);
        vm.expectEmit();
        emit Voted(address(_voterAddress), address(builders[1]), weights[1], block.timestamp);
        voter.vote(builderVote, weights);
        vm.stopPrank();
    }

    function _distribute(uint256 _amountToDistribute, uint256 _factor) private {
        uint256 _totalWeight = _getTotalWeight(builderVote, weights);
        uint256 _adjustment = 1e18;
        uint256 _expectedAmountGauge0 = (_amountToDistribute * (weights[0] * _adjustment / _totalWeight)) / _adjustment;
        uint256 _expectedAmountGauge1 = (_amountToDistribute * (weights[1] * _adjustment / _totalWeight)) / _adjustment;

        vm.expectEmit();
        emit DistributeReward(address(this), address(gauges[0]), _expectedAmountGauge0);
        vm.expectEmit();
        emit DistributeReward(address(this), address(gauges[1]), _expectedAmountGauge1);
        voter.distribute(0, 2);

        assertEq(rewardToken.balanceOf(address(gauges[0])), _expectedAmountGauge0 * _factor);
        assertEq(rewardToken.balanceOf(address(gauges[1])), _expectedAmountGauge1 * _factor);
        assertEq(rewardToken.balanceOf(address(voter)), 0);
    }
}
