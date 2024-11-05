// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { BaseTest } from "../../BaseTest.sol";
import { TimeManager } from "./TimeManager.sol";
import { SponsorsManagerRootstockCollective } from "src/SponsorsManagerRootstockCollective.sol";

contract BaseHandler is Test {
    BaseTest public baseTest;
    TimeManager public timeManager;
    SponsorsManagerRootstockCollective public sponsorsManager;

    constructor(BaseTest baseTest_, TimeManager timeManager_) {
        baseTest = baseTest_;
        timeManager = timeManager_;
        sponsorsManager = baseTest_.sponsorsManager();
    }

    modifier skipTime(uint256 timeToSkip_) {
        vm.warp(timeManager.timestamp());
        uint256 _nextCycle = sponsorsManager.cycleNext(block.timestamp) - block.timestamp;
        timeToSkip_ = bound(timeToSkip_, 0, 2 * _nextCycle);
        timeManager.increaseTimestamp(timeToSkip_);
        _;
    }
}
