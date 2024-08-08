// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (RewardDistributor proxy, RewardDistributor implementation) {
        address changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        if (changeExecutorAddress == address(0)) {
            changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        address foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        address sponsorsManagerAddress = vm.envOr("SponsorsManager", address(0));
        if (sponsorsManagerAddress == address(0)) {
            sponsorsManagerAddress = vm.envAddress("SPONSORS_MANAGER_ADDRESS");
        }

        ((proxy, implementation)) = run(changeExecutorAddress, foundationTreasuryAddress, sponsorsManagerAddress);
    }

    function run(
        address changeExecutor_,
        address foundationTreasury_,
        address sponsorsManager_
    )
        public
        broadcast
        returns (RewardDistributor, RewardDistributor)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(foundationTreasury_ != address(0), "Foundation Treasury address cannot be empty");
        require(sponsorsManager_ != address(0), "Sponsors Manager address cannot be empty");

        string memory _contractName = "RewardDistributor.sol";
        bytes memory _initializerData =
            abi.encodeCall(RewardDistributor.initialize, (changeExecutor_, foundationTreasury_, sponsorsManager_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            (_proxy, _implementation) = _deployUUPSProxy(_contractName, _initializerData);

            return (RewardDistributor(_proxy), RewardDistributor(_implementation));
        }
        (_proxy, _implementation) = _deployUUPSProxyDD(_contractName, _initializerData, _salt);

        return (RewardDistributor(_proxy), RewardDistributor(_implementation));
    }
}
