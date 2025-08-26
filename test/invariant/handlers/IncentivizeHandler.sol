// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { ERC20Mock } from "test/mock/ERC20Mock.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { UtilsLib } from "src/libraries/UtilsLib.sol";

contract IncentivizeHandler is BaseHandler {
    ERC20Mock public rifToken;

    mapping(GaugeRootstockCollective gauge => uint256 amount) public rifTokenIncentives;

    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) {
        rifToken = baseTest_.rifToken();
    }

    function incentivize(
        uint256 gaugeIndex_,
        uint256 amountRif_,
        uint256 amountNative_,
        uint256 timeToSkip_
    )
        external
        skipTime(timeToSkip_)
    {
        if (msg.sender.code.length != 0) return;
        if (backersManager.periodFinish() <= block.timestamp) return;
        gaugeIndex_ = bound(gaugeIndex_, 0, baseTest.gaugesArrayLength() - 1);
        amountRif_ = bound(amountRif_, UtilsLib.MIN_AMOUNT_INCENTIVES, type(uint64).max);
        amountNative_ = bound(amountNative_, UtilsLib.MIN_AMOUNT_INCENTIVES, type(uint64).max);

        GaugeRootstockCollective _gauge = baseTest.gaugesArray(gaugeIndex_);
        if (builderRegistry.isGaugeHalted(address(_gauge))) return;

        rifTokenIncentives[_gauge] += amountRif_;

        rifToken.mint(msg.sender, amountRif_);
        vm.deal(msg.sender, amountNative_);

        vm.startPrank(msg.sender);
        rifToken.approve(address(_gauge), amountRif_);
        _gauge.incentivizeWithRifToken(amountRif_);
        _gauge.incentivizeWithNative{ value: amountNative_ }();
        vm.stopPrank();
    }
}
