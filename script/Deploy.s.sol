// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Broadcaster } from "script/script_utils/Broadcaster.s.sol";
import { OutputWriter } from "script/script_utils/OutputWriter.s.sol";
import { ChangeExecutorRootstockCollective } from "src/governance/ChangeExecutorRootstockCollective.sol";
import { Deploy as ChangeExecutorDeployerRootstockCollective } from
    "script/governance/ChangeExecutorRootstockCollective.s.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { GaugeBeacon } from "src/gauge/GaugeBeacon.sol";
import { Deploy as GaugeBeaconDeployer } from "script/gauge/GaugeBeacon.s.sol";
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
    uint32 private _epochDuration;
    uint24 private _epochStartOffset;
    uint128 private _kickbackCooldown;

    function setUp() public {
        _governorAddress = vm.envAddress("GOVERNOR_ADDRESS");
        _rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        _stakingTokenAddress = vm.envAddress("STAKING_TOKEN_ADDRESS");
        _kycApproverAddress = vm.envAddress("KYC_APPROVER_ADDRESS");
        _foundationTreasuryAddress = vm.envAddress("FOUNDATION_TREASURY_ADDRESS");
        _epochDuration = uint32(vm.envUint("EPOCH_DURATION"));
        _epochStartOffset = uint24(vm.envUint("EPOCH_START_OFFSET"));
        _kickbackCooldown = uint128(vm.envUint("KICKBACK_COOLDOWN"));

        outputWriterSetup();
    }

    function run() public {
        (ChangeExecutorRootstockCollective _changeExecutorProxy, ChangeExecutorRootstockCollective _changeExecutorImpl)
        = new ChangeExecutorDeployerRootstockCollective().run(_governorAddress);
        saveWithProxy("ChangeExecutorRootstockCollective", address(_changeExecutorImpl), address(_changeExecutorProxy));

        GaugeBeacon _gaugeBeacon = new GaugeBeaconDeployer().run(address(_changeExecutorProxy));
        save("GaugeBeacon", address(_gaugeBeacon));

        GaugeFactory _gaugeFactory = new GaugeFactoryDeployer().run(address(_gaugeBeacon), _rewardTokenAddress);
        save("GaugeFactory", address(_gaugeFactory));

        (RewardDistributor _rewardDistributorProxy, RewardDistributor _rewardDistributorImpl) =
            new RewardDistributorDeployer().run(address(_changeExecutorProxy), _foundationTreasuryAddress);
        saveWithProxy("RewardDistributor", address(_rewardDistributorImpl), address(_rewardDistributorProxy));

        (SponsorsManager _sponsorManagerProxy, SponsorsManager _sponsorManagerImpl) = new SponsorsManagerDeployer().run(
            address(_changeExecutorProxy),
            _kycApproverAddress,
            _rewardTokenAddress,
            _stakingTokenAddress,
            address(_gaugeFactory),
            address(_rewardDistributorProxy),
            _epochDuration,
            _epochStartOffset,
            _kickbackCooldown
        );
        saveWithProxy("SponsorsManager", address(_sponsorManagerImpl), address(_sponsorManagerProxy));

        _rewardDistributorProxy.initializeBIMAddresses(address(_sponsorManagerProxy));
    }
}
