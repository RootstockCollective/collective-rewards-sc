// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { CycleTimeKeeperRootstockCollective } from "../src/backersManager/CycleTimeKeeperRootstockCollective.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";

contract SetDistributionDurationTest is BaseTest {
    event NewDistributionDuration(uint256 newDistributionDuration_, address by_);

    /**
     * SCENARIO: Successfully set a new distribution duration
     */
    function test_SetDistributionDuration() public {
        // GIVEN the caller is authorized (foundation or a valid changer)
        vm.prank(foundation);

        // WHEN a valid new distribution duration is provided
        uint32 _newDistributionDuration = 3 hours;
        vm.expectEmit();
        emit NewDistributionDuration(_newDistributionDuration, foundation);
        backersManager.setDistributionDuration(_newDistributionDuration);

        // THEN the distribution duration should be updated to the new value
        vm.assertEq(backersManager.distributionDuration(), _newDistributionDuration);
    }

    /**
     * SCENARIO: Reverts when the new distribution duration is too short (0 duration)
     */
    function test_RevertWhenDistributionDurationTooShort() public {
        // GIVEN the caller is authorized
        vm.prank(foundation);

        // WHEN a duration of 0 is provided
        vm.expectRevert(CycleTimeKeeperRootstockCollective.DistributionDurationTooShort.selector);

        // THEN it reverts with DistributionDurationTooShort
        backersManager.setDistributionDuration(0);
    }

    /**
     * SCENARIO: Reverts if distribution duration is modified during an active distribution window
     */
    function test_RevertWhenModifiedDuringCurrentDistributionWindow() public {
        // GIVEN the caller is authorized and an active distribution window is ongoing
        vm.startPrank(foundation);

        // Fast forward within the distribution window (distributionDuration = 1 hour)
        vm.warp(block.timestamp + 30 minutes);

        // WHEN trying to modify the distribution duration
        vm.expectRevert(CycleTimeKeeperRootstockCollective.DistributionModifiedDuringDistributionWindow.selector);

        // THEN it reverts because the distribution is ongoing
        backersManager.setDistributionDuration(2 hours);
    }

    /**
     * SCENARIO: Reverts if distribution duration would be modified during new distribution window
     */
    function test_RevertWhenModifiedDuringNewDistributionWindow() public {
        // GIVEN the caller is authorized and an active distribution window is ongoing
        vm.startPrank(foundation);

        // Fast forward outside the distribution window (distributionDuration = 1 hour)
        vm.warp(block.timestamp + 2 hours);

        // WHEN trying to modify the distribution duration
        vm.expectRevert(CycleTimeKeeperRootstockCollective.DistributionModifiedDuringDistributionWindow.selector);

        // THEN it reverts because the distribution window would be re-activated
        backersManager.setDistributionDuration(3 hours);
    }

    /**
     * SCENARIO: Reverts if the new duration is more than half of the upcoming cycle duration
     */
    function test_RevertWhenDistributionDurationTooLongForNextCycle() public {
        // GIVEN a distribution cycle is set with a next cycle duration
        (, uint32 nextDuration,,,) = backersManager.cycleData();
        uint32 invalidLongDuration = (nextDuration / 2) + 1;

        // WHEN an overly long duration is attempted to be set
        vm.expectRevert(CycleTimeKeeperRootstockCollective.DistributionDurationTooLong.selector);

        // THEN it reverts with DistributionDurationTooLong
        vm.prank(foundation);
        backersManager.setDistributionDuration(invalidLongDuration);
    }

    /**
     * SCENARIO: Reverts if the new duration is more than half of the previous cycle duration
     */
    function test_RevertWhenDistributionDurationTooLongForPreviousCycle() public {
        // GIVEN a distribution cycle is set with a previous cycle duration
        uint32 _invalidLongDuration = (cycleDuration / 2) + 1;

        // WHEN an overly long duration is attempted to be set
        vm.expectRevert(CycleTimeKeeperRootstockCollective.DistributionDurationTooLong.selector);

        // THEN it reverts with DistributionDurationTooLong
        vm.prank(foundation);
        backersManager.setDistributionDuration(_invalidLongDuration);
    }

    /**
     * SCENARIO: Reverts when an anauthorized account attempts to set the distribution duration
     */
    function test_RevertUnauthorizedSetDistributionDuration() public {
        // GIVEN an account that is not the foudation attempts to call the function
        vm.prank(governor);

        // WHEN it tries to set the distribution duration
        // THEN it reverts with NotValidChangerOrFoundation
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotFoundationTreasury.selector);
        backersManager.setDistributionDuration(2 hours);
    }
}
