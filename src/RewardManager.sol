// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { RGOV } from "./RGOV.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardManager {
    IERC20 public rifToken;

    constructor(RGOV rifToken_) {
        rifToken = rifToken_;
    }
}
