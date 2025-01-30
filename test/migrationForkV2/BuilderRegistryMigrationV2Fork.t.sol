// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { BuilderRegistryRootstockCollective } from "../../src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "../../src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { IBackersManagerV1 } from "../../src/interfaces/v1/IBackersManagerV1.sol";
import { GaugeRootstockCollective } from "../../src/gauge/GaugeRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "../../src/gauge/GaugeFactoryRootstockCollective.sol";
import { MigrationV2 } from "../../src/upgrade/MigrationV2.sol";
import { BackersManagerRootstockCollective } from "../../src/backersManager/BackersManagerRootstockCollective.sol";

using EnumerableSet for EnumerableSet.AddressSet;

struct BuilderState {
    bool activated;
    bool kycApproved;
    bool communityApproved;
    bool paused;
    bool revoked;
    bytes7 reserved;
    bytes20 pausedReason;
}

struct RewardPercentageData {
    uint64 previous;
    uint64 next;
    uint128 cooldownEndTime;
}

struct BuilderRegistryData {
    address rewardDistributor;
    mapping(address builder => BuilderState state) builderState;
    mapping(address builder => address rewardReceiver) builderRewardReceiver;
    mapping(address builder => address rewardReceiverReplacement) builderRewardReceiverReplacement;
    mapping(address builder => bool hasRewardReceiverPendingApproval) hasBuilderRewardReceiverPendingApproval;
    mapping(address builder => RewardPercentageData rewardPercentageData) backerRewardPercentage;
    EnumerableSet.AddressSet gauges;
    EnumerableSet.AddressSet haltedGauges;
    GaugeFactoryRootstockCollective gaugeFactory;
    mapping(address builder => GaugeRootstockCollective gauge) builderToGauge;
    mapping(GaugeRootstockCollective gauge => address builder) gaugeToBuilder;
    mapping(GaugeRootstockCollective gauge => uint256 lastPeriodFinish) haltedGaugeLastPeriodFinish;
    uint128 rewardPercentageCooldown;
    BackersManagerRootstockCollective backersManager;
    address[] builders;
}

contract BuilderRegistryMigrationV2Fork is Test {
    address public backersManager;
    IGovernanceManagerRootstockCollective public governanceManager;
    address public upgrader;
    MigrationV2 public migrationV2;
    address public alice;
    BuilderRegistryRootstockCollective public builderRegistry;

    BuilderRegistryData internal _buildersDataV1;

    function setUp() public {
        alice = makeAddr("alice");
        backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        IBackersManagerV1 _backersManagerV1 = IBackersManagerV1(backersManager);
        migrationV2 = new MigrationV2(backersManager);
        governanceManager = _backersManagerV1.governanceManager();
        upgrader = governanceManager.upgrader();

        _storeBuildersV1Data();
    }

    /**
     * SCENARIO: Migrates all builders from V1 to V2
     */
    function test_fork_migrateBuilderRegistryData() public {
        // GIVEN builderRegistry is created and upgrader is set
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        // AND the builders are migrated
        builderRegistry = migrationV2.run();

        // THEM the builderRegistry is set to the migrated builderRegistry
        vm.assertEq(address(builderRegistry), address(migrationV2.builderRegistry()));

        // AND upgrader is set back to the original address after the migration
        vm.assertEq(upgrader, governanceManager.upgrader());

        // AND the migrated data in v2 matches v1 data
        vm.assertEq(_buildersDataV1.builders.length, builderRegistry.getGaugesLength());
        vm.assertEq(_buildersDataV1.gauges.length(), builderRegistry.getGaugesLength());
        vm.assertEq(_buildersDataV1.haltedGauges.length(), builderRegistry.getHaltedGaugesLength());
        vm.assertEq(_buildersDataV1.rewardDistributor, builderRegistry.rewardDistributor());
        vm.assertEq(_buildersDataV1.rewardPercentageCooldown, builderRegistry.rewardPercentageCooldown());
        vm.assertEq(address(_buildersDataV1.gaugeFactory), address(builderRegistry.gaugeFactory()));
        vm.assertEq(address(_buildersDataV1.backersManager), address(builderRegistry.backersManager()));

        for (uint256 i = 0; i < _buildersDataV1.builders.length; i++) {
            _validateBuilderMigration(_buildersDataV1.builders[i]);
        }
    }

    /**
     * SCENARIO: Unauthorized account attempts to migrate a builder
     */
    function test_fork_migrateFromUnauthorizedAccount() public {
        // GIVEN builderRegistry is created and upgrader is set
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        // AND the builders are migrated
        builderRegistry = migrationV2.run();

        // WHEN an unauthorized attempts to call migrateBuilder
        vm.prank(alice);
        // THEN the transaction migrateAllBuildersV2 reverts with NotAuthorizedUpgrader error
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedUpgrader.selector);
        builderRegistry.migrateAllBuildersV2();
    }

    /**
     * SCENARIO: Migrates a paused builder
     */
    function test_fork_migratePausedBuilder() public {
        // GIVEN a builder is paused
        address _builder = _buildersDataV1.builders[0];
        vm.prank(governanceManager.kycApprover());
        IBackersManagerV1(backersManager).pauseBuilder(_builder, bytes20(0));

        // WHEN the builder is migrated
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        builderRegistry = migrationV2.run();

        // THEN the builder is paused in V2
        vm.assertTrue(builderRegistry.isBuilderPaused(_builder));
    }

    /**
     * SCENARIO: Migrates a builder with a pending reward receiver
     */
    function test_fork_migrateBuilderWithPendingRewardReceiver() public {
        // GIVEN a builder has a pending reward receiver
        address _builder = _buildersDataV1.builders[0];
        address _bob = makeAddr("bob");
        vm.prank(_builder);
        IBackersManagerV1(backersManager).submitRewardReceiverReplacementRequest(_bob);

        // WHEN the builder is migrated
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        builderRegistry = migrationV2.run();

        // EN the migrated builder has the pending reward receiver
        vm.assertEq(builderRegistry.builderRewardReceiverReplacement(_builder), _bob);
    }

    /**
     * SCENARIO: Migrates a builder with revoked kyc
     */
    function test_fork_migrateBuilderWithRevokedKyc() public {
        // GIVEN a builder has revoked kyc
        address _builder = _buildersDataV1.builders[0];
        vm.prank(governanceManager.kycApprover());
        IBackersManagerV1(backersManager).revokeBuilderKYC(_builder);

        // WHEN the builder is migrated
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(migrationV2));
        builderRegistry = migrationV2.run();

        // THEN the migrated builder has revoked kyc
        (, bool _kycApprovedV2,,,,,) = builderRegistry.builderState(_builder);
        vm.assertFalse(_kycApprovedV2);
    }

    // -----------------------------------
    // ---- Internal helper functions ----
    // -----------------------------------

    function _storeBuildersV1Data() internal {
        IBackersManagerV1 _backersManagerV1 = IBackersManagerV1(backersManager);
        uint256 _gaugesLength = _backersManagerV1.getGaugesLength();
        _buildersDataV1.rewardDistributor = _backersManagerV1.rewardDistributor();
        _buildersDataV1.rewardPercentageCooldown = _backersManagerV1.rewardPercentageCooldown();
        _buildersDataV1.gaugeFactory = GaugeFactoryRootstockCollective(_backersManagerV1.gaugeFactory());
        _buildersDataV1.backersManager = BackersManagerRootstockCollective(backersManager);

        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _gauge = _backersManagerV1.getGaugeAt(i);
            address _builder = _backersManagerV1.gaugeToBuilder(_gauge);
            _buildersDataV1.builders.push(_builder);
            _buildersDataV1.builderState[_builder] = _getBuilderStateV1(_builder);
            _buildersDataV1.builderRewardReceiver[_builder] = _backersManagerV1.builderRewardReceiver(_builder);
            _buildersDataV1.builderRewardReceiverReplacement[_builder] =
                _backersManagerV1.builderRewardReceiverReplacement(_builder);
            _buildersDataV1.hasBuilderRewardReceiverPendingApproval[_builder] =
                _backersManagerV1.hasBuilderRewardReceiverPendingApproval(_builder);
            _buildersDataV1.backerRewardPercentage[_builder] = _getBackerRewardPercentageData(_builder);
            _buildersDataV1.builderToGauge[_builder] = GaugeRootstockCollective(_gauge);
            _buildersDataV1.gaugeToBuilder[GaugeRootstockCollective(_gauge)] = _builder;
            _buildersDataV1.haltedGaugeLastPeriodFinish[GaugeRootstockCollective(_gauge)] =
                _backersManagerV1.haltedGaugeLastPeriodFinish(_gauge);

            if (_backersManagerV1.isGaugeHalted(_gauge)) {
                _buildersDataV1.haltedGauges.add(_gauge);
            } else {
                _buildersDataV1.gauges.add(_gauge);
            }
        }
    }

    function _getBuilderStateV1(address builder_) internal view returns (BuilderState memory) {
        IBackersManagerV1 _backersManagerV1 = IBackersManagerV1(backersManager);
        (
            bool _activated,
            bool _kycApproved,
            bool _communityApproved,
            bool _paused,
            bool _revoked,
            bytes7 _reserved,
            bytes20 _pausedReason
        ) = _backersManagerV1.builderState(builder_);
        return BuilderState({
            activated: _activated,
            kycApproved: _kycApproved,
            communityApproved: _communityApproved,
            paused: _paused,
            revoked: _revoked,
            reserved: _reserved,
            pausedReason: _pausedReason
        });
    }

    function _getBackerRewardPercentageData(address builder_) internal view returns (RewardPercentageData memory) {
        IBackersManagerV1 _backersManagerV1 = IBackersManagerV1(backersManager);
        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = _backersManagerV1.backerRewardPercentage(builder_);
        return RewardPercentageData({ previous: _previous, next: _next, cooldownEndTime: _cooldownEndTime });
    }

    function _validateBuilderMigration(address builder_) internal view {
        _validateMigratedBuilderState(builder_);
        _validateMigratedBuilderRewardReceiver(builder_);
        _validateMigratedBackerRewardPercentage(builder_);
        _validateMigratedGauge(builder_);
    }

    function _validateMigratedBuilderRewardReceiver(address builder_) internal view {
        vm.assertEq(_buildersDataV1.builderRewardReceiver[builder_], builderRegistry.builderRewardReceiver(builder_));

        // validate builderRewardReceiverReplacement
        bool _hasBuilderRewardReceiverPendingApprovalV1 =
            _buildersDataV1.hasBuilderRewardReceiverPendingApproval[builder_];
        bool _hasBuilderRewardReceiverPendingApprovalV2 =
            builderRegistry.hasBuilderRewardReceiverPendingApproval(builder_);
        vm.assertEq(_hasBuilderRewardReceiverPendingApprovalV1, _hasBuilderRewardReceiverPendingApprovalV2);
    }

    function _validateMigratedBackerRewardPercentage(address builder_) internal view {
        _buildersDataV1.backerRewardPercentage[builder_].previous;
        (uint64 _previousV2, uint64 _nextV2, uint128 _cooldownEndTimeV2) =
            builderRegistry.backerRewardPercentage(builder_);
        vm.assertEq(_buildersDataV1.backerRewardPercentage[builder_].previous, _previousV2);
        vm.assertEq(_buildersDataV1.backerRewardPercentage[builder_].next, _nextV2);
        vm.assertEq(_buildersDataV1.backerRewardPercentage[builder_].cooldownEndTime, _cooldownEndTimeV2);
    }

    function _validateMigratedBuilderState(address builder_) internal view {
        BuilderState memory _builderStateV1 = _buildersDataV1.builderState[builder_];

        (
            bool _activatedV2,
            bool _kycApprovedV2,
            bool _communityApprovedV2,
            bool _pausedV2,
            bool _revokedV2,
            bytes7 _reservedV2,
            bytes20 _pausedReasonV2
        ) = builderRegistry.builderState(builder_);

        vm.assertEq(_builderStateV1.activated, _activatedV2);
        vm.assertEq(_builderStateV1.kycApproved, _kycApprovedV2);
        vm.assertEq(_builderStateV1.communityApproved, _communityApprovedV2);
        vm.assertEq(_builderStateV1.paused, _pausedV2);
        vm.assertEq(_builderStateV1.revoked, _revokedV2);
        vm.assertEq(_builderStateV1.reserved, _reservedV2);
        vm.assertEq(_builderStateV1.pausedReason, _pausedReasonV2);
    }

    function _validateMigratedGauge(address builder_) internal view {
        GaugeRootstockCollective _gaugeV1 = _buildersDataV1.builderToGauge[builder_];
        // validate builderToGauge
        vm.assertEq(address(_gaugeV1), address(builderRegistry.builderToGauge(builder_)));

        // validate gaugeToBuilder
        vm.assertEq(_buildersDataV1.gaugeToBuilder[_gaugeV1], builder_);

        // validate isGaugeHalted
        bool _isGaugeHaltedV1 = _buildersDataV1.haltedGauges.contains(address(_gaugeV1));
        bool _isGaugeHaltedV2 = builderRegistry.isGaugeHalted(address(_gaugeV1));
        vm.assertEq(_isGaugeHaltedV1, _isGaugeHaltedV2);

        if (_isGaugeHaltedV1) {
            vm.assertTrue(_buildersDataV1.haltedGauges.contains(address(_gaugeV1)));
        } else {
            vm.assertTrue(_buildersDataV1.gauges.contains(address(_gaugeV1)));
        }

        // validate haltedGaugeLastPeriodFinish
        uint256 _haltedGaugeLastPeriodFinishV1 = _buildersDataV1.haltedGaugeLastPeriodFinish[_gaugeV1];
        uint256 _haltedGaugeLastPeriodFinishV2 = builderRegistry.haltedGaugeLastPeriodFinish(_gaugeV1);
        vm.assertEq(_haltedGaugeLastPeriodFinishV1, _haltedGaugeLastPeriodFinishV2);

        // validate
    }
}
