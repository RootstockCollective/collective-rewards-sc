// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";

contract EpochHandler is BaseHandler {
    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) { }

    function setEpochDuration(
        uint32 newEpochDuration_,
        uint24 epochStartOffset_,
        uint256 timeToSkip_
    )
        external
        skipTime(timeToSkip_)
    {
        newEpochDuration_ = uint32(bound(newEpochDuration_, 2 hours, 365 days));
        epochStartOffset_ = uint24(bound(epochStartOffset_, 0, 20 weeks));
        vm.prank(baseTest.governanceManager().governor());
        sponsorsManager.setEpochDuration(newEpochDuration_, epochStartOffset_);
    }
}
