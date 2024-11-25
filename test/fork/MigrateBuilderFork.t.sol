// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { ISimplifiedRewardDistributorRootstockCollective } from
    "./interfaces/ISimplifiedRewardDistributorRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/BackersManagerRootstockCollective.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";

contract MigrateBuilderFork is Test {
    uint64 private _rewardPercentage;
    address[] public buildersV1;
    address[] public buildersRewardReceiverV1;

    ISimplifiedRewardDistributorRootstockCollective public simplifiedRewardDistributor;
    GaugeRootstockCollective[] public gauges;
    BackersManagerRootstockCollective public backersManager;
    RewardDistributorRootstockCollective public rewardDistributor;
    address public kycApprover;
    // ASSUMPTION: foundation holds RBTC and RIF
    address public foundation;
    address public stRifHolder;

    IERC20 public rewardToken; // RIF token
    IERC20 public stRif;

    event BuilderMigrated(address indexed builder_, address indexed migrator_);
    event Dewhitelisted(address indexed builder_);

    function setUp() public {
        _rewardPercentage = 1 ether / 5; // 20%

        address payable _simplifiedRewardDistributorAddress =
            payable(vm.envAddress("SIMPLIFIED_REWARD_DISTRIBUTOR_ADDRESS_FORK"));
        simplifiedRewardDistributor =
            ISimplifiedRewardDistributorRootstockCollective(_simplifiedRewardDistributorAddress);
        buildersV1 = simplifiedRewardDistributor.getWhitelistedBuildersArray();
        for (uint256 i = 0; i < buildersV1.length; i++) {
            buildersRewardReceiverV1.push(simplifiedRewardDistributor.builderRewardReceiver(buildersV1[i]));
        }
        backersManager = BackersManagerRootstockCollective(vm.envAddress("BACKERS_MANAGER_ADDRESS_FORK"));
        kycApprover = backersManager.governanceManager().kycApprover();
        foundation = backersManager.governanceManager().foundationTreasury();
        stRifHolder = vm.envAddress("STRIF_HOLDER_ADDRESS_FORK");

        stRif = backersManager.stakingToken();
        address payable _rewardDistributor = payable(backersManager.rewardDistributor());
        rewardDistributor = RewardDistributorRootstockCollective(_rewardDistributor);
        rewardToken = IERC20(backersManager.rewardToken());
    }

    /**
     * SCENARIO: V1 builders are migrated to v1 and can claim rewards
     */
    function test_fork_MigrateBuilder() public {
        // GIVEN Fundation migrates all v1 Builders
        for (uint256 i = 0; i < buildersV1.length; i++) {
            // GIVEN a v1 builder
            address _builder = buildersV1[i];
            address _rewardReceiver = buildersRewardReceiverV1[i];

            vm.expectEmit();
            emit BuilderMigrated(_builder, kycApprover);

            //  WHEN the Fundation migrates the builder to v2
            vm.prank(kycApprover);
            backersManager.migrateBuilder(_builder, _rewardReceiver, _rewardPercentage);

            // THEN the builder is community approved, activated, and KYC-approved
            _validateIsWhitelisted(_builder);

            // AND reward receiver and percentage are set correctly
            (, uint64 next,) = backersManager.backerRewardPercentage(_builder);
            address newRewardReceiver = backersManager.builderRewardReceiver(_builder);
            vm.assertEq(newRewardReceiver, _rewardReceiver);
            vm.assertEq(next, _rewardPercentage);
        }

        vm.assertGt(buildersV1.length, 0);

        // THEN all v1 builders have gauges in v2
        for (uint256 i = 0; i < buildersV1.length; i++) {
            GaugeRootstockCollective _gauge = backersManager.builderToGauge(buildersV1[i]);
            gauges.push(_gauge);
            vm.assertNotEq(address(_gauge), address(0));
        }

        // THEN Backers can vote on migrated Builders
        uint256 _unallocatedRif = _getUnallocatedStRif();
        vm.assertGt(_unallocatedRif, 0);

        uint256 _amountToAllocate = _unallocatedRif / gauges.length;
        for (uint256 i = 0; i < gauges.length; i++) {
            vm.prank(stRifHolder);
            backersManager.allocate(gauges[i], _amountToAllocate);
            uint256 _allocated = gauges[i].allocationOf(stRifHolder);
            vm.assertEq(_allocated, _amountToAllocate);
        }

        // THEN Fundation does distribution
        _distribute();
        _skipAndStartNewCycle();

        // THEN Backer can claim rewards and increase his RIF and RBTC balance
        // Note: Simplified check to avoid complex calculations that are already covered by unit testing
        uint256 _backerInitialRifBalance = rewardToken.balanceOf(stRifHolder);
        uint256 _backerInitialRbtcBalance = stRifHolder.balance;
        vm.prank(stRifHolder);
        backersManager.claimBackerRewards(gauges);
        uint256 _backerRifBalance = rewardToken.balanceOf(stRifHolder);
        uint256 _backerRbtcBalance = stRifHolder.balance;
        vm.assertGt(_backerRifBalance, _backerInitialRifBalance);
        vm.assertGt(_backerRbtcBalance, _backerInitialRbtcBalance);

        // THEN builders can claim rewards
        for (uint256 i = 0; i < gauges.length; i++) {
            address _builder = buildersV1[i];
            address _rewardReceiver = buildersRewardReceiverV1[i];

            uint256 _receiverInitialRifBalance = rewardToken.balanceOf(_builder);
            uint256 _receiverInitialRbtcBalance = _builder.balance;
            vm.prank(_builder);
            gauges[i].claimBuilderReward();
            uint256 _receiverRifBalance = rewardToken.balanceOf(_rewardReceiver);
            uint256 _receiverRbtcBalance = _rewardReceiver.balance;
            vm.assertGt(_receiverRifBalance, _receiverInitialRifBalance);
            vm.assertGt(_receiverRbtcBalance, _receiverInitialRbtcBalance);
        }
    }

    function _distribute() internal {
        _skipAndStartNewCycle();
        vm.startPrank(foundation);
        uint256 _amountERC20 = rewardToken.balanceOf(foundation) / 2;
        vm.assertGt(_amountERC20, 0);
        uint256 _amountCoinbase = foundation.balance / 2;
        vm.assertGt(_amountCoinbase, 0);
        rewardToken.transfer(address(rewardDistributor), _amountERC20);
        vm.deal(address(rewardDistributor), _amountCoinbase + address(rewardDistributor).balance);
        rewardDistributor.sendRewardsAndStartDistribution(_amountERC20, _amountCoinbase);
        while (backersManager.onDistributionPeriod()) {
            backersManager.distribute();
        }
        vm.stopPrank();
    }

    function _skipAndStartNewCycle() internal {
        uint256 _currentCycleRemaining = backersManager.cycleNext(block.timestamp) - block.timestamp;
        skip(_currentCycleRemaining);
    }

    function _getUnallocatedStRif() internal view returns (uint256 unstakedStRif_) {
        uint256 _balance = stRif.balanceOf(stRifHolder);
        uint256 _backerTotalAllocation = backersManager.backerTotalAllocation(stRifHolder);
        unstakedStRif_ = _balance - _backerTotalAllocation;
    }

    function _validateIsWhitelisted(address builder_) private view {
        (bool _activated, bool _kycApproved, bool _communityApproved,,,,) = backersManager.builderState(builder_);
        vm.assertTrue(_communityApproved);
        vm.assertTrue(_activated);
        vm.assertTrue(_kycApproved);
    }

    function _clearRbtcBalance(address address_) internal returns (uint256 balance_) {
        balance_ = address_.balance;
        vm.prank(address_);
        Address.sendValue(payable(address(this)), balance_);
    }

    function _clearRifBalance(address address_) internal returns (uint256 balance_) {
        balance_ = rewardToken.balanceOf(address_);
        vm.prank(address_);
        rewardToken.transfer(address(this), balance_);
    }
}
