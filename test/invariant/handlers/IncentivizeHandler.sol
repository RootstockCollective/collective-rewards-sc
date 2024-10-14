// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { ERC20Mock } from "test/mock/ERC20Mock.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { Gauge } from "src/gauge/Gauge.sol";

contract IncentivizeHandler is BaseHandler {
    ERC20Mock public rewardToken;

    mapping(Gauge gauge => uint256 amount) public rewardTokenIncentives;

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
        if (sponsorsManager.periodFinish() <= block.timestamp) return;
        gaugeIndex_ = bound(gaugeIndex_, 0, baseTest.gaugesArrayLength() - 1);
        amountERC20_ = bound(amountERC20_, 0, type(uint64).max);
        amountCoinbase_ = bound(amountCoinbase_, 0, type(uint64).max);

        Gauge _gauge = baseTest.gaugesArray(gaugeIndex_);
        if (sponsorsManager.isGaugeHalted(address(_gauge))) return;

        rewardTokenIncentives[_gauge] += amountERC20_;

        rewardToken.mint(msg.sender, amountERC20_);
        vm.deal(msg.sender, amountCoinbase_);

        vm.startPrank(msg.sender);
        rewardToken.approve(address(_gauge), amountERC20_);
        _gauge.incentivizeWithRewardToken(amountERC20_);
        _gauge.incentivizeWithCoinbase{ value: amountCoinbase_ }();
        vm.stopPrank();
    }
}
