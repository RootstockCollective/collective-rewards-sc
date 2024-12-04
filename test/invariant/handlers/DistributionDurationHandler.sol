// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";

contract DistributionDurationHandler is BaseHandler {
    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) { }

    function increaseTimestamp(uint256 deltaTime_) external {
        deltaTime_ = bound(deltaTime_, 0, 1 weeks);
        timeManager.increaseTimestamp(deltaTime_);
    }

    function setDistributionDuration(uint32 newDuration_) external {
        vm.prank(baseTest.governanceManager().governor());
        backersManager.setDistributionDuration(newDuration_);
    }
}
