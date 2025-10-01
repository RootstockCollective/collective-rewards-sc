// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster {
    function run()
        public
        returns (RewardDistributorRootstockCollective proxy_, RewardDistributorRootstockCollective implementation_)
    {
        address _governanceManager = vm.envOr("GovernanceManagerRootstockCollectiveProxy", address(0));
        if (_governanceManager == address(0)) {
            _governanceManager = vm.envAddress("GOVERNANCE_MANAGER_ADDRESS");
        }

        (proxy_, implementation_) = run(_governanceManager);

        address _backersManagerAddress = vm.envOr("BackersManagerRootstockCollectiveProxy", address(0));
        if (_backersManagerAddress == address(0)) {
            _backersManagerAddress = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        }

        proxy_.initializeCollectiveRewardsAddresses(address(_backersManagerAddress));
    }

    function run(address governanceManager_)
        public
        broadcast
        returns (RewardDistributorRootstockCollective, RewardDistributorRootstockCollective)
    {
        require(governanceManager_ != address(0), "Access control address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(
            RewardDistributorRootstockCollective.initialize, (IGovernanceManagerRootstockCollective(governanceManager_))
        );
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new RewardDistributorRootstockCollective());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (
                RewardDistributorRootstockCollective(payable(_proxy)),
                RewardDistributorRootstockCollective(payable(_implementation))
            );
        }
        _implementation = address(new RewardDistributorRootstockCollective{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (
            RewardDistributorRootstockCollective(payable(_proxy)),
            RewardDistributorRootstockCollective(payable(_implementation))
        );
    }
}
