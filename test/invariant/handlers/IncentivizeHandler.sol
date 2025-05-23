// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { ERC20Mock } from "test/mock/ERC20Mock.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { UtilsLib } from "src/libraries/UtilsLib.sol";

contract IncentivizeHandler is BaseHandler {
    ERC20Mock public rewardToken;

    mapping(GaugeRootstockCollective gauge => uint256 amount) public rewardTokenIncentives;

    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) {
        rewardToken = baseTest_.rewardToken();
    }

    function incentivize(
        uint256 gaugeIndex_,
        uint256 amountERC20_,
        uint256 amountCoinbase_,
        uint256 timeToSkip_
    )
        external
        skipTime(timeToSkip_)
    {
        if (msg.sender.code.length != 0) return;
        if (backersManager.periodFinish() <= block.timestamp) return;
        gaugeIndex_ = bound(gaugeIndex_, 0, baseTest.gaugesArrayLength() - 1);
        amountERC20_ = bound(amountERC20_, UtilsLib.MIN_AMOUNT_INCENTIVES, type(uint64).max);
        amountCoinbase_ = bound(amountCoinbase_, UtilsLib.MIN_AMOUNT_INCENTIVES, type(uint64).max);

        GaugeRootstockCollective _gauge = baseTest.gaugesArray(gaugeIndex_);
        if (builderRegistry.isGaugeHalted(address(_gauge))) return;

        rewardTokenIncentives[_gauge] += amountERC20_;

        rewardToken.mint(msg.sender, amountERC20_);
        vm.deal(msg.sender, amountCoinbase_);

        vm.startPrank(msg.sender);
        rewardToken.approve(address(_gauge), amountERC20_);
        _gauge.incentivizeWithRewardToken(amountERC20_, address(rewardToken));
        _gauge.incentivizeWithCoinbase{ value: amountCoinbase_ }();
        vm.stopPrank();
    }
}
