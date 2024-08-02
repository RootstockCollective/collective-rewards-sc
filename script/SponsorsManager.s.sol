// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";

contract Deploy is Broadcaster {
    function run() public returns (SponsorsManager) {
        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        address rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        address changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        if (changeExecutorAddress == address(0)) {
            changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        address gaugeFactoryAddress = vm.envOr("GaugeFactory", address(0));
        if (gaugeFactoryAddress == address(0)) {
            gaugeFactoryAddress = vm.envAddress("GAUGE_FACTORY_ADDRESS");
        }
        return run(governorAddress, changeExecutorAddress, rewardTokenAddress, stakingTokenAddress, gaugeFactoryAddress);
    }

    function run(
        address governor_,
        address changeExecutor_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_
    )
        public
        broadcast
        returns (SponsorsManager)
    {
        require(governor_ != address(0), "Governor address cannot be empty");
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        require(stakingToken_ != address(0), "Staking token address cannot be empty");
        require(gaugeFactory_ != address(0), "Gauge factory address cannot be empty");

        if (vm.envOr("NO_DD", false)) {
            return new SponsorsManager(governor_, changeExecutor_, rewardToken_, stakingToken_, gaugeFactory_);
        }
        return
            new SponsorsManager{ salt: _salt }(governor_, changeExecutor_, rewardToken_, stakingToken_, gaugeFactory_);
    }
}
