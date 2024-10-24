// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SimplifiedRewardDistributor } from "src/mvp/SimplifiedRewardDistributor.sol";

contract Deploy is Broadcaster {
    function run() public returns (SimplifiedRewardDistributor proxy_, SimplifiedRewardDistributor implementation_) {
        address _changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        address _rewardTokenAddress = vm.envOr("RewardToken", address(0));
        if (_changeExecutorAddress == address(0)) {
            _changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        if (_rewardTokenAddress == address(0)) {
            _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        }
        (proxy_, implementation_) = run(_changeExecutorAddress, _rewardTokenAddress);
    }

    function run(
        address changeExecutor_,
        address rewardToken_
    )
        public
        broadcast
        returns (SimplifiedRewardDistributor, SimplifiedRewardDistributor)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(rewardToken_ != address(0), "Reward Token address cannot be empty");

        bytes memory _initializerData =
            abi.encodeCall(SimplifiedRewardDistributor.initialize, (changeExecutor_, rewardToken_));
        address _implementation;
        address _proxy;
        if (vm.envOr("NO_DD", false)) {
            _implementation = address(new SimplifiedRewardDistributor());
            _proxy = address(new ERC1967Proxy(_implementation, _initializerData));

            return (SimplifiedRewardDistributor(payable(_proxy)), SimplifiedRewardDistributor(payable(_implementation)));
        }
        _implementation = address(new SimplifiedRewardDistributor{ salt: _salt }());
        _proxy = address(new ERC1967Proxy{ salt: _salt }(_implementation, _initializerData));

        return (SimplifiedRewardDistributor(payable(_proxy)), SimplifiedRewardDistributor(payable(_implementation)));
    }
}
