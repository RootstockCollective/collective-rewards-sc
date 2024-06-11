// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";
import { RGOV } from "../../src/RGOV.sol";
import { Staking } from "../../src/Staking.sol";
import { Voter } from "../../src/Voter.sol";
import { ERC20Mock } from "../../src/mocks/ERC20Mock.sol";

contract Base is Test {
    ERC20Mock public rifToken;
    RGOV public rgovToken;
    Staking public staking;
    Voter public voter;

    address[] public proposals;
    address[] public aliceProposals;
    uint256[] public aliceVotes;
    address[] public bobProposals;
    uint256[] public bobVotes;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.
        rifToken = new ERC20Mock();
        rgovToken = new RGOV();
        staking = new Staking(rifToken, rgovToken);
        voter = new Voter(rgovToken);
        rgovToken.initialize(staking, voter);

        vm.deal(alice, 100 ether);
        rifToken.mint(alice, 100 ether);

        vm.deal(alice, 100 ether);
        rifToken.mint(bob, 100 ether);

        proposals.push(address(1));
        proposals.push(address(2));
        proposals.push(address(3));

        aliceProposals.push(proposals[0]);
        aliceProposals.push(proposals[1]);
        aliceVotes.push(2 ether);
        aliceVotes.push(4 ether);

        bobProposals.push(proposals[0]);
        bobProposals.push(proposals[2]);
        bobVotes.push(4 ether);
        bobVotes.push(6 ether);
    }

    function _stake(address staker_, uint256 amount_) internal {
        vm.startPrank(staker_);
        rifToken.approve(address(staking), amount_);
        staking.stake(amount_);
        vm.stopPrank();
    }

    function _unstake(address staker_, uint256 amount_) internal {
        vm.startPrank(staker_);
        rgovToken.approve(address(staking), amount_);
        staking.unstake(amount_);
        vm.stopPrank();
    }

    function _skipToEpoch(uint256 epoch) internal {
        uint256 epochTime = ((epoch - 1) * voter.epochPeriod());
        vm.warp(epochTime + voter.FIRST_EPOCH());
    }
}
