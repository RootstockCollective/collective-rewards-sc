// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";

contract Deploy is Broadcaster {
    function run() public returns (GaugeFactory) {
        address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        return run(_rewardTokenAddress);
    }

    function run(address rewardToken_) public broadcast returns (GaugeFactory) {
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        if (vm.envOr("NO_DD", false)) {
            return new GaugeFactory(rewardToken_);
        }
        return new GaugeFactory{ salt: _salt }(rewardToken_);
    }
}
