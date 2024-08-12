// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { console } from "forge-std/src/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";
import { Deploy as ChangeExecutorDeployer } from "script/governance/ChangeExecutor.s.sol";
import { SupportHub } from "src/SupportHub.sol";
import { Deploy as SupportHubDeployer } from "script/SupportHub.s.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";
import { Deploy as BuilderRegistryDeployer } from "script/BuilderRegistry.s.sol";
import { BuilderGaugeFactory } from "src/builder/BuilderGaugeFactory.sol";
import { Deploy as GaugeFactoryDeployer } from "script/builder/BuilderGaugeFactory.s.sol";
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

        _outputWriterSetup();
    }

    function run() public {
        BuilderGaugeFactory builderGaugeFactory = new GaugeFactoryDeployer().run();
        save("BuilderGaugeFactory", address(builderGaugeFactory));

        (ChangeExecutor changeExecutorProxy, ChangeExecutor changeExecutorImpl) =
            new ChangeExecutorDeployer().run(_governorAddress);
        saveWithProxy("ChangeExecutor", address(changeExecutorImpl), address(changeExecutorProxy));

        (BuilderRegistry builderRegistryProxy, BuilderRegistry builderRegistryImpl) =
            new BuilderRegistryDeployer().run(address(changeExecutorImpl), _kycApproverAddress);
        saveWithProxy("BuilderRegistry", address(builderRegistryImpl), address(builderRegistryProxy));

        (SupportHub supporterHubProxy, SupportHub supporterHubImpl) = new SupportHubDeployer().run(
            address(changeExecutorImpl),
            _rewardTokenAddress,
            _stakingTokenAddress,
            address(builderGaugeFactory),
            address(builderRegistryImpl)
        );
        saveWithProxy("SupportHub", address(supporterHubImpl), address(supporterHubProxy));

        (RewardDistributor rewardDistributorProxy, RewardDistributor rewardDistributorImpl) = new RewardDistributorDeployer(
        ).run(address(changeExecutorImpl), _foundationTreasuryAddress, address(supporterHubImpl));
        saveWithProxy("RewardDistributor", address(rewardDistributorImpl), address(rewardDistributorProxy));
    }
}
