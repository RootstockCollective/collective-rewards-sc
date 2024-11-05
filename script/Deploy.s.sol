// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { SponsorsManagerRootstockCollective } from "src/SponsorsManagerRootstockCollective.sol";
import { Deploy as SponsorsManagerRootstockCollectiveDeployer } from "script/SponsorsManagerRootstockCollective.s.sol";
import { GaugeBeaconRootstockCollective } from "src/gauge/GaugeBeaconRootstockCollective.sol";
import { Deploy as GaugeBeaconRootstockCollectiveDeployer } from "script/gauge/GaugeBeaconRootstockCollective.s.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";
import { Deploy as GaugeFactoryRootstockCollectiveDeployer } from "script/gauge/GaugeFactoryRootstockCollective.s.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";
import { Deploy as RewardDistributorRootstockCollectiveDeployer } from
    "script/RewardDistributorRootstockCollective.s.sol";
import { Deploy as GovernanceManagerRootstockCollectiveDeployer } from
    "script/governance/GovernanceManagerRootstockCollective.s.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";

contract Deploy is Broadcaster, OutputWriter {
    address private _rewardTokenAddress;
    address private _stakingTokenAddress;
    address private _kycApproverAddress;
    address private _foundationTreasuryAddress;
    uint32 private _cycleDuration;
    uint24 private _cycleStartOffset;
    uint128 private _rewardPercentageCooldown;

    function setUp() public {
        _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        _foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        _cycleDuration = uint32(vm.envUint("CYCLE_DURATION"));
        _cycleStartOffset = uint24(vm.envUint("CYCLE_START_OFFSET"));
        _rewardPercentageCooldown = uint128(vm.envUint("REWARD_PERCENTAGE_COOLDOWN"));

        outputWriterSetup();
    }

    function run() public {
        (
            GovernanceManagerRootstockCollective _governanceManagerProxy,
            GovernanceManagerRootstockCollective _governanceManagerImpl
        ) = new GovernanceManagerRootstockCollectiveDeployer().run();
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

        (
            SponsorsManagerRootstockCollective _sponsorManagerProxy,
            SponsorsManagerRootstockCollective _sponsorManagerImpl
        ) = new SponsorsManagerRootstockCollectiveDeployer().run(
            address(_governanceManagerProxy),
            _rewardTokenAddress,
            _stakingTokenAddress,
            address(_gaugeFactory),
            address(_rewardDistributorProxy),
            _cycleDuration,
            _cycleStartOffset,
            _rewardPercentageCooldown
        );
        saveWithProxy("SponsorsManagerRootstockCollective", address(_sponsorManagerImpl), address(_sponsorManagerProxy));

        _rewardDistributorProxy.initializeCollectiveRewardsAddresses(address(_sponsorManagerProxy));
    }
}
