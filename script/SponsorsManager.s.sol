// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { DeployUUPSProxy } from "script/script_utils/DeployUUPSProxy.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";

contract Deploy is Broadcaster, DeployUUPSProxy {
    function run() public returns (SponsorsManager proxy_, SponsorsManager implementation_) {
        address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        address _changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        if (_changeExecutorAddress == address(0)) {
            _changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        address _builderGaugeFactoryAddress = vm.envOr("BuilderGaugeFactory", address(0));
        if (_builderGaugeFactoryAddress == address(0)) {
            _builderGaugeFactoryAddress = vm.envAddress("BUILDER_GAUGE_FACTORY_ADDRESS");
        }
        address _builderRegistryAddress = vm.envOr("BuilderRegistry", address(0));
        if (_builderRegistryAddress == address(0)) {
            _builderRegistryAddress = vm.envAddress("BUILDER_REGISTRY_ADDRESS");
        }

        (proxy_, implementation_) = run(
            _changeExecutorAddress,
            _rewardTokenAddress,
            _stakingTokenAddress,
            _builderGaugeFactoryAddress,
            _builderRegistryAddress
        );
    }

    function run(
        address changeExecutor_,
        address rewardToken_,
        address stakingToken_,
        address builderGaugeFactory_,
        address builderRegistry_
    )
        public
        broadcast
        returns (SponsorsManager, SponsorsManager)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        require(stakingToken_ != address(0), "Staking token address cannot be empty");
        require(builderGaugeFactory_ != address(0), "BuilderGauge factory address cannot be empty");
        require(builderRegistry_ != address(0), "BuilderGauge factory address cannot be empty");

        string memory _contractName = "SponsorsManager.sol";
        bytes memory _initializerData = abi.encodeCall(
            SponsorsManager.initialize,
            (changeExecutor_, rewardToken_, stakingToken_, builderGaugeFactory_, builderRegistry_)
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
