// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Staking } from "./Staking.sol";
import { Voter } from "./Voter.sol";

contract RGOV is ERC20 {
    Staking public staking;
    Voter public voter;

    error TokensUsedToVote();
    error OnlyStaking();

    constructor() ERC20("RGOV", "RGOV") { }

    // TODO: only for POC
    function initialize(Staking staking_, Voter voter_) external {
        staking = staking_;
        voter = voter_;
    }

    function mint(address to_, uint256 amount_) public {
        if (msg.sender != address(staking)) revert OnlyStaking();
        _mint(to_, amount_);
    }

    function burn(address from_, uint256 amount_) public {
        if (msg.sender != address(staking)) revert OnlyStaking();
        _burn(from_, amount_);
    }

    function _update(address from_, address to_, uint256 amount_) internal virtual override {
        super._update(from_, to_, amount_);
        if (from_ != address(0) && balanceOf(from_) < voter.getStakerAllocation(from_)) {
            revert TokensUsedToVote();
        }
    }
}
