// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { IBackersManagerV1 } from "src/interfaces/V1/IBackersManagerV1.sol";
import { MigrationV2 } from "src/migrations/v2/MigrationV2.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { MigrationV2Deployer } from "script/migrations/v2/MigrationV2.s.sol";

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
    address public constant COINBASE_ADDRESS = address(uint160(uint256(keccak256("COINBASE_ADDRESS"))));
    IBackersManagerV1 public backersManagerV1;
    IGovernanceManagerRootstockCollective public governanceManager;
    BuilderRegistryRootstockCollective public builderRegistry;
    MigrationV2 public migrationV2;
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

        MigrationV2Deployer _migrationV2Deployer = new MigrationV2Deployer();
        migrationV2 = _migrationV2Deployer.run(_backersManager, false);
        vm.prank(governanceManager.upgrader());
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
        vm.assertEq(gaugesDataV1[gauge_].backersManager, address(_gaugeV2.backersManager()));

        // Validate total allocation
        vm.assertEq(gaugesDataV1[gauge_].totalAllocation, _gaugeV2.totalAllocation());

        // Validate reward shares
        vm.assertEq(gaugesDataV1[gauge_].rewardShares, _gaugeV2.rewardShares());

        // Validate allocation of backer
        vm.assertEq(gaugesDataV1[gauge_].allocationOf[backer], _gaugeV2.allocationOf(backer));

        // Validate reward data
        _validateRewardData(gaugesDataV1[gauge_].rewardToken, _gaugeV2);
        _validateRewardData(COINBASE_ADDRESS, _gaugeV2);
    }

    function _validateRewardData(address rewardToken_, GaugeRootstockCollective gauge_) internal view {
        RewardData storage _rewardData = gaugesDataV1[gauge_].rewardData[rewardToken_];
        vm.assertEq(_rewardData.rewardRate, gauge_.rewardRate(rewardToken_));
        vm.assertEq(_rewardData.rewardPerTokenStored, gauge_.rewardPerTokenStored(rewardToken_));
        vm.assertEq(_rewardData.rewardMissing, gauge_.rewardMissing(rewardToken_));
        vm.assertEq(_rewardData.lastUpdateTime, gauge_.lastUpdateTime(rewardToken_));
        vm.assertEq(_rewardData.builderRewards, gauge_.builderRewards(rewardToken_));
        vm.assertEq(_rewardData.backerRewardPerTokenPaid[backer], gauge_.backerRewardPerTokenPaid(rewardToken_, backer));
        vm.assertEq(_rewardData.rewards[backer], gauge_.rewards(rewardToken_, backer));
    }

    function _setGaugesDataV1() internal {
        for (uint256 i = 0; i < gauges.length; i++) {
            GaugeRootstockCollective _gaugeV1 = GaugeRootstockCollective(gauges[i]);
            gaugesDataV1[_gaugeV1].backersManager = address(backersManagerV1);
            gaugesDataV1[_gaugeV1].totalAllocation = _gaugeV1.totalAllocation();
            gaugesDataV1[_gaugeV1].rewardShares = _gaugeV1.rewardShares();
            gaugesDataV1[_gaugeV1].allocationOf[backer] = _gaugeV1.allocationOf(backer);

            address _rewardToken = _gaugeV1.rewardToken();
            gaugesDataV1[_gaugeV1].rewardToken = _rewardToken;
            _setRewardData(_gaugeV1, _rewardToken);

            _setRewardData(_gaugeV1, COINBASE_ADDRESS);
        }
    }

    function _setRewardData(GaugeRootstockCollective gaugeV1_, address rewardToken_) internal {
        gaugesDataV1[gaugeV1_].rewardData[rewardToken_].rewardRate = gaugeV1_.rewardRate(rewardToken_);
        gaugesDataV1[gaugeV1_].rewardData[rewardToken_].rewardPerTokenStored =
            gaugeV1_.rewardPerTokenStored(rewardToken_);
        gaugesDataV1[gaugeV1_].rewardData[rewardToken_].rewardMissing = gaugeV1_.rewardMissing(rewardToken_);
        gaugesDataV1[gaugeV1_].rewardData[rewardToken_].lastUpdateTime = gaugeV1_.lastUpdateTime(rewardToken_);
        gaugesDataV1[gaugeV1_].rewardData[rewardToken_].builderRewards = gaugeV1_.builderRewards(rewardToken_);
        gaugesDataV1[gaugeV1_].rewardData[rewardToken_].backerRewardPerTokenPaid[backer] =
            gaugeV1_.backerRewardPerTokenPaid(rewardToken_, backer);
        gaugesDataV1[gaugeV1_].rewardData[rewardToken_].rewards[backer] = gaugeV1_.rewards(rewardToken_, backer);
    }
}
