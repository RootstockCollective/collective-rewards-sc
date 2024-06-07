// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Staking } from "./Staking.sol";
import { Voter } from "./Voter.sol";

contract RGOV is ERC20, Ownable {
    Staking public staking;
    Voter public voter;

    error TokensUsedToVote();

    constructor(address initialOwner_) ERC20("RGOV", "RGOV") Ownable(initialOwner_) { }

    // TODO: only for POC
    function initialize(address staking_, address voter_) external {
        staking = Staking(staking_);
        voter = Voter(voter_);
    }

    function mint(address to_, uint256 amount_) public onlyOwner {
        _mint(to_, amount_);
    }

    function burn(address from_, uint256 amount_) public onlyOwner {
        _burn(from_, amount_);
    }

    function _update(address from_, address to_, uint256 amount_) internal virtual override {
        if (balanceOf(from_) - voter.getStakerAllocation(from_) < amount_) revert TokensUsedToVote();
        super._update(from_, to_, amount_);
    }
}
