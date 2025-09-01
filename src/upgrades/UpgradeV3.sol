// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";
import { GaugeBeaconRootstockCollective } from "../gauge/GaugeBeaconRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "../gauge/GaugeFactoryRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "../builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "../backersManager/BackersManagerRootstockCollective.sol";
import { GovernanceManagerRootstockCollective } from "../governance/GovernanceManagerRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "../RewardDistributorRootstockCollective.sol";
import { IBackersManagerRootstockCollectiveV2 } from "src/interfaces/v2/IBackersManagerRootstockCollectiveV2.sol";
import { IRewardDistributorRootstockCollectiveV2 } from "src/interfaces/v2/IRewardDistributorRootstockCollectiveV2.sol";
/**
 * @title UpgradeV3
 * @notice Migrate the mainnet live contracts to V3
 */

contract UpgradeV3 {
    error NotUpgrader();

    IBackersManagerRootstockCollectiveV2 public backersManagerProxyV2;
    BackersManagerRootstockCollective public backersManagerImplV3;
    BuilderRegistryRootstockCollective public builderRegistryProxy;
    BuilderRegistryRootstockCollective public builderRegistryImplV3;
    GovernanceManagerRootstockCollective public governanceManagerProxy;
    GovernanceManagerRootstockCollective public governanceManagerImplV3;
    GaugeBeaconRootstockCollective public gaugeBeacon;
    GaugeRootstockCollective public gaugeImplV3;
    IRewardDistributorRootstockCollectiveV2 public rewardDistributorProxy;
    RewardDistributorRootstockCollective public rewardDistributorImplV3;
    GaugeFactoryRootstockCollective public gaugeFactoryV3;
    address public upgrader;
    address public configurator;
    address public usdrifToken;
    uint256 public constant MAX_DISTRIBUTIONS_PER_BATCH = 20;

    constructor(
        IBackersManagerRootstockCollectiveV2 backersManagerProxyV2_,
        BackersManagerRootstockCollective backersManagerImplV3_,
        BuilderRegistryRootstockCollective builderRegistryImplV3_,
        GovernanceManagerRootstockCollective governanceManagerImplV3_,
        GaugeRootstockCollective gaugeImplV3_,
        IRewardDistributorRootstockCollectiveV2 rewardDistributorProxyV2_,
        RewardDistributorRootstockCollective rewardDistributorImplV3_,
        address configurator_,
        address usdrifToken_,
        GaugeFactoryRootstockCollective gaugeFactoryV3_
    ) {
        backersManagerProxyV2 = backersManagerProxyV2_;
        backersManagerImplV3 = backersManagerImplV3_;
        builderRegistryProxy = BuilderRegistryRootstockCollective(backersManagerProxyV2_.builderRegistry());
        builderRegistryImplV3 = builderRegistryImplV3_;
        governanceManagerProxy =
            GovernanceManagerRootstockCollective(address(backersManagerProxyV2_.governanceManager()));
        governanceManagerImplV3 = governanceManagerImplV3_;
        gaugeBeacon = GaugeBeaconRootstockCollective(
            GaugeFactoryRootstockCollective(builderRegistryProxy.gaugeFactory()).beacon()
        );
        gaugeImplV3 = gaugeImplV3_;
        rewardDistributorProxy = rewardDistributorProxyV2_;
        rewardDistributorImplV3 = rewardDistributorImplV3_;
        gaugeFactoryV3 = gaugeFactoryV3_;
        upgrader = governanceManagerProxy.upgrader();
        configurator = configurator_;
        usdrifToken = usdrifToken_;
    }

    function run() public {
        if (governanceManagerProxy.upgrader() != address(this)) revert NotUpgrader();

        _upgradeBackersManager();
        _upgradeBuilderRegistry();
        _upgradeGovernanceManager();
        _upgradeGauges();
        _upgradeRewardDistributor();

        _resetUpgrader();
    }

    /**
     * @notice Resets the upgrader role back to the original address
     * @dev reverts if not called by the original upgrader
     * @dev Prevents this contract from being permanently stuck with the upgrader role if upgrades are no longer needed
     */
    function resetUpgrader() public {
        if (msg.sender != upgrader) revert NotUpgrader();
        _resetUpgrader();
    }

    function _upgradeBackersManager() internal {
        bytes memory _backersManagerInitializeData =
            abi.encodeCall(BackersManagerRootstockCollective.initializeV3, (MAX_DISTRIBUTIONS_PER_BATCH, usdrifToken));

        backersManagerProxyV2.upgradeToAndCall(address(backersManagerImplV3), _backersManagerInitializeData);
    }

    function _upgradeGovernanceManager() internal {
        bytes memory _governanceManagerInitializeData =
            abi.encodeCall(GovernanceManagerRootstockCollective.initializeV3, (configurator));

        governanceManagerProxy.upgradeToAndCall(address(governanceManagerImplV3), _governanceManagerInitializeData);
    }

    function _upgradeBuilderRegistry() internal {
        bytes memory _data = abi.encodeCall(BuilderRegistryRootstockCollective.initializeV3, (gaugeFactoryV3));
        builderRegistryProxy.upgradeToAndCall(address(builderRegistryImplV3), _data);
    }

    function _upgradeGauges() internal {
        gaugeBeacon.upgradeTo(address(gaugeImplV3));

        // Initialize gauges with usdrifToken
        uint256 _gaugesLength = builderRegistryProxy.getGaugesLength();
        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _gaugeAddress = builderRegistryProxy.getGaugeAt(i);
            GaugeRootstockCollective(_gaugeAddress).initializeV3(usdrifToken);
        }

        // Initialize halted gauges with usdrifToken
        uint256 _haltedGaugesLength = builderRegistryProxy.getHaltedGaugesLength();
        for (uint256 i = 0; i < _haltedGaugesLength; i++) {
            address _gaugeAddress = builderRegistryProxy.getHaltedGaugeAt(i);
            GaugeRootstockCollective(_gaugeAddress).initializeV3(usdrifToken);
        }
    }

    function _upgradeRewardDistributor() internal {
        bytes memory _data = abi.encodeCall(RewardDistributorRootstockCollective.initializeUsdrifToken, ());
        rewardDistributorProxy.upgradeToAndCall(address(rewardDistributorImplV3), _data);
    }

    function _resetUpgrader() internal {
        // Reset upgrader role back to the original address
        governanceManagerProxy.updateUpgrader(upgrader);
    }
}
