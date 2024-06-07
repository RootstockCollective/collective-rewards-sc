// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { RGOV } from "./RGOV.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking {
    IERC20 public rifToken;
    RGOV public rgovToken;

    constructor(IERC20 rifToken_, RGOV rgovToken_) {
        rifToken = rifToken_;
        rgovToken = rgovToken_;
    }

    function stake(uint256 amount_) external {
        address staker = msg.sender;
        SafeERC20.safeTransferFrom(rifToken, staker, address(this), amount_);
        rgovToken.mint(staker, amount_);
    }

    function unstake(uint256 amount_) external {
        address staker = msg.sender;
        SafeERC20.safeTransfer(rifToken, staker, amount_);
        rgovToken.burn(staker, amount_);
    }
}
