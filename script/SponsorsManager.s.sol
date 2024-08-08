// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (SponsorsManager proxy, SponsorsManager implementation) {
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
        address builderRegistryAddress = vm.envOr("BuilderRegistry", address(0));
        if (builderRegistryAddress == address(0)) {
            builderRegistryAddress = vm.envAddress("BUILDER_REGISTRY_ADDRESS");
        }

        ((proxy, implementation)) = run(
            changeExecutorAddress, rewardTokenAddress, stakingTokenAddress, gaugeFactoryAddress, builderRegistryAddress
        );
    }

    function run(
        address changeExecutor_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        address builderRegistry_
    )
        public
        broadcast
        returns (SponsorsManager, SponsorsManager)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        require(stakingToken_ != address(0), "Staking token address cannot be empty");
        require(gaugeFactory_ != address(0), "Gauge factory address cannot be empty");
        require(builderRegistry_ != address(0), "Gauge factory address cannot be empty");

        string memory _contractName = "SponsorsManager.sol";
        bytes memory _initializerData = abi.encodeCall(
            SponsorsManager.initialize, (changeExecutor_, rewardToken_, stakingToken_, gaugeFactory_, builderRegistry_)
        );
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            (_proxy, _implementation) = _deployUUPSProxy(_contractName, _initializerData);

            return (SponsorsManager(_proxy), SponsorsManager(_implementation));
        }
        (_proxy, _implementation) = _deployUUPSProxyDD(_contractName, _initializerData, _salt);

        return (SponsorsManager(_proxy), SponsorsManager(_implementation));
    }
}
