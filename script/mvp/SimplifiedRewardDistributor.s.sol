// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { SimplifiedRewardDistributor } from "src/mvp/SimplifiedRewardDistributor.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (SimplifiedRewardDistributor) {
        address kycApprover = vm.envAddress("KYC_APPROVER_ADDRESS");
        address changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        address rewardTokenAddress = vm.envOr("RewardToken", address(0));
        if (changeExecutorAddress == address(0)) {
            changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        if (rewardTokenAddress == address(0)) {
            rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        }
        return run(changeExecutorAddress, rewardTokenAddress, kycApprover);
    }

    function run(
        address changeExecutor_,
        address rewardToken_,
        address kycApprover_
    )
        public
        broadcast
        returns (SimplifiedRewardDistributor)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(rewardToken_ != address(0), "Reward Token address cannot be empty");
        require(kycApprover_ != address(0), "KYC Approver address cannot be empty");

        string memory _contractName = "SimplifiedRewardDistributor.sol";
        bytes memory _initializerData =
            abi.encodeCall(SimplifiedRewardDistributor.initialize, (changeExecutor_, rewardToken_, kycApprover_));
        if (vm.envOr("NO_DD", false)) {
            return SimplifiedRewardDistributor(payable(_deployUUPSProxy(_contractName, _initializerData)));
        }
        return SimplifiedRewardDistributor(payable(_deployUUPSProxyDD(_contractName, _initializerData, _salt)));
    }
}
