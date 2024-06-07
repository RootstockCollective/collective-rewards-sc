// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { RGOV } from "./RGOV.sol";

contract Voter {
    error TooManyProposals();
    error UnequalLengths();
    error InsufficientVotingPower();

    RGOV public rgovToken;

    // first epoch time stamp
    uint256 public immutable FIRST_EPOCH = block.timestamp;
    // epoch time duration
    uint256 public epochPeriod = 1 weeks;

    // max amount of proposal to votes in a batch due block gas limit
    uint256 public maxProposalsPerBatch = 10;

    // total amount of votes
    mapping(uint256 epoch => uint256 votes) public totalVotes;
    // amount of votes per proposal
    mapping(uint256 epoch => mapping(address proposal => uint256 votes)) public proposalVotes;
    // amount of votes per staker per proposal
    mapping(uint256 epoch => mapping(address staker => mapping(address proposal => uint256 votes))) public
        stakerProposalsVoted;
    // amount of votes per staker
    mapping(uint256 epoch => mapping(address staker => uint256 votesUsed)) public stakerVotesUsed;
    // last epoch where a staker voted
    mapping(address staker => uint256 epoch) public stakerLastEpochVoted;

    constructor(RGOV rgovToken_) {
        rgovToken = rgovToken_;
    }

    function increaseVotes(address[] memory proposals_, uint256[] memory votes_) external {
        _increaseVotes(msg.sender, proposals_, votes_);
    }

    function decreaseVotes(address[] memory proposals_, uint256[] memory votes_) external {
        _decreaseVotes(msg.sender, proposals_, votes_);
    }

    function _increaseVotes(address staker_, address[] memory proposals_, uint256[] memory votes_) internal {
        uint256 length = proposals_.length;
        if (length > maxProposalsPerBatch) revert TooManyProposals();
        if (length != votes_.length) revert UnequalLengths();
        uint256 epoch = getCurrentEpochNumber();
        // update staker last epoch
        stakerLastEpochVoted[staker_] = epoch;
        for (uint256 i = 0; i < length; i++) {
            // increase all the votes storages
            stakerVotesUsed[epoch][staker_] += votes_[i];
            proposalVotes[epoch][proposals_[i]] += votes_[i];
            stakerProposalsVoted[epoch][staker_][proposals_[i]] += votes_[i];
            totalVotes[epoch] += votes_[i];
        }
        // reverts if staker votes more than its voting power
        if (stakerVotesUsed[epoch][staker_] > rgovToken.balanceOf(staker_)) revert InsufficientVotingPower();
    }

    function _decreaseVotes(address staker_, address[] memory proposals_, uint256[] memory votes_) internal {
        uint256 length = proposals_.length;
        if (length > maxProposalsPerBatch) revert TooManyProposals();
        if (length != votes_.length) revert UnequalLengths();
        uint256 epoch = getCurrentEpochNumber();
        // update staker last epoch
        stakerLastEpochVoted[staker_] = epoch;
        for (uint256 i = 0; i < length; i++) {
            // decrease all the votes storages
            stakerVotesUsed[epoch][staker_] -= votes_[i];
            proposalVotes[epoch][proposals_[i]] -= votes_[i];
            stakerProposalsVoted[epoch][staker_][proposals_[i]] -= votes_[i];
            totalVotes[epoch] -= votes_[i];
        }
    }

    function getStakerAllocation(address staker_) external view returns (uint256 allocation) {
        return stakerVotesUsed[stakerLastEpochVoted[staker_]][staker_];
    }

    function getProposalVotingPct(address proposal_, uint256 epoch_) external view returns (uint256 proposalPct) {
        return (totalVotes[epoch_] * 10 ** 18) / proposalVotes[epoch_][proposal_];
    }

    function getStakerRewardPct(
        address proposal_,
        address staker_,
        uint256 epoch_
    )
        external
        view
        returns (uint256 rewardPct)
    {
        return (proposalVotes[epoch_][proposal_] * 10 ** 18) / stakerProposalsVoted[epoch_][staker_][proposal_];
    }

    function getCurrentEpochNumber() public view returns (uint256 epoch) {
        return getEpochNumber(block.timestamp);
    }

    function getEpochNumber(uint256 timestamp) public view returns (uint256 epoch) {
        if (timestamp < FIRST_EPOCH || epochPeriod == 0) {
            return 0;
        }
        return ((timestamp - FIRST_EPOCH) / (epochPeriod) + 1);
    }
}
