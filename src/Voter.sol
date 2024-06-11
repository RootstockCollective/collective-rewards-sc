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

    mapping(address proposal => uint256 votes) public lastProposalVotes;
    mapping(address staker => mapping(address proposal => uint256 votes)) public lastStakerProposalsVoted;
    mapping(address staker => uint256 epoch) public lastStakerVotesUsed;
    uint256 public lastTotalVotes;

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
        for (uint256 i = 0; i < length; i++) {
            // increase all the votes storages
            lastStakerVotesUsed[staker_] += votes_[i];
            lastProposalVotes[proposals_[i]] += votes_[i];
            lastStakerProposalsVoted[staker_][proposals_[i]] += votes_[i];
            lastTotalVotes += votes_[i];
        }
        // reverts if staker votes more than its voting power
        if (lastStakerVotesUsed[staker_] > rgovToken.balanceOf(staker_)) revert InsufficientVotingPower();
        _updateEpochVotes(staker_, proposals_);
    }

    function _decreaseVotes(address staker_, address[] memory proposals_, uint256[] memory votes_) internal {
        uint256 length = proposals_.length;
        if (length > maxProposalsPerBatch) revert TooManyProposals();
        if (length != votes_.length) revert UnequalLengths();
        for (uint256 i = 0; i < length; i++) {
            // decrease all the votes storages
            lastStakerVotesUsed[staker_] -= votes_[i];
            lastProposalVotes[proposals_[i]] -= votes_[i];
            lastStakerProposalsVoted[staker_][proposals_[i]] -= votes_[i];
            lastTotalVotes -= votes_[i];
        }
        _updateEpochVotes(staker_, proposals_);
    }

    function _updateEpochVotes(address staker_, address[] memory proposals_) internal {
        uint256 length = proposals_.length;
        uint256 epoch = getCurrentEpochNumber();
        for (uint256 i = 0; i < length; i++) {
            stakerVotesUsed[epoch][staker_] = lastStakerVotesUsed[staker_];
            proposalVotes[epoch][proposals_[i]] = lastProposalVotes[proposals_[i]];
            stakerProposalsVoted[epoch][staker_][proposals_[i]] = lastStakerProposalsVoted[staker_][proposals_[i]];
            totalVotes[epoch] = lastTotalVotes;
        }
    }

    function getStakerAllocation(address staker_) external view returns (uint256 allocation) {
        return lastStakerVotesUsed[staker_];
    }

    function getProposalVotingPct(uint256 epoch_, address proposal_) external view returns (uint256 proposalPct) {
        // if epoch is empty, scan until find the last one updated
        // TODO: how much epochs we can search without fail by gas limit?
        // TODO: verify both variables > 0 or is enough with only one? are they always updated together?
        for (uint256 i = epoch_; i > 0; i--) {
            uint256 _proposalVotes = proposalVotes[i][proposal_];
            if (_proposalVotes > 0) {
                return (_proposalVotes * 10 ** 18) / totalVotes[i];
            }
        }
        return 0;
    }

    function getStakerRewardPct(
        uint256 epoch_,
        address staker_,
        address proposal_
    )
        external
        view
        returns (uint256 rewardPct)
    {
        // if epoch is empty, scan until find the last one updated
        // TODO: how much epochs we can search without fail by gas limit?
        // TODO: verify both variables > 0 or is enough with only one? are they always updated together?
        for (uint256 i = epoch_; i > 0; i--) {
            uint256 _stakerProposalsVoted = stakerProposalsVoted[i][staker_][proposal_];
            if (_stakerProposalsVoted > 0) {
                return (_stakerProposalsVoted * 10 ** 18) / proposalVotes[i][proposal_];
            }
        }
        return 0;
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
