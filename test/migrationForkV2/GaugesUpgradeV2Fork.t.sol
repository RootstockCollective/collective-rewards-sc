// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { IGovernanceManagerRootstockCollective } from "../../src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { IBackersManagerV1 } from "../../src/interfaces/v1/IBackersManagerV1.sol";
import { MigrationV2 } from "../../src/upgrade/MigrationV2.sol";
import { BuilderRegistryRootstockCollective } from "../../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { GaugeRootstockCollective } from "../../src/gauge/GaugeRootstockCollective.sol";

struct RewardData {
    uint256 rewardRate;
    uint256 rewardPerTokenStored;
    uint256 rewardMissing;
    uint256 lastUpdateTime;
    uint256 builderRewards;
    mapping(address backer => uint256 rewardPerTokenPaid) backerRewardPerTokenPaid;
    mapping(address backer => uint256 rewards) rewards;
}

struct GaugesData {
    address rewardToken;
    address backersManager;
    uint256 totalAllocation;
    uint256 rewardShares;
    mapping(address backer => uint256 allocation) allocationOf;
    mapping(address rewardToken => RewardData rewardData) rewardData;
}

contract GaugesUpgradeV2Fork is Test {
    IBackersManagerV1 public backersManagerV1;
    IGovernanceManagerRootstockCollective public governanceManager;
    MigrationV2 public migrationV2;
    BuilderRegistryRootstockCollective public builderRegistry;
    address public upgrader;
    address public backer = 0xb0F0D0e27BF82236E01d8FaB590b46A470F45cfF;

    address[] public gauges;
    mapping(GaugeRootstockCollective gauge => GaugesData dataV1) public gaugesDataV1;

    function setUp() public {
        address _backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        backersManagerV1 = IBackersManagerV1(_backersManager);
        governanceManager = backersManagerV1.governanceManager();

        uint256 _gaugesLength = backersManagerV1.getGaugesLength();
        for (uint256 i = 0; i < _gaugesLength; i++) {
            gauges.push(backersManagerV1.getGaugeAt(i));
        }

        _setGaugesDataV1();

        migrationV2 = new MigrationV2(_backersManager);

        // Migrate to V2
        upgrader = governanceManager.upgrader();
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        builderRegistry = migrationV2.run();
    }

    /**
     * SCENARIO: Gauges are migrated to V2 and initialized
     */
    function test_fork_migrateGaugesToV2() public view {
        vm.assertEq(gauges.length, builderRegistry.getGaugesLength());
        for (uint256 i = 0; i < gauges.length; i++) {
            GaugeRootstockCollective _gauge = GaugeRootstockCollective(gauges[i]);
            _validateGaugeMigration(_gauge);
        }
    }

    function _validateGaugeMigration(GaugeRootstockCollective gauge_) internal view {
        GaugeRootstockCollective _gaugeV2 = GaugeRootstockCollective(gauge_);

        // Validate reward token
        vm.assertEq(gaugesDataV1[gauge_].rewardToken, _gaugeV2.rewardToken());

        // Validate backers manager
        vm.assertEq(gaugesDataV1[gauge_].backersManager, address(backersManagerV1));

        // Validate total allocation
        vm.assertEq(gaugesDataV1[gauge_].totalAllocation, _gaugeV2.totalAllocation());

        // Validate reward shares
        vm.assertEq(gaugesDataV1[gauge_].rewardShares, _gaugeV2.rewardShares());

        // Validate allocation of backer
        vm.assertEq(gaugesDataV1[gauge_].allocationOf[backer], _gaugeV2.allocationOf(backer));

        // Validate reward data
        _validateRewardData(gaugesDataV1[gauge_].rewardData[gaugesDataV1[gauge_].rewardToken], _gaugeV2);
    }

    function _validateRewardData(RewardData storage rewardData_, GaugeRootstockCollective gauge_) internal view {
        address _rewardToken = gaugesDataV1[gauge_].rewardToken;
        vm.assertEq(rewardData_.rewardRate, gauge_.rewardRate(_rewardToken));
        vm.assertEq(rewardData_.rewardPerTokenStored, gauge_.rewardPerTokenStored(_rewardToken));
        vm.assertEq(rewardData_.rewardMissing, gauge_.rewardMissing(_rewardToken));
        vm.assertEq(rewardData_.lastUpdateTime, gauge_.lastUpdateTime(_rewardToken));
        vm.assertEq(rewardData_.builderRewards, gauge_.builderRewards(_rewardToken));
        vm.assertEq(rewardData_.backerRewardPerTokenPaid[backer], gauge_.backerRewardPerTokenPaid(_rewardToken, backer));
        vm.assertEq(rewardData_.rewards[backer], gauge_.rewards(_rewardToken, backer));
    }

    function _setGaugesDataV1() internal {
        for (uint256 i = 0; i < gauges.length; i++) {
            GaugeRootstockCollective _gaugeV1 = GaugeRootstockCollective(gauges[i]);
            address _rewardToken = _gaugeV1.rewardToken();
            gaugesDataV1[_gaugeV1].rewardToken = _rewardToken;
            gaugesDataV1[_gaugeV1].backersManager = address(backersManagerV1);
            gaugesDataV1[_gaugeV1].totalAllocation = _gaugeV1.totalAllocation();
            gaugesDataV1[_gaugeV1].rewardShares = _gaugeV1.rewardShares();
            gaugesDataV1[_gaugeV1].allocationOf[backer] = _gaugeV1.allocationOf(backer);

            gaugesDataV1[_gaugeV1].rewardData[_rewardToken].rewardRate = _gaugeV1.rewardRate(_rewardToken);
            gaugesDataV1[_gaugeV1].rewardData[_rewardToken].rewardPerTokenStored =
                _gaugeV1.rewardPerTokenStored(_rewardToken);
            gaugesDataV1[_gaugeV1].rewardData[_rewardToken].rewardMissing = _gaugeV1.rewardMissing(_rewardToken);
            gaugesDataV1[_gaugeV1].rewardData[_rewardToken].lastUpdateTime = _gaugeV1.lastUpdateTime(_rewardToken);
            gaugesDataV1[_gaugeV1].rewardData[_rewardToken].builderRewards = _gaugeV1.builderRewards(_rewardToken);
            gaugesDataV1[_gaugeV1].rewardData[_rewardToken].backerRewardPerTokenPaid[backer] =
                _gaugeV1.backerRewardPerTokenPaid(_rewardToken, backer);
            gaugesDataV1[_gaugeV1].rewardData[_rewardToken].rewards[backer] = _gaugeV1.rewards(_rewardToken, backer);
        }
    }
}
