// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { console } from "forge-std/src/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";
import { Deploy as ChangeExecutorDeployer } from "script/governance/ChangeExecutor.s.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";
import { Deploy as BuilderRegistryDeployer } from "script/BuilderRegistry.s.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";
import { Deploy as GaugeFactoryDeployer } from "script/gauge/GaugeFactory.s.sol";
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
        GaugeFactory gaugeFactory = new GaugeFactoryDeployer().run();
        save("GaugeFactory", address(gaugeFactory));

        ChangeExecutor changeExecutor = new ChangeExecutorDeployer().run(_governorAddress);
        save("ChangeExecutor", address(changeExecutor));

        BuilderRegistry builderRegistry =
            new BuilderRegistryDeployer().run(address(changeExecutor), _kycApproverAddress);
        save("BuilderRegistry", address(builderRegistry));

        SponsorsManager sponsorManager = new SponsorsManagerDeployer().run(
            address(changeExecutor),
            _rewardTokenAddress,
            _stakingTokenAddress,
            address(gaugeFactory),
            address(builderRegistry)
        );
        save("SponsorsManager", address(sponsorManager));

        RewardDistributor rewardDistributor = new RewardDistributorDeployer().run(
            address(changeExecutor), _foundationTreasuryAddress, address(sponsorManager)
        );
        save("RewardDistributor", address(rewardDistributor));
    }
}
