// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Base } from "./utils/Base.sol";

contract VoterTest is Base {
    function testGetEpochNumber() public {
        assertEq(voter.getCurrentEpochNumber(), 1);
        _skipToEpoch(500);
        assertEq(voter.getCurrentEpochNumber(), 500);
    }

    function testIncreaseVotesOneStaker() public {
        // alice votes on epoch 1
        _stake(alice, 10 ether);
        uint256 epochOne = 1;
        vm.prank(alice);
        voter.increaseVotes(aliceProposals, aliceVotes);

        assertEq(voter.totalVotes(epochOne), 6 ether);
        assertEq(voter.stakerVotesUsed(epochOne, alice), 6 ether);
        assertEq(voter.proposalVotes(epochOne, proposals[0]), 2 ether);
        assertEq(voter.proposalVotes(epochOne, proposals[1]), 4 ether);
        assertEq(voter.stakerProposalsVoted(epochOne, alice, proposals[0]), 2 ether);
        assertEq(voter.stakerProposalsVoted(epochOne, alice, proposals[1]), 4 ether);
        assertEq(voter.getProposalVotingPct(epochOne, proposals[0]), 333_333_333_333_333_333); // 0.33%
        assertEq(voter.getProposalVotingPct(epochOne, proposals[1]), 666_666_666_666_666_666); // 0.66%
        assertEq(voter.getStakerRewardPct(epochOne, alice, proposals[0]), 1_000_000_000_000_000_000); // 100%
        assertEq(voter.getStakerRewardPct(epochOne, alice, proposals[1]), 1_000_000_000_000_000_000); // 100%

        // alice duplicates votes on epoch 10
        _stake(alice, 10 ether);
        uint256 epochTen = 10;
        _skipToEpoch(epochTen);
        vm.prank(alice);
        voter.increaseVotes(aliceProposals, aliceVotes);

        assertEq(voter.totalVotes(epochTen), 12 ether);
        assertEq(voter.stakerVotesUsed(epochTen, alice), 12 ether);
        assertEq(voter.proposalVotes(epochTen, proposals[0]), 4 ether);
        assertEq(voter.proposalVotes(epochTen, proposals[1]), 8 ether);
        assertEq(voter.stakerProposalsVoted(epochTen, alice, proposals[0]), 4 ether);
        assertEq(voter.stakerProposalsVoted(epochTen, alice, proposals[1]), 8 ether);
        assertEq(voter.getProposalVotingPct(epochOne, proposals[0]), 333_333_333_333_333_333); // 0.33%
        assertEq(voter.getProposalVotingPct(epochOne, proposals[1]), 666_666_666_666_666_666); // 0.66%
        assertEq(voter.getStakerRewardPct(epochOne, alice, proposals[0]), 1_000_000_000_000_000_000); // 100%
        assertEq(voter.getStakerRewardPct(epochOne, alice, proposals[1]), 1_000_000_000_000_000_000); // 100%
    }

    function testIncreaseVotesTwoStakers() public {
        // alice and bob vote on epoch 1
        _stake(alice, 10 ether);
        _stake(bob, 10 ether);
        uint256 epochOne = 1;
        vm.prank(alice);
        voter.increaseVotes(aliceProposals, aliceVotes);
        vm.prank(bob);
        voter.increaseVotes(bobProposals, bobVotes);

        assertEq(voter.totalVotes(epochOne), 16 ether);

        assertEq(voter.stakerVotesUsed(epochOne, alice), 6 ether);
        assertEq(voter.stakerVotesUsed(epochOne, bob), 10 ether);

        assertEq(voter.proposalVotes(epochOne, proposals[0]), 6 ether);
        assertEq(voter.proposalVotes(epochOne, proposals[1]), 4 ether);
        assertEq(voter.proposalVotes(epochOne, proposals[2]), 6 ether);

        assertEq(voter.stakerProposalsVoted(epochOne, alice, proposals[0]), 2 ether);
        assertEq(voter.stakerProposalsVoted(epochOne, alice, proposals[1]), 4 ether);
        assertEq(voter.stakerProposalsVoted(epochOne, alice, proposals[2]), 0 ether);

        assertEq(voter.stakerProposalsVoted(epochOne, bob, proposals[0]), 4 ether);
        assertEq(voter.stakerProposalsVoted(epochOne, bob, proposals[1]), 0 ether);
        assertEq(voter.stakerProposalsVoted(epochOne, bob, proposals[2]), 6 ether);

        assertEq(voter.getProposalVotingPct(epochOne, proposals[0]), 375_000_000_000_000_000); // 0.375%
        assertEq(voter.getProposalVotingPct(epochOne, proposals[1]), 250_000_000_000_000_000); // 0.25%
        assertEq(voter.getProposalVotingPct(epochOne, proposals[2]), 375_000_000_000_000_000); // 0.375%

        assertEq(voter.getStakerRewardPct(epochOne, alice, proposals[0]), 333_333_333_333_333_333); // 0.33%
        assertEq(voter.getStakerRewardPct(epochOne, alice, proposals[1]), 1_000_000_000_000_000_000); // 100%
        assertEq(voter.getStakerRewardPct(epochOne, alice, proposals[2]), 0); // 0%

        assertEq(voter.getStakerRewardPct(epochOne, bob, proposals[0]), 666_666_666_666_666_666); // 0.66%
        assertEq(voter.getStakerRewardPct(epochOne, bob, proposals[1]), 0); // 0%
        assertEq(voter.getStakerRewardPct(epochOne, bob, proposals[2]), 1_000_000_000_000_000_000); // 100%
    }

    function test1000EpochsWithoutVotes() public {
        // alice votes on epoch 1
        _stake(alice, 10 ether);
        vm.prank(alice);
        voter.increaseVotes(aliceProposals, aliceVotes);

        // alice add votes on epoch 1001
        _stake(alice, 10 ether);
        _skipToEpoch(1001);
        vm.prank(alice);
        uint256[] memory newVotes = bobVotes; // use different votes to see the changes on epoch 1001
        voter.increaseVotes(aliceProposals, newVotes);

        assertEq(voter.getProposalVotingPct(1000, proposals[0]), 333_333_333_333_333_333); // 0.33%
        assertEq(voter.getProposalVotingPct(1000, proposals[1]), 666_666_666_666_666_666); // 0.66%
        assertEq(voter.getStakerRewardPct(1000, alice, proposals[0]), 1_000_000_000_000_000_000); // 100%
        assertEq(voter.getStakerRewardPct(1000, alice, proposals[1]), 1_000_000_000_000_000_000); // 100%

        assertEq(voter.getProposalVotingPct(1001, proposals[0]), 375_000_000_000_000_000); // 0.375%
        assertEq(voter.getProposalVotingPct(1001, proposals[1]), 625_000_000_000_000_000); // 0.625%
        assertEq(voter.getStakerRewardPct(1001, alice, proposals[0]), 1_000_000_000_000_000_000); // 100%
        assertEq(voter.getStakerRewardPct(1001, alice, proposals[1]), 1_000_000_000_000_000_000); // 100%
    }
}
