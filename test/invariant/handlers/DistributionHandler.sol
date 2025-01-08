// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { ERC20Mock } from "test/mock/ERC20Mock.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";

contract DistributionHandler is BaseHandler {
  ERC20Mock public rewardToken;
  RewardDistributorRootstockCollective public rewardDistributor;

  uint256 public totalAmountDistributed;

  constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) {
    rewardToken = baseTest_.rewardToken();
    rewardDistributor = baseTest_.rewardDistributor();
  }

  function startDistribution(
    uint256 amountERC20_,
    uint256 amountCoinbase_,
    uint256 timeToSkip_
  ) external skipTime(timeToSkip_) {
    if (backersManager.totalPotentialReward() == 0) return;
    amountERC20_ = bound(amountERC20_, 0, type(uint64).max);
    amountCoinbase_ = bound(amountCoinbase_, 0, type(uint64).max);

    timeManager.increaseTimestamp(
      backersManager.timeKeeper().cycleNext(block.timestamp) - block.timestamp + (timeToSkip_ % 0.99 hours)
    );

    totalAmountDistributed += amountERC20_;

    rewardToken.mint(address(rewardDistributor), amountERC20_);
    vm.deal(address(rewardDistributor), amountCoinbase_);
    vm.prank(baseTest.foundation());
    rewardDistributor.sendRewardsAndStartDistribution(amountERC20_, amountCoinbase_);
  }
}
