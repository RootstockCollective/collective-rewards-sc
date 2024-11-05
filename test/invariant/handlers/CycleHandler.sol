// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";

contract CycleHandler is BaseHandler {
    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) { }

    function setCycleDuration(
        uint32 newCycleDuration_,
        uint24 cycleStartOffset_,
        uint256 timeToSkip_
    )
        external
        skipTime(timeToSkip_)
    {
        newCycleDuration_ = uint32(bound(newCycleDuration_, 2 hours, 365 days));
        cycleStartOffset_ = uint24(bound(cycleStartOffset_, 0, 20 weeks));
        vm.prank(baseTest.governanceManager().governor());
        sponsorsManager.setCycleDuration(newCycleDuration_, cycleStartOffset_);
    }
}
