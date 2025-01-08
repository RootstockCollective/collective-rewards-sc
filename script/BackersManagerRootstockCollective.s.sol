// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
  function run()
    public
    returns (BackersManagerRootstockCollective proxy_, BackersManagerRootstockCollective implementation_)
  {
    address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
    address _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
    address _governanceManager = vm.envOr("GovernanceManagerRootstockCollective", address(0));
    if (_governanceManager == address(0)) {
      _governanceManager = vm.envAddress("GOVERNANCE_MANAGER_ADDRESS");
    }
    address _gaugeFactoryAddress = vm.envOr("GaugeFactoryRootstockCollective", address(0));
    if (_gaugeFactoryAddress == address(0)) {
      _gaugeFactoryAddress = vm.envAddress("GAUGE_FACTORY_ADDRESS");
    }
    address _rewardDistributorAddress = vm.envOr("RewardDistributorRootstockCollective", address(0));
    if (_rewardDistributorAddress == address(0)) {
      _rewardDistributorAddress = vm.envAddress("REWARD_DISTRIBUTOR_ADDRESS");
    }
    address _timeKeeperAddress = vm.envOr("CycleTimeKeeperRootstockCollective", address(0));
    if (_timeKeeperAddress == address(0)) {
      _timeKeeperAddress = vm.envAddress("TIME_KEEPER_ADDRESS");
    }
    uint128 _rewardPercentageCooldown = uint128(vm.envUint("REWARD_PERCENTAGE_COOLDOWN"));
    (proxy_, implementation_) = run(
      _governanceManager,
      _rewardTokenAddress,
      _stakingTokenAddress,
      _gaugeFactoryAddress,
      _rewardDistributorAddress,
      _timeKeeperAddress,
      _rewardPercentageCooldown
    );
  }

  function run(
    address governanceManager_,
    address rewardToken_,
    address stakingToken_,
    address gaugeFactory_,
    address rewardDistributor_,
    address timeKeeper_,
    uint128 rewardPercentageCooldown_
  ) public broadcast returns (BackersManagerRootstockCollective, BackersManagerRootstockCollective) {
    require(governanceManager_ != address(0), "Access control address cannot be empty");
    require(rewardToken_ != address(0), "Reward token address cannot be empty");
    require(stakingToken_ != address(0), "Staking token address cannot be empty");
    require(gaugeFactory_ != address(0), "Gauge factory address cannot be empty");
    require(timeKeeper_ != address(0), "Time keeper address cannot be empty");
    require(rewardDistributor_ != address(0), "Reward Distributor address cannot be empty");

    bytes memory _initializerData = abi.encodeCall(
      BackersManagerRootstockCollective.initialize,
      (
        IGovernanceManagerRootstockCollective(governanceManager_),
        rewardToken_,
        stakingToken_,
        gaugeFactory_,
        rewardDistributor_,
        timeKeeper_,
        rewardPercentageCooldown_
      )
    );
    address _implementation;
    address _proxy;
    if (vm.envOr("NO_DD", false)) {
      _implementation = address(new BackersManagerRootstockCollective());
      _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

      return (BackersManagerRootstockCollective(_proxy), BackersManagerRootstockCollective(_implementation));
    }
    _implementation = address(new BackersManagerRootstockCollective{ salt: _salt }());
    _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));
    return (BackersManagerRootstockCollective(_proxy), BackersManagerRootstockCollective(_implementation));
  }
}
