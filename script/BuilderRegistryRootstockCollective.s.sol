// SPDX-License-Identifier: MIT
// solhint-disable gas-custom-errors
// solhint-disable reason-string
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BuilderRegistryRootstockCollective } from "src/backersManager/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run()
        public
        returns (BuilderRegistryRootstockCollective proxy_, BuilderRegistryRootstockCollective implementation_)
    {
        address _backersManager = vm.envOr("BackersManagerRootstockCollective", address(0));
        if (_backersManager == address(0)) {
            _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        }
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
        uint128 _rewardPercentageCooldown = uint128(vm.envUint("REWARD_PERCENTAGE_COOLDOWN"));
        (proxy_, implementation_) =
            run(_governanceManager, _gaugeFactoryAddress, _rewardDistributorAddress, _rewardPercentageCooldown);

        if (_backersManager != address(0)) {
            BuilderRegistryRootstockCollective(proxy_).initializeBackersManager(
                BackersManagerRootstockCollective(_backersManager)
            );
        }
    }

    function run(
        address governanceManager_,
        address gaugeFactory_,
        address rewardDistributor_,
        uint128 rewardPercentageCooldown_
    )
        public
        broadcast
        returns (BuilderRegistryRootstockCollective, BuilderRegistryRootstockCollective)
    {
        require(governanceManager_ != address(0), "Access control address cannot be empty");
        require(gaugeFactory_ != address(0), "Gauge factory address cannot be empty");
        require(rewardDistributor_ != address(0), "Reward Distributor address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(
            BuilderRegistryRootstockCollective.initialize,
            (
                IGovernanceManagerRootstockCollective(governanceManager_),
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
