// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CycleTimeKeeperRootstockCollective } from "src/backersManager/CycleTimeKeeperRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
  function run()
    public
    returns (CycleTimeKeeperRootstockCollective proxy_, CycleTimeKeeperRootstockCollective implementation_)
  {
    address _governanceManager = vm.envOr("GovernanceManagerRootstockCollective", address(0));
    if (_governanceManager == address(0)) {
      _governanceManager = vm.envAddress("GOVERNANCE_MANAGER_ADDRESS");
    }
    uint32 _cycleDuration = uint32(vm.envUint("CYCLE_DURATION"));
    uint32 _distributionDuration = uint32(vm.envUint("DISTRIBUTION_DURATION"));
    uint24 _cycleStartOffset = uint24(vm.envUint("CYCLE_START_OFFSET"));
    (proxy_, implementation_) = run(_governanceManager, _cycleDuration, _cycleStartOffset, _distributionDuration);
  }

  function run(
    address governanceManager_,
    uint32 cycleDuration_,
    uint24 cycleStartOffset_,
    uint32 distributionDuration_
  ) public broadcast returns (CycleTimeKeeperRootstockCollective, CycleTimeKeeperRootstockCollective) {
    require(governanceManager_ != address(0), "Access control address cannot be empty");

    bytes memory _initializerData = abi.encodeCall(
      CycleTimeKeeperRootstockCollective.initialize,
      (
        IGovernanceManagerRootstockCollective(governanceManager_),
        cycleDuration_,
        cycleStartOffset_,
        distributionDuration_
      )
    );
    address _implementation;
    address _proxy;
    if (vm.envOr("NO_DD", false)) {
      _implementation = address(new CycleTimeKeeperRootstockCollective());
      _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

      return (CycleTimeKeeperRootstockCollective(_proxy), CycleTimeKeeperRootstockCollective(_implementation));
    }
    _implementation = address(new CycleTimeKeeperRootstockCollective{ salt: _salt }());
    _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));
    return (CycleTimeKeeperRootstockCollective(_proxy), CycleTimeKeeperRootstockCollective(_implementation));
  }
}
