// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { BuilderRegistryRootstockCollective } from "../src/BuilderRegistryRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract MigrateBuilderTest is BaseTest {
    address private _v1Builder01;
    address private _v1Builder02;
    uint64 private _validRewardPercentage;

    event BuilderMigrated(address indexed builder_, address indexed migrator_);
    event Dewhitelisted(address indexed builder_);

    function _setUp() internal override {
        _v1Builder01 = makeAddr("v1Builder01");
        _v1Builder02 = makeAddr("v1Builder02");
        _validRewardPercentage = 1 ether / 4; // 25%
    }

    /**
     * SCENARIO: Successfully migrate a builder
     */
    function test_MigrateBuilder() public {
        // GIVEN a valid builder and reward details
        //  WHEN foundation calls migrateBuilder
        vm.expectEmit();
        emit BuilderMigrated(_v1Builder01, foundation);

        vm.prank(foundation);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);

        // THEN the builder is whitelisted, activated, and KYC-approved
        _validateIsActivatedAndWhitelisted(_v1Builder01);

        // AND reward receiver and percentage are set correctly
        (, uint64 next,) = backersManager.builderRewardPercentage(_v1Builder01);
        vm.assertEq(backersManager.builderRewardReceiver(_v1Builder01), _v1Builder01);
        vm.assertEq(next, _validRewardPercentage);
    }

    /**
     * SCENARIO: Successfully migrate multiple builders
     */
    function test_MigrateMultipleBuilders() public {
        // GIVEN multiple valid builders and reward details
        _v1Builder02 = makeAddr("builderV1_2");

        //  WHEN foundation calls migrateBuilder for each builder
        vm.startPrank(foundation);
        vm.expectEmit();
        emit BuilderMigrated(_v1Builder01, foundation);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);

        vm.expectEmit();
        emit BuilderMigrated(_v1Builder02, foundation);
        backersManager.migrateBuilder(_v1Builder02, _v1Builder02, _validRewardPercentage);
        vm.stopPrank();

        // THEN the builders are whitelisted, activated, and KYC-approved
        _validateIsActivatedAndWhitelisted(_v1Builder01);
        _validateIsActivatedAndWhitelisted(_v1Builder02);
    }

    /**
     * SCENARIO: Unauthorized account attempts to migrate a builder
     */
    function test_MigrateFromUnauthorizedAccount() public {
        // GIVEN an unauthorized account
        //  WHEN the account attempts to call migrateBuilder
        vm.prank(alice);

        // THEN the transaction reverts with NotFoundationTreasury error
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotFoundationTreasury.selector);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);
    }

    /**
     * SCENARIO: Attempt to migrate an already migrated builder
     */
    function test_MigrateAlreadyMigratedBuilder() public {
        // GIVEN a builder has already been migrated
        vm.startPrank(foundation);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);

        //  WHEN foundation attempts to migrate the same builder again
        //   THEN the transaction reverts with AlreadyWhitelisted error
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyWhitelisted.selector);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);

        vm.stopPrank();
    }

    /**
     * SCENARIO: Attempt to migrate an already whitelisted builder
     */
    function test_MigrateAlreadyWhitelistedBuilder() public {
        // GIVEN a builder is already whitelisted
        vm.prank(governor);
        backersManager.whitelistBuilder(_v1Builder01);

        //  WHEN foundation attempts to migrate the whitelisted builder
        //   THEN the transaction reverts with AlreadyWhitelisted error
        vm.prank(foundation);
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyWhitelisted.selector);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);
    }

    /**
     * SCENARIO: Attempt to migrate an already activated builder
     */
    function test_MigrateAlreadyActivatedBuilder() public {
        // GIVEN a builder is already whitelisted and activated
        vm.prank(governor);
        backersManager.whitelistBuilder(_v1Builder01);
        vm.prank(kycApprover);
        backersManager.activateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);

        //  WHEN foundation attempts to migrate the activated builder
        //   THEN the transaction reverts with AlreadyWhitelisted error
        vm.prank(foundation);
        vm.expectRevert(BuilderRegistryRootstockCollective.AlreadyWhitelisted.selector);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);
    }

    /**
     * SCENARIO: Attempt to migrate a builder with an invalid reward percentage
     */
    function test_MigrateWithInvalidRewardPercentage() public {
        // GIVEN an invalid reward percentage
        uint64 _invalidRewardPercentage = type(uint64).max;

        //  WHEN foundation attempts to migrate a builder with the invalid percentage
        //   THEN the transaction reverts with InvalidBuilderRewardPercentage error
        vm.expectRevert(BuilderRegistryRootstockCollective.InvalidBuilderRewardPercentage.selector);
        vm.prank(foundation);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _invalidRewardPercentage);
    }

    /**
     * SCENARIO: Dewhitelist a builder after migration
     */
    function test_DewhitelistBuilder() public {
        // GIVEN a builder has been migrated
        vm.prank(foundation);
        backersManager.migrateBuilder(_v1Builder01, _v1Builder01, _validRewardPercentage);

        //  WHEN foundation dewhitelists the builder
        vm.expectEmit();
        emit Dewhitelisted(_v1Builder01);

        vm.prank(governor);
        backersManager.dewhitelistBuilder(_v1Builder01);

        // THEN the builder is no longer whitelisted
        (bool _activated, bool _kycApproved, bool _whitelisted,,,,) = backersManager.builderState(_v1Builder01);
        vm.assertFalse(_whitelisted);
    }

    function _validateIsActivatedAndWhitelisted(address builder_) private view {
        (bool _activated, bool _kycApproved, bool _whitelisted,,,,) = backersManager.builderState(builder_);
        vm.assertTrue(_whitelisted);
        vm.assertTrue(_activated);
        vm.assertTrue(_kycApproved);
    }
}
