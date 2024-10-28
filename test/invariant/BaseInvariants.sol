// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, Gauge } from "../BaseTest.sol";
import { AllocateHandler } from "./handlers/AllocateHandler.sol";
import { BuilderHandler } from "./handlers/BuilderHandler.sol";
import { EpochHandler } from "./handlers/EpochHandler.sol";
import { TimeManager } from "./handlers/TimeManager.sol";
import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { IncentivizeHandler } from "./handlers/IncentivizeHandler.sol";

contract BaseInvariants is BaseTest {
    TimeManager public timeManager;
    BuilderHandler public builderHandler;
    AllocateHandler public allocateHandler;
    EpochHandler public epochHandler;
    DistributionHandler public distributionHandler;
    IncentivizeHandler public incentivizeHandler;

    function _setUp() internal override {
        // delete all the arrays created on BaseTest setup to start from scratch
        delete gaugesArray;
        delete allocationsArray;
        delete builders;

        timeManager = new TimeManager();
        allocateHandler = new AllocateHandler(BaseTest(payable(address(this))), timeManager);
        builderHandler = new BuilderHandler(BaseTest(payable(address(this))), timeManager);
        epochHandler = new EpochHandler(BaseTest(payable(address(this))), timeManager);
        distributionHandler = new DistributionHandler(BaseTest(payable(address(this))), timeManager);
        incentivizeHandler = new IncentivizeHandler(BaseTest(payable(address(this))), timeManager);

        targetContract(address(allocateHandler));
        targetContract(address(builderHandler));
        targetContract(address(epochHandler));
        targetContract(address(distributionHandler));
        targetContract(address(incentivizeHandler));

        // creates 15 gauges with 40% of kickback
        uint64 _kickback = 0.4 ether; // 40%
        _createGauges(15, _kickback);
    }

    modifier useTime() {
        vm.warp(timeManager.timestamp());
        _;
    }
}