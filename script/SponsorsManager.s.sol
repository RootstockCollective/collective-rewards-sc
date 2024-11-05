// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { IGovernanceManager } from "../src/interfaces/IGovernanceManager.sol";

contract Deploy is Broadcaster {
    function run() public returns (SponsorsManager proxy_, SponsorsManager implementation_) {
        address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        address _governanceManager = vm.envOr("GovernanceManager", address(0));
        if (_governanceManager == address(0)) {
            _governanceManager = vm.envAddress("GOVERNANCE_MANAGER_ADDRESS");
        }
        address _gaugeFactoryAddress = vm.envOr("GaugeFactoryRootstockCollective", address(0));
        if (_gaugeFactoryAddress == address(0)) {
            _gaugeFactoryAddress = vm.envAddress("GAUGE_FACTORY_ADDRESS");
        }
        address _rewardDistributorAddress = vm.envOr("RewardDistributor", address(0));
        if (_rewardDistributorAddress == address(0)) {
            _rewardDistributorAddress = vm.envAddress("REWARD_DISTRIBUTOR_ADDRESS");
        }
        uint32 _cycleDuration = uint32(vm.envUint("CYCLE_DURATION"));
        uint24 _cycleStartOffset = uint24(vm.envUint("CYCLE_START_OFFSET"));
        uint128 _rewardPercentageCooldown = uint128(vm.envUint("REWARD_PERCENTAGE_COOLDOWN"));
        (proxy_, implementation_) = run(
            _governanceManager,
            _rewardTokenAddress,
            _stakingTokenAddress,
            _gaugeFactoryAddress,
            _rewardDistributorAddress,
            _cycleDuration,
            _cycleStartOffset,
            _rewardPercentageCooldown
        );
    }

    function run(
        address governanceManager_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint128 rewardPercentageCooldown_
    )
        public
        broadcast
        returns (SponsorsManager, SponsorsManager)
    {
        require(governanceManager_ != address(0), "Access control address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        require(stakingToken_ != address(0), "Staking token address cannot be empty");
        require(gaugeFactory_ != address(0), "Gauge factory address cannot be empty");
        require(rewardDistributor_ != address(0), "Reward Distributor address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(
            SponsorsManager.initialize,
            (
                IGovernanceManager(governanceManager_),
                rewardToken_,
                stakingToken_,
                gaugeFactory_,
                rewardDistributor_,
                cycleDuration_,
                cycleStartOffset_,
                rewardPercentageCooldown_
            )
        );
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new SponsorsManager());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (SponsorsManager(_proxy), SponsorsManager(_implementation));
        }
        _implementation = address(new SponsorsManager{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));
        return (SponsorsManager(_proxy), SponsorsManager(_implementation));
    }
}
