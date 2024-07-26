// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { console } from "forge-std/src/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";
import { Deploy as BuilderRegistryDeployer } from "script/BuilderRegistry.s.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";
import { Deploy as GaugeFactoryDeployer } from "script/gauge/GaugeFactory.s.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { Deploy as RewardDistributorDeployer } from "script/RewardDistributor.s.sol";

contract Deploy is Broadcaster, OutputWriter {
    function setUp() public {
        _outputWriterSetup();
    }

    function run() public {
        address gaugeFactory = address(new GaugeFactoryDeployer().run());
        save("GaugeFactory", gaugeFactory);

        address governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        address changeExecutorAddress = vm.envAddress("CHANGE_EXECUTOR_ADDRESS");
        address rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");

        SponsorsManager sponsorManager = new SponsorsManagerDeployer().run(
            governorAddress, changeExecutorAddress, rewardTokenAddress, stakingTokenAddress, gaugeFactory
        );
        save("SponsorsManager", address(sponsorManager));

        address kycApproverAddress = vm.envAddress("KYC_APPROVER_ADDRESS");
        BuilderRegistry builderRegistry =
            new BuilderRegistryDeployer().run(governorAddress, changeExecutorAddress, kycApproverAddress);
        save("BuilderRegistry", address(builderRegistry));

        address foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        RewardDistributor rewardDistributor =
            new RewardDistributorDeployer().run(foundationTreasuryAddress, rewardTokenAddress, address(sponsorManager));
        save("RewardDistributor", address(rewardDistributor));
    }
}
