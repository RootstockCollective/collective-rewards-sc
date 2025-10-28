// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { UpgradeV3 } from "src/upgrades/UpgradeV3.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";
import { IBackersManagerRootstockCollectiveV2 } from "src/interfaces/v2/IBackersManagerRootstockCollectiveV2.sol";
import { IRewardDistributorRootstockCollectiveV2 } from "src/interfaces/v2/IRewardDistributorRootstockCollectiveV2.sol";

contract UpgradeV3Deployer is Broadcaster, OutputWriter {
    // State variables instead of local variables to avoid stack too deep error
    BackersManagerRootstockCollective private _backersManagerImplV3;
    BuilderRegistryRootstockCollective private _builderRegistryImplV3;
    RewardDistributorRootstockCollective private _rewardDistributorImplV3;
    GovernanceManagerRootstockCollective private _governanceManagerImplV3;
    GaugeRootstockCollective private _gaugeImplV3;
    GaugeFactoryRootstockCollective private _gaugeFactoryV3;

    function run() public returns (UpgradeV3 upgradeV3_) {
        outputWriterSetup();
        address _backersManager = vm.envOr("BackersManagerRootstockCollectiveProxy", address(0));
        address payable _rewardDistributor = payable(vm.envOr("RewardDistributorRootstockCollectiveProxy", address(0)));
        address _configurator = vm.envAddress("CONFIGURATOR_ADDRESS");
        address _usdrifToken = vm.envAddress("USDRIF_TOKEN_ADDRESS");
        address _gaugeBeacon = vm.envAddress("GaugeBeaconRootstockCollective");
        uint256 _maxDistributionsPerBatch = uint256(vm.envUint("MAX_DISTRIBUTION_PER_BATCH"));

        upgradeV3_ = run(
            IBackersManagerRootstockCollectiveV2(_backersManager),
            IRewardDistributorRootstockCollectiveV2(_rewardDistributor),
            _configurator,
            _usdrifToken,
            _gaugeBeacon,
            _maxDistributionsPerBatch,
            true
        );
    }

    function run(
        IBackersManagerRootstockCollectiveV2 backersManagerProxy_,
        IRewardDistributorRootstockCollectiveV2 rewardDistributorProxyV2_,
        address configurator_,
        address usdrifToken_,
        address gaugeBeacon_,
        uint256 maxDistributionsPerBatch_,
        bool writeDeployment_
    )
        public
        broadcast
        returns (UpgradeV3 upgradeV3_)
    {
        require(address(backersManagerProxy_) != address(0), "Backers Manager address cannot be zero");
        require(address(rewardDistributorProxyV2_) != address(0), "Reward distributor address cannot be zero");
        require(configurator_ != address(0), "Configurator address cannot be zero");
        require(usdrifToken_ != address(0), "USDRIF token address cannot be zero");
        require(gaugeBeacon_ != address(0), "Gauge beacon address cannot be zero");
        require(maxDistributionsPerBatch_ > 0, "Max distributions per batch must be greater than 0");

        upgradeV3_ = _deployUpgradeV3(
            backersManagerProxy_,
            rewardDistributorProxyV2_,
            configurator_,
            usdrifToken_,
            gaugeBeacon_,
            maxDistributionsPerBatch_
        );

        if (!writeDeployment_) return upgradeV3_;

        _saveDeployments(upgradeV3_);
    }

    function _deployUpgradeV3(
        IBackersManagerRootstockCollectiveV2 backersManagerProxy_,
        IRewardDistributorRootstockCollectiveV2 rewardDistributorProxyV2_,
        address configurator_,
        address usdrifToken_,
        address gaugeBeacon_,
        uint256 maxDistributionsPerBatch_
    )
        internal
        returns (UpgradeV3 upgradeV3_)
    {
        // Deploy implementations and store in state variables
        _backersManagerImplV3 = new BackersManagerRootstockCollective();
        _builderRegistryImplV3 = new BuilderRegistryRootstockCollective();
        _rewardDistributorImplV3 = new RewardDistributorRootstockCollective();
        _governanceManagerImplV3 = new GovernanceManagerRootstockCollective();
        _gaugeImplV3 = new GaugeRootstockCollective();

        address _rifToken = IBackersManagerRootstockCollectiveV2(backersManagerProxy_).rewardToken();
        _gaugeFactoryV3 = new GaugeFactoryRootstockCollective(gaugeBeacon_, _rifToken, usdrifToken_);

        upgradeV3_ = new UpgradeV3(
            backersManagerProxy_,
            _backersManagerImplV3,
            _builderRegistryImplV3,
            _governanceManagerImplV3,
            _gaugeImplV3,
            rewardDistributorProxyV2_,
            _rewardDistributorImplV3,
            configurator_,
            usdrifToken_,
            _gaugeFactoryV3,
            maxDistributionsPerBatch_
        );
    }

    function _saveDeployments(UpgradeV3 upgradeV3_) internal {
        persistOutputJson();
        save("UpgradeV3", address(upgradeV3_));
        save("BackersManagerRootstockCollective", address(_backersManagerImplV3));
        save("BuilderRegistryRootstockCollective", address(_builderRegistryImplV3));
        save("GovernanceManagerRootstockCollective", address(_governanceManagerImplV3));
        save("RewardDistributorRootstockCollective", address(_rewardDistributorImplV3));
        save("GaugeRootstockCollectiveImplementation", address(_gaugeImplV3));
        save("GaugeFactoryRootstockCollective", address(_gaugeFactoryV3));
    }
}
