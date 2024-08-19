// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";

contract Deploy is Broadcaster {
    function run() public returns (RewardDistributor proxy_, RewardDistributor implementation_) {
        address _changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        if (_changeExecutorAddress == address(0)) {
            _changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        address _foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        address _sponsorsManagerAddress = vm.envOr("SponsorsManager", address(0));
        if (_sponsorsManagerAddress == address(0)) {
            _sponsorsManagerAddress = vm.envAddress("SPONSORS_MANAGER_ADDRESS");
        }

        (proxy_, implementation_) = run(_changeExecutorAddress, _foundationTreasuryAddress, _sponsorsManagerAddress);
    }

    function run(
        address changeExecutor_,
        address foundationTreasury_,
        address sponsorsManager_
    )
        public
        broadcast
        returns (RewardDistributor, RewardDistributor)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(foundationTreasury_ != address(0), "Foundation Treasury address cannot be empty");
        require(sponsorsManager_ != address(0), "Sponsors Manager address cannot be empty");

        bytes memory _initializerData =
            abi.encodeCall(RewardDistributor.initialize, (changeExecutor_, foundationTreasury_, sponsorsManager_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new RewardDistributor());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (RewardDistributor(_proxy), RewardDistributor(_implementation));
        }
        _implementation = address(new RewardDistributor{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (RewardDistributor(_proxy), RewardDistributor(_implementation));
    }
}
