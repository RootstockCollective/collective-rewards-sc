// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.28;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run()
        public
        returns (BuilderRegistryRootstockCollective proxy_, BuilderRegistryRootstockCollective implementation_)
    {
        address _backersManager = vm.envOr("BackersManagerRootstockCollective", address(0));
        if (_backersManager == address(0)) {
            _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        }
        address _gaugeFactoryAddress = vm.envOr("GaugeFactoryRootstockCollective", address(0));
        if (_gaugeFactoryAddress == address(0)) {
            _gaugeFactoryAddress = vm.envAddress("GAUGE_FACTORY_ADDRESS");
        }
        address _rewardDistributorAddress =
            vm.envOr("RewardDistributorRootstockCollective", vm.envAddress("REWARD_DISTRIBUTOR_ADDRESS"));
        if (_rewardDistributorAddress == address(0)) {
            _rewardDistributorAddress = vm.envAddress("REWARD_DISTRIBUTOR_ADDRESS");
        }
        uint128 _rewardPercentageCooldown = uint128(vm.envUint("REWARD_PERCENTAGE_COOLDOWN"));
        (proxy_, implementation_) =
            run(_backersManager, _gaugeFactoryAddress, _rewardDistributorAddress, _rewardPercentageCooldown);
    }

    function run(
        address backersManager_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint128 rewardPercentageCooldown_
    )
        public
        broadcast
        returns (BuilderRegistryRootstockCollective, BuilderRegistryRootstockCollective)
    {
        require(backersManager_ != address(0), "Backers Manager address cannot be empty");
        require(gaugeFactory_ != address(0), "Gauge factory address cannot be empty");
        require(rewardDistributor_ != address(0), "Reward Distributor address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(
            BuilderRegistryRootstockCollective.initialize,
            (
                BackersManagerRootstockCollective(backersManager_),
                gaugeFactory_,
                rewardDistributor_,
                rewardPercentageCooldown_
            )
        );

        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new BuilderRegistryRootstockCollective());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (BuilderRegistryRootstockCollective(_proxy), BuilderRegistryRootstockCollective(_implementation));
        }
        _implementation = address(new BuilderRegistryRootstockCollective{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (BuilderRegistryRootstockCollective(_proxy), BuilderRegistryRootstockCollective(_implementation));
    }
}
