// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";
import { Deploy as ChangeExecutorDeployer } from "script/governance/ChangeExecutor.s.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";
import { Deploy as BuilderRegistryDeployer } from "script/BuilderRegistry.s.sol";
import { BuilderGaugeFactory } from "src/builder/BuilderGaugeFactory.sol";
import { Deploy as BuilderGaugeFactoryDeployer } from "script/builder/BuilderGaugeFactory.s.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { Deploy as RewardDistributorDeployer } from "script/RewardDistributor.s.sol";

contract Deploy is Broadcaster, OutputWriter {
    address private _governorAddress;
    address private _rewardTokenAddress;
    address private _stakingTokenAddress;
    address private _kycApproverAddress;
    address private _foundationTreasuryAddress;

    function setUp() public {
        _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        _kycApproverAddress = vm.envAddress("KYC_APPROVER_ADDRESS");
        _foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");

        outputWriterSetup();
    }

    function run() public {
        BuilderGaugeFactory _builderGaugeFactory = new BuilderGaugeFactoryDeployer().run();
        save("BuilderGaugeFactory", address(_builderGaugeFactory));

        (ChangeExecutor _changeExecutorProxy, ChangeExecutor _changeExecutorImpl) =
            new ChangeExecutorDeployer().run(_governorAddress);
        saveWithProxy("ChangeExecutor", address(_changeExecutorImpl), address(_changeExecutorProxy));

        (BuilderRegistry _builderRegistryProxy, BuilderRegistry _builderRegistryImpl) =
            new BuilderRegistryDeployer().run(address(_changeExecutorProxy), _kycApproverAddress);
        saveWithProxy("BuilderRegistry", address(_builderRegistryImpl), address(_builderRegistryProxy));

        (SponsorsManager _sponsorManagerProxy, SponsorsManager _sponsorManagerImpl) = new SponsorsManagerDeployer().run(
            address(_changeExecutorProxy),
            _rewardTokenAddress,
            _stakingTokenAddress,
            address(_builderGaugeFactory),
            address(_builderRegistryImpl)
        );
        saveWithProxy("SponsorsManager", address(_sponsorManagerImpl), address(_sponsorManagerProxy));

        (RewardDistributor _rewardDistributorProxy, RewardDistributor _rewardDistributorImpl) = new RewardDistributorDeployer(
        ).run(address(_changeExecutorProxy), _foundationTreasuryAddress, address(_sponsorManagerProxy));
        saveWithProxy("RewardDistributor", address(_rewardDistributorImpl), address(_rewardDistributorProxy));
    }
}
