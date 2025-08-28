// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { UpgradeV3 } from "src/upgrades/UpgradeV3.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";

contract UpgradeV3Deployer is Broadcaster, OutputWriter {
    function run() public returns (UpgradeV3 upgradeV3_) {
        outputWriterSetup();
        address _backersManager = vm.envOr("BackersManagerRootstockCollectiveProxy", address(0));
        address payable _rewardDistributor = payable(vm.envOr("RewardDistributorRootstockCollectiveProxy", address(0)));
        address _configurator = vm.envAddress("CONFIGURATOR_ADDRESS");
        address _usdrifToken = vm.envAddress("USDRIF_TOKEN_ADDRESS");

        upgradeV3_ = run(
            BackersManagerRootstockCollective(_backersManager),
            RewardDistributorRootstockCollective(_rewardDistributor),
            _configurator,
            _usdrifToken,
            true
        );
    }

    function run(
        BackersManagerRootstockCollective backersManagerProxy_,
        RewardDistributorRootstockCollective rewardDistributorProxy_,
        address configurator_,
        address usdrifToken_,
        bool writeDeployment_
    )
        public
        broadcast
        returns (UpgradeV3 upgradeV3_)
    {
        require(address(backersManagerProxy_) != address(0), "Backers Manager address cannot be zero");
        require(address(rewardDistributorProxy_) != address(0), "Reward distributor address cannot be zero");
        require(configurator_ != address(0), "Configurator address cannot be zero");
        require(usdrifToken_ != address(0), "USDRIF token address cannot be zero");

        BackersManagerRootstockCollective _backersManagerImplV3 = new BackersManagerRootstockCollective();
        BuilderRegistryRootstockCollective _builderRegistryImplV3 = new BuilderRegistryRootstockCollective();
        RewardDistributorRootstockCollective _rewardDistributorImplV3 = new RewardDistributorRootstockCollective();
        GovernanceManagerRootstockCollective _governanceManagerImplV3 = new GovernanceManagerRootstockCollective();
        GaugeRootstockCollective _gaugeImplV3 = new GaugeRootstockCollective();

        upgradeV3_ = new UpgradeV3(
            backersManagerProxy_,
            _backersManagerImplV3,
            _builderRegistryImplV3,
            _governanceManagerImplV3,
            _gaugeImplV3,
            rewardDistributorProxy_,
            _rewardDistributorImplV3,
            configurator_,
            usdrifToken_
        );

        if (!writeDeployment_) return upgradeV3_;

        persistOutputJson();
        save("UpgradeV3", address(upgradeV3_));
        save("BackersManagerRootstockCollective", address(_backersManagerImplV3));
        save("BuilderRegistryRootstockCollective", address(_builderRegistryImplV3));
        save("GovernanceManagerRootstockCollective", address(_governanceManagerImplV3));
        save("RewardDistributorRootstockCollective", address(_rewardDistributorImplV3));
        save("GaugeRootstockCollectiveImplementation", address(_gaugeImplV3));
    }
}
