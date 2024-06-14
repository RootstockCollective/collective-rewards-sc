// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { BaseTest } from "./BaseTest.sol";

contract VoterTest is BaseTest {
    event Voted(address indexed voter, address indexed builder, uint256 totalWeight, uint256 timestamp);

    event DistributeReward(address indexed sender, address indexed gauge, uint256 amount);

    function test_Vote() public {
        address[] memory builderVote = new address[](2);
        builderVote[0] = address(builders[0]);
        builderVote[1] = address(builders[1]);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1 ether;
        weights[1] = 2 ether;

        uint256 totalWeight = getTotalWeight(builderVote, weights);
        erc20Utils.mintToken(address(builderToken), alice, totalWeight);

        vm.startPrank(alice);
        builderToken.approve(address(voter), totalWeight);
        vm.expectEmit();
        emit Voted(address(alice), address(builders[0]), weights[0], block.timestamp);
        vm.expectEmit();
        emit Voted(address(alice), address(builders[1]), weights[1], block.timestamp);
        voter.vote(builderVote, weights);
        vm.stopPrank();

        assertEq(voter.lastVoted(alice), block.timestamp);
        assertEq(voter.totalWeight(), totalWeight);
        assertEq(gauges[0].totalSupply(), weights[0]);
        assertEq(gauges[1].totalSupply(), weights[1]);
        assertEq(gauges[0].balanceOf(alice), weights[0]);
        assertEq(gauges[1].balanceOf(alice), weights[1]);
        assertEq(voter.builderVote(alice, 0), address(builders[0]));
        assertEq(voter.builderVote(alice, 1), address(builders[1]));
        assertEq(builderToken.balanceOf(alice), 0);

        erc20Utils.mintToken(address(builderToken), bob, totalWeight);

        vm.startPrank(bob);
        builderToken.approve(address(voter), totalWeight);
        vm.expectEmit();
        emit Voted(address(bob), address(builders[0]), weights[0], block.timestamp);
        vm.expectEmit();
        emit Voted(address(bob), address(builders[1]), weights[1], block.timestamp);
        voter.vote(builderVote, weights);
        vm.stopPrank();

        assertEq(voter.lastVoted(bob), block.timestamp);
        assertEq(voter.totalWeight(), totalWeight * 2);
        assertEq(gauges[0].totalSupply(), weights[0] * 2);
        assertEq(gauges[1].totalSupply(), weights[1] * 2);
        assertEq(gauges[0].balanceOf(bob), weights[0]);
        assertEq(gauges[1].balanceOf(bob), weights[1]);
        assertEq(voter.builderVote(bob, 0), address(builders[0]));
        assertEq(voter.builderVote(bob, 1), address(builders[1]));
        assertEq(builderToken.balanceOf(bob), 0);
    }

    function test_Distribute() public {
        address[] memory builderVote = new address[](2);
        builderVote[0] = address(builders[0]);
        builderVote[1] = address(builders[1]);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1 ether;
        weights[1] = 1 ether;

        uint256 totalWeight = getTotalWeight(builderVote, weights);

        erc20Utils.mintToken(address(builderToken), alice, totalWeight);

        vm.startPrank(alice);
        builderToken.approve(address(voter), totalWeight);
        voter.vote(builderVote, weights);
        vm.stopPrank();

        erc20Utils.mintToken(address(rewardToken), voter.minter(), 100 ether);
        rewardToken.approve(address(voter), 100 ether);
        voter.notifyRewardAmount(100 ether);

        vm.expectEmit();
        emit DistributeReward(address(this), address(gauges[0]), 50 ether);
        vm.expectEmit();
        emit DistributeReward(address(this), address(gauges[1]), 50 ether);
        voter.distribute(0, 2);

        assertEq(rewardToken.balanceOf(address(gauges[0])), 50 ether);
        assertEq(rewardToken.balanceOf(address(gauges[1])), 50 ether);
        assertEq(rewardToken.balanceOf(address(voter)), 0);
    }

    function test_Distribute2x() public {
        address[] memory builderVote = new address[](2);
        builderVote[0] = address(builders[0]);
        builderVote[1] = address(builders[1]);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1 ether;
        weights[1] = 1 ether;
        uint256 totalWeight = getTotalWeight(builderVote, weights);

        erc20Utils.mintToken(address(builderToken), alice, totalWeight);
        vm.startPrank(alice);
        builderToken.approve(address(voter), totalWeight);
        voter.vote(builderVote, weights);
        vm.stopPrank();

        erc20Utils.mintToken(address(builderToken), bob, totalWeight);
        vm.startPrank(bob);
        builderToken.approve(address(voter), totalWeight);
        voter.vote(builderVote, weights);
        vm.stopPrank();

        erc20Utils.mintToken(address(rewardToken), voter.minter(), 200 ether);
        rewardToken.approve(address(voter), 100 ether);
        voter.notifyRewardAmount(100 ether);

        rewardToken.approve(address(voter), 100 ether);
        voter.notifyRewardAmount(100 ether);

        voter.distribute(0, 2);
    }

    function test_CannotVoteIfUnequalLengths() public { }

    function test_CannotVoteIfTooManyPools() public { }

    function test_CannotVoteIfNotEnoughVotingPower() public { }

    function test_CannotVoteIfGaugeNotAlive() public { }

    function test_CannotVoteIfZeroBalance() public { }

    function getTotalWeight(address[] memory _builderVote, uint256[] memory _weights) internal pure returns (uint256) {
        uint256 _builderCnt = _builderVote.length;
        uint256 _totalWeight = 0;

        for (uint256 i = 0; i < _builderCnt; i++) {
            _totalWeight += _weights[i];
        }

        return _totalWeight;
    }
}
