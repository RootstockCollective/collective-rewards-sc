// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { ERC20Mock } from "test/mock/ERC20Mock.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";

contract DistributionHandler is BaseHandler {
    ERC20Mock public rifToken;
    ERC20Mock public usdrifToken;
    RewardDistributorRootstockCollective public rewardDistributor;

    uint256 public totalAmountDistributed;
    uint256 public totalAmountDistributedUsdrif;

    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) {
        rifToken = baseTest_.rifToken();
        rewardDistributor = baseTest_.rewardDistributor();
        usdrifToken = baseTest_.usdrifToken();
    }

    function startDistribution(
        uint256 amountRif_,
        uint256 amountUsdrif_,
        uint256 amountNative_,
        uint256 timeToSkip_
    )
        external
        skipTime(timeToSkip_)
    {
        if (backersManager.totalPotentialReward() == 0) return;
        amountRif_ = bound(amountRif_, 0, type(uint64).max);
        amountUsdrif_ = bound(amountUsdrif_, 0, type(uint64).max);
        amountNative_ = bound(amountNative_, 0, type(uint64).max);

        timeManager.increaseTimestamp(
            backersManager.cycleNext(block.timestamp) - block.timestamp + (timeToSkip_ % 0.99 hours)
        );

        totalAmountDistributed += amountRif_;
        totalAmountDistributedUsdrif += amountUsdrif_;

        rifToken.mint(address(rewardDistributor), amountRif_);
        usdrifToken.mint(address(rewardDistributor), amountUsdrif_);
        vm.deal(address(rewardDistributor), amountNative_);
        vm.prank(baseTest.foundation());
        rewardDistributor.sendRewardsAndStartDistribution(amountRif_, amountUsdrif_, amountNative_);
    }
}
