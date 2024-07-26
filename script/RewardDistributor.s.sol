// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";

contract Deploy is Broadcaster {
    function run() public returns (RewardDistributor) {
        address foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        address rewardTokenAddress = vm.envOr("RewardToken", address(0));
        if (rewardTokenAddress == address(0)) {
            rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        }
        address sponsorsManagerAddress = vm.envOr("SponsorsManager", address(0));
        if (sponsorsManagerAddress == address(0)) {
            sponsorsManagerAddress = vm.envAddress("SPONSORS_MANAGER_ADDRESS");
        }
        return run(foundationTreasuryAddress, rewardTokenAddress, sponsorsManagerAddress);
    }

    function run(
        address foundationTreasury,
        address rewardToken,
        address sponsorsManager
    )
        public
        broadcast
        returns (RewardDistributor)
    {
        require(foundationTreasury != address(0), "Foundation Treasury address cannot be empty");
        require(rewardToken != address(0), "Reward Token address cannot be empty");
        require(sponsorsManager != address(0), "Sponsors Manager address cannot be empty");

        if (vm.envOr("NO_DD", false)) {
            return new RewardDistributor(foundationTreasury, rewardToken, sponsorsManager);
        }
        return new RewardDistributor{ salt: _salt }(foundationTreasury, rewardToken, sponsorsManager);
    }
}
