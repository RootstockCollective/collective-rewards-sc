// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { Deploy as BackersManagerRootstockCollectiveDeployer } from "script/BackersManagerRootstockCollective.s.sol";
import { Deploy as BuilderRegistryRootstockCollectiveDeployer } from "script/BuilderRegistryRootstockCollective.s.sol";
import { GaugeBeaconRootstockCollective } from "src/gauge/GaugeBeaconRootstockCollective.sol";
import { Deploy as GaugeBeaconRootstockCollectiveDeployer } from "script/gauge/GaugeBeaconRootstockCollective.s.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";
import { Deploy as GaugeFactoryRootstockCollectiveDeployer } from "script/gauge/GaugeFactoryRootstockCollective.s.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";
import { Deploy as RewardDistributorRootstockCollectiveDeployer } from
    "script/RewardDistributorRootstockCollective.s.sol";
import { Deploy as GovernanceManagerRootstockCollectiveDeployer } from
    "script/governance/GovernanceManagerRootstockCollective.s.sol";

contract Deploy is Broadcaster, OutputWriter {
    address private _rewardTokenAddress;
    address private _usdrifRewardTokenAddress;
    address private _stakingTokenAddress;
    address private _kycApproverAddress;
    address private _governorAddress;
    address private _foundationTreasuryAddress;
    address private _upgrader;
    uint32 private _cycleDuration;
    uint24 private _cycleStartOffset;
    uint32 private _distributionDuration;
    uint128 private _rewardPercentageCooldown;
    uint256 private _maxDistributionsPerBatch;

    function setUp() public {
        _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        _usdrifRewardTokenAddress = vm.envAddress("USDRIF_REWARD_TOKEN_ADDRESS");
        _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        _foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        _kycApproverAddress = vm.envAddress("KYC_APPROVER_ADDRESS");
        _upgrader = vm.envAddress("UPGRADER_ADDRESS");
        _cycleDuration = uint32(vm.envUint("CYCLE_DURATION"));
        _cycleStartOffset = uint24(vm.envUint("CYCLE_START_OFFSET"));
        _distributionDuration = uint32(vm.envUint("DISTRIBUTION_DURATION"));
        _rewardPercentageCooldown = uint128(vm.envUint("REWARD_PERCENTAGE_COOLDOWN"));
        _maxDistributionsPerBatch = uint256(vm.envUint("MAX_DISTRIBUTION_PER_BATCH"));

        outputWriterSetup();
    }

    function run() public {
        (
            GovernanceManagerRootstockCollective _governanceManagerProxy,
            GovernanceManagerRootstockCollective _governanceManagerImpl
        ) = new GovernanceManagerRootstockCollectiveDeployer().run(
            _governorAddress, _foundationTreasuryAddress, _kycApproverAddress, _upgrader
        );
        saveWithProxy(
            "GovernanceManagerRootstockCollective", address(_governanceManagerImpl), address(_governanceManagerProxy)
        );

        GaugeBeaconRootstockCollective _gaugeBeacon =
            new GaugeBeaconRootstockCollectiveDeployer().run(address(_governanceManagerProxy));
        save("GaugeBeaconRootstockCollective", address(_gaugeBeacon));

        GaugeFactoryRootstockCollective _gaugeFactory =
            new GaugeFactoryRootstockCollectiveDeployer().run(address(_gaugeBeacon), _rewardTokenAddress);
        save("GaugeFactoryRootstockCollective", address(_gaugeFactory));

        (
            RewardDistributorRootstockCollective _rewardDistributorProxy,
            RewardDistributorRootstockCollective _rewardDistributorImpl
        ) = new RewardDistributorRootstockCollectiveDeployer().run(address(_governanceManagerProxy));
        saveWithProxy(
            "RewardDistributorRootstockCollective", address(_rewardDistributorImpl), address(_rewardDistributorProxy)
        );

        (BackersManagerRootstockCollective _backersManagerProxy, BackersManagerRootstockCollective _backersManagerImpl)
        = new BackersManagerRootstockCollectiveDeployer().run(
            address(_governanceManagerProxy),
            _rewardTokenAddress,
            _stakingTokenAddress,
            _cycleDuration,
            _cycleStartOffset,
            _distributionDuration
        );
        saveWithProxy("BackersManagerRootstockCollective", address(_backersManagerImpl), address(_backersManagerProxy));

        (
            BuilderRegistryRootstockCollective _builderRegistryProxy,
            BuilderRegistryRootstockCollective _builderRegistryImpl
        ) = new BuilderRegistryRootstockCollectiveDeployer().run(
            address(_backersManagerProxy),
            address(_gaugeFactory),
            address(_rewardDistributorProxy),
            _rewardPercentageCooldown
        );
        saveWithProxy(
            "BuilderRegistryRootstockCollective", address(_builderRegistryImpl), address(_builderRegistryProxy)
        );

        vm.startBroadcast();

        _backersManagerProxy.initializeBuilderRegistry(_builderRegistryProxy);
        _backersManagerProxy.initializeV3(_maxDistributionsPerBatch, _usdrifRewardTokenAddress);

        _rewardDistributorProxy.initializeCollectiveRewardsAddresses(address(_backersManagerProxy));

        vm.stopBroadcast();
    }
}
