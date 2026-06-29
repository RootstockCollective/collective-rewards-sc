// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Deploy as BackersManagerRootstockCollectiveDeployer } from "script/BackersManagerRootstockCollective.s.sol";
import { BaseTest } from "../BaseTest.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract InitializationTest is BaseTest {
    /**
     * SCENARIO: BackersManagerRootstockCollective cannot be initialized twice
     */
    function test_RevertBackersManagerRootstockCollectiveInitialize() public {
        // GIVEN a BackersManagerRootstockCollective initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        backersManager.initialize(
            governanceManager,
            address(rifToken),
            address(usdrifToken),
            address(stakingToken),
            cycleDuration,
            cycleStartOffset,
            distributionDuration,
            maxDistributionsPerBatch
        );
    }

    /**
     * SCENARIO: BackersManagerRootstockCollective builder registry cannot be initialized twice
     */
    function test_RevertBackersManagerRootstockCollectiveInitializeBuilderRegistryTwice() public {
        // GIVEN a BackersManagerRootstockCollective with builderRegistry already initialized
        (BackersManagerRootstockCollective _backersManager,) = new BackersManagerRootstockCollectiveDeployer()
            .run(
                address(governanceManager),
                address(rifToken),
                address(usdrifToken),
                address(stakingToken),
                cycleDuration,
                cycleStartOffset,
                distributionDuration,
                maxDistributionsPerBatch
            );

        vm.prank(upgrader);
        _backersManager.initializeBuilderRegistry(builderRegistry);

        //  WHEN the upgrader tries to initialize builderRegistry again
        //   THEN tx reverts because BuilderRegistryAlreadyInitialized
        vm.prank(upgrader);
        vm.expectRevert(BackersManagerRootstockCollective.BuilderRegistryAlreadyInitialized.selector);
        _backersManager.initializeBuilderRegistry(builderRegistry);
    }

    /**
     * SCENARIO: initializeBuilderRegistry can only be called by an authorized upgrader
     */
    function test_RevertBackersManagerRootstockCollectiveInitializeBuilderRegistryNotAuthorizedUpgrader() public {
        // GIVEN a BackersManagerRootstockCollective without builderRegistry initialized
        (BackersManagerRootstockCollective _backersManager,) = new BackersManagerRootstockCollectiveDeployer()
            .run(
                address(governanceManager),
                address(rifToken),
                address(usdrifToken),
                address(stakingToken),
                cycleDuration,
                cycleStartOffset,
                distributionDuration,
                maxDistributionsPerBatch
            );

        //  WHEN an unauthorized account tries to initialize builderRegistry
        //   THEN tx reverts because NotAuthorizedUpgrader
        vm.prank(alice);
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotAuthorizedUpgrader.selector);
        _backersManager.initializeBuilderRegistry(builderRegistry);
    }

    /**
     * SCENARIO: RewardDistributorRootstockCollective cannot be initialized twice
     */
    function test_RevertRewardDistributorRootstockCollectiveInitialize() public {
        // GIVEN a RewardDistributorRootstockCollective initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rewardDistributor.initialize(governanceManager);
    }

    /**
     * SCENARIO: Gauge cannot be initialized twice
     */
    function test_RevertGaugeInitialize() public {
        // GIVEN a Gauge initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        gauge.initialize(address(rifToken), address(usdrifToken), address(backersManager));
    }

    /**
     * SCENARIO: GovernanceManagerRootstockCollective cannot be initialized twice
     */
    function test_RevertGovernanceManagerRootstockCollectiveInitialize() public {
        // GIVEN a GovernanceManagerRootstockCollective initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.prank(governor);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        governanceManager.initialize(governor, foundation, kycApprover, upgrader);
    }
}
