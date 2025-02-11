// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { IBackersManagerV1 } from "src/interfaces/V1/IBackersManagerV1.sol";
import { MigrationV2 } from "src/migrations/v2/MigrationV2.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { MigrationV2Deployer } from "script/migrations/v2/MigrationV2.s.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";

struct CycleData {
    uint32 previousDuration;
    uint32 nextDuration;
    uint64 previousStart;
    uint64 nextStart;
    uint24 offset;
}

struct BackersManagerData {
    // GovernanceManager data
    IGovernanceManagerRootstockCollective governanceManager;
    // CycleTimeKeeper data
    CycleData cycleData;
    uint32 distributionDuration;
    // BackersManager data
    address stakingToken;
    address rewardToken;
    uint256 totalPotentialReward;
    uint256 tempTotalPotentialReward;
    uint256 rewardsERC20;
    uint256 rewardsCoinbase;
    uint256 indexLastGaugeDistributed;
    bool onDistributionPeriod;
    uint256 backerTotalAllocation;
}

contract BackersManagerUpgradeV2Fork is Test {
    address public backersManager;
    IGovernanceManagerRootstockCollective public governanceManager;
    BuilderRegistryRootstockCollective public builderRegistry;
    address public governor;
    // Random backer with allocations
    address public backer = 0xb0F0D0e27BF82236E01d8FaB590b46A470F45cfF;
    BackersManagerData public backersManagerDataV1;

    function setUp() public {
        backersManager = vm.envAddress("BACKERS_MANAGER_ADDRESS");
        IBackersManagerV1 _backersManagerV1 = IBackersManagerV1(backersManager);
        governanceManager = _backersManagerV1.governanceManager();
        governor = IBackersManagerV1(backersManager).governanceManager().governor();

        backersManagerDataV1 = _getBackersManagerData();

        // migrate
        MigrationV2Deployer _migrationV2Deployer = new MigrationV2Deployer();
        MigrationV2 _migrationV2 = _migrationV2Deployer.run(backersManager);
        vm.prank(governanceManager.upgrader());
        governanceManager.updateUpgrader(address(_migrationV2));
        builderRegistry = _migrationV2.run();
    }

    /**
     * SCENARIO: BackersManager is upgraded to v2 migrating all data
     */
    function test_fork_upgradeBackersManagerData() public view {
        // GIVEN the upgraded backers manager
        // WHEN requesting v2 data
        BackersManagerRootstockCollective _backersManager = BackersManagerRootstockCollective(backersManager);
        // THEN it should match the expected data
        vm.assertEq(address(builderRegistry), address(_backersManager.builderRegistry()));

        // GIVEN the upgraded backers manager
        // WHEN requesting v2 data
        BackersManagerData memory _backersManagerDataV2 = _getBackersManagerData();
        // THEN it should match the previous v1 data
        _validateBackersManagerMigration(backersManagerDataV1, _backersManagerDataV2);
    }

    /**
     * SCENARIO: BackersManager continues to be able to execute builders community approvals after upgrade and migration
     */
    function test_fork_communityApproveBuilderV2() public {
        // GIVEN the upgraded backers manager
        BackersManagerRootstockCollective _backersManager = BackersManagerRootstockCollective(backersManager);
        // WHEN governor executes a community approval
        address _builder = makeAddr("builder");
        vm.prank(governor);
        GaugeRootstockCollective _newGauge = _backersManager.communityApproveBuilder(_builder);

        // THEN new gauge is assigned to the new builder
        assertEq(address(builderRegistry.builderToGauge(_builder)), address(_newGauge));
        // THEN new builder is assigned to the new gauge
        assertEq(builderRegistry.gaugeToBuilder(_newGauge), _builder);
        // THEN builder is community approved
        (,, bool _communityApproved,,,,) = builderRegistry.builderState(_builder);
        assertTrue(_communityApproved);
    }

    /**
     * SCENARIO: BackersManager community approval fails if not authorized
     */
    function test_fork_communityApproveBuilderV2_NotAuthorized() public {
        // GIVEN the upgraded backers manager
        BackersManagerRootstockCollective _backersManager = BackersManagerRootstockCollective(backersManager);
        // WHEN non permissioned address executes a community approval
        address _builder = makeAddr("builder");
        vm.prank(_builder);
        // THEN it should revert with NotAuthorized error
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedChanger.selector);
        _backersManager.communityApproveBuilder(_builder);
    }

    /**
     * SCENARIO: BackersManager is upgraded to v2 and v1 interface is no longer valid
     */
    function test_fork_upgradeBackersManagerInterface() public {
        // GIVEN backers manager v2 casted to v1 interface
        IBackersManagerV1 _backersManagerV2 = IBackersManagerV1(backersManager);
        // WHEN calling v1 functions
        // THEN it should revert
        vm.expectRevert();
        _backersManagerV2.rewardPercentageCooldown();
    }

    function _validateBackersManagerMigration(
        BackersManagerData memory backersManagerDataFirst_,
        BackersManagerData memory backersManagerDataSecond_
    )
        internal
        pure
    {
        // GovernanceManager data
        vm.assertEq(
            address(backersManagerDataFirst_.governanceManager), address(backersManagerDataSecond_.governanceManager)
        );

        // CycleTimeKeeper data
        vm.assertEq(backersManagerDataFirst_.distributionDuration, backersManagerDataSecond_.distributionDuration);
        vm.assertEq(
            backersManagerDataFirst_.cycleData.previousDuration, backersManagerDataSecond_.cycleData.previousDuration
        );
        vm.assertEq(backersManagerDataFirst_.cycleData.nextDuration, backersManagerDataSecond_.cycleData.nextDuration);
        vm.assertEq(backersManagerDataFirst_.cycleData.previousStart, backersManagerDataSecond_.cycleData.previousStart);
        vm.assertEq(backersManagerDataFirst_.cycleData.nextStart, backersManagerDataSecond_.cycleData.nextStart);
        vm.assertEq(backersManagerDataFirst_.cycleData.offset, backersManagerDataSecond_.cycleData.offset);

        // BackersManager data
        vm.assertEq(backersManagerDataFirst_.stakingToken, backersManagerDataSecond_.stakingToken);
        vm.assertEq(backersManagerDataFirst_.rewardToken, backersManagerDataSecond_.rewardToken);
        vm.assertEq(backersManagerDataFirst_.totalPotentialReward, backersManagerDataSecond_.totalPotentialReward);
        vm.assertEq(
            backersManagerDataFirst_.tempTotalPotentialReward, backersManagerDataSecond_.tempTotalPotentialReward
        );
        vm.assertEq(backersManagerDataFirst_.rewardsERC20, backersManagerDataSecond_.rewardsERC20);
        vm.assertEq(backersManagerDataFirst_.rewardsCoinbase, backersManagerDataSecond_.rewardsCoinbase);
        vm.assertEq(
            backersManagerDataFirst_.indexLastGaugeDistributed, backersManagerDataSecond_.indexLastGaugeDistributed
        );
        vm.assertEq(backersManagerDataFirst_.onDistributionPeriod, backersManagerDataSecond_.onDistributionPeriod);
        vm.assertEq(backersManagerDataFirst_.backerTotalAllocation, backersManagerDataSecond_.backerTotalAllocation);
    }

    function _getBackersManagerData() internal view returns (BackersManagerData memory backersManagerData_) {
        // Note: IBackersManagerV1 can be used to get data from BackersManager v1 and v2, since they share the same
        // interface
        IBackersManagerV1 _backersManager = IBackersManagerV1(backersManager);

        backersManagerData_.governanceManager = _backersManager.governanceManager();
        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart, uint24 _offset) =
            _backersManager.cycleData();
        backersManagerData_.cycleData = CycleData({
            previousDuration: _previousDuration,
            nextDuration: _nextDuration,
            previousStart: _previousStart,
            nextStart: _nextStart,
            offset: _offset
        });
        backersManagerData_.distributionDuration = _backersManager.distributionDuration();

        backersManagerData_.stakingToken = address(_backersManager.stakingToken());
        backersManagerData_.rewardToken = _backersManager.rewardToken();
        backersManagerData_.totalPotentialReward = _backersManager.totalPotentialReward();
        backersManagerData_.tempTotalPotentialReward = _backersManager.tempTotalPotentialReward();
        backersManagerData_.rewardsERC20 = _backersManager.rewardsERC20();
        backersManagerData_.rewardsCoinbase = _backersManager.rewardsCoinbase();
        backersManagerData_.indexLastGaugeDistributed = _backersManager.indexLastGaugeDistributed();
        backersManagerData_.onDistributionPeriod = _backersManager.onDistributionPeriod();
        backersManagerData_.backerTotalAllocation = _backersManager.backerTotalAllocation(backer);
    }
}
