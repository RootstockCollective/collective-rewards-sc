// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run()
        public
        returns (BackersManagerRootstockCollective proxy_, BackersManagerRootstockCollective implementation_)
    {
        address _governanceManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        address _builderRegistry = vm.envAddress("BUILDER_REGISTRY");
        address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");

        uint32 _cycleDuration = uint32(vm.envUint("CYCLE_DURATION"));
        uint32 _distributionDuration = uint32(vm.envUint("DISTRIBUTION_DURATION"));
        uint24 _cycleStartOffset = uint24(vm.envUint("CYCLE_START_OFFSET"));

        (proxy_, implementation_) = run(
            _governanceManager,
            _builderRegistry,
            _rewardTokenAddress,
            _stakingTokenAddress,
            _cycleDuration,
            _cycleStartOffset,
            _distributionDuration
        );
    }

    function run(
        address governanceManager_,
        address builderRegistry_,
        address rewardToken_,
        address stakingToken_,
        uint32 cycleDuration_,
        uint24 cycleStartOffset_,
        uint32 distributionDuration_
    )
        public
        broadcast
        returns (BackersManagerRootstockCollective, BackersManagerRootstockCollective)
    {
        require(governanceManager_ != address(0), "Governance Manager address cannot be empty");
        require(builderRegistry_ != address(0), "Builder Registry address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        require(stakingToken_ != address(0), "Staking token address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(
            BackersManagerRootstockCollective.initialize,
            (
                IGovernanceManagerRootstockCollective(governanceManager_),
                builderRegistry_,
                rewardToken_,
                stakingToken_,
                cycleDuration_,
                cycleStartOffset_,
                distributionDuration_
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
