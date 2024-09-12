// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";

contract Deploy is Broadcaster {
    function run() public returns (SponsorsManager proxy_, SponsorsManager implementation_) {
        address _kycApprover = vm.envAddress("KYC_APPROVER_ADDRESS");
        address _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        address _changeExecutorAddress = vm.envOr("ChangeExecutor", address(0));
        if (_changeExecutorAddress == address(0)) {
            _changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        }
        address _gaugeFactoryAddress = vm.envOr("GaugeFactory", address(0));
        if (_gaugeFactoryAddress == address(0)) {
            _gaugeFactoryAddress = vm.envAddress("GAUGE_FACTORY_ADDRESS");
        }
        uint128 _kickbackCooldown = uint128(vm.envUint("KICKBACK_COOLDOWN"));
        (proxy_, implementation_) = run(
            _changeExecutorAddress,
            _kycApprover,
            _rewardTokenAddress,
            _stakingTokenAddress,
            _gaugeFactoryAddress,
            _kickbackCooldown
        );
    }

    function run(
        address changeExecutor_,
        address kycApprover_,
        address rewardToken_,
        address stakingToken_,
        address gaugeFactory_,
        uint128 kickbackCooldown_
    )
        public
        broadcast
        returns (SponsorsManager, SponsorsManager)
    {
        require(changeExecutor_ != address(0), "Change executor address cannot be empty");
        require(kycApprover_ != address(0), "KYC Approver address cannot be empty");
        require(rewardToken_ != address(0), "Reward token address cannot be empty");
        require(stakingToken_ != address(0), "Staking token address cannot be empty");
        require(gaugeFactory_ != address(0), "Gauge factory address cannot be empty");

        bytes memory _initializerData = abi.encodeCall(
            SponsorsManager.initialize,
            (changeExecutor_, kycApprover_, rewardToken_, stakingToken_, gaugeFactory_, kickbackCooldown_)
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
