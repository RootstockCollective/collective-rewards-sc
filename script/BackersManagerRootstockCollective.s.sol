// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "src/backersManager/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
  function run()
    public
    returns (BackersManagerRootstockCollective proxy_, BackersManagerRootstockCollective implementation_)
  {
    address _builderRegistry = vm.envAddress("BUILDER_REGISTRY");
    address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
    address _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");

    (proxy_, implementation_) = run(_builderRegistry, _rewardTokenAddress, _stakingTokenAddress);
  }

  function run(
    address builderRegistry_,
    address rewardToken_,
    address stakingToken_
  ) public broadcast returns (BackersManagerRootstockCollective, BackersManagerRootstockCollective) {
    require(builderRegistry_ != address(0), "Builder Registry address cannot be empty");
    require(rewardToken_ != address(0), "Reward token address cannot be empty");
    require(stakingToken_ != address(0), "Staking token address cannot be empty");

    bytes memory _initializerData = abi.encodeCall(
      BackersManagerRootstockCollective.initialize,
      (BuilderRegistryRootstockCollective(builderRegistry_), rewardToken_, stakingToken_)
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
