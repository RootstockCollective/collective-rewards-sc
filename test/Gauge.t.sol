// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { stdError } from "forge-std/src/Test.sol";
import { BaseTest, Gauge } from "./BaseTest.sol";
import { EpochLib } from "../src/libraries/EpochLib.sol";

contract GaugeTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event SponsorRewardsClaimed(address indexed sponsor_, uint256 amount_);
    event Allocated(address indexed from, address indexed sponsor_, uint256 allocation_);
    event Deallocated(address indexed sponsor_, uint256 allocation_);
    event NotifyReward(uint256 amount_);

    /**
     * SCENARIO: functions protected by OnlySponsorsManager should revert when are not
     *  called by SponsorsManager contract
     */
    function test_OnlySponsorsManager() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);
        // WHEN alice calls allocate
        //  THEN tx reverts because caller is not the SponsorsManager contract
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.allocate(alice, 1 ether);
        // WHEN alice calls deallocate
        //  THEN tx reverts because caller is not the SponsorsManager contract
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.deallocate(alice, 1 ether);
        // WHEN alice calls notifyRewardAmount
        //  THEN tx reverts because caller is not the SponsorsManager contract
        vm.expectRevert(Gauge.NotSponsorsManager.selector);
        gauge.notifyRewardAmount(1 ether);
    }

    /**
     * SCENARIO: getSponsorReward should revert if is not called by the sponsor or the SponsorsManager contract
     */
    function test_NotAuthorized() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);
        // WHEN alice calls getSponsorReward using bob address
        //  THEN tx reverts because caller is not authorized
        vm.expectRevert(Gauge.NotAuthorized.selector);
        gauge.getSponsorReward(bob);
    }

    /**
     * SCENARIO: SponsorsManager allocates to alice without no rewards distributed
     */
    function test_Allocate() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));

        // WHEN allocates 1 ether to alice
        //  THEN Allocated event is emitted
        vm.expectEmit();
        emit Allocated(address(sponsorsManager), alice, 1 ether);
        gauge.allocate(alice, 1 ether);

        // THEN alice allocation is 1 ether
        assertEq(gauge.allocationOf(alice), 1 ether);
        // THEN totalAllocation is 1 ether
        assertEq(gauge.totalAllocation(), 1 ether);
        // THEN totalAllocationByEpoch is 1 ether on the current epoch
        assertEq(gauge.totalAllocationByEpoch(EpochLib.epochStart(block.timestamp)), 1 ether);
        // THEN rewardPerTokenStored is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenStored(), 0);
        // THEN rewardPerToken is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerToken(), 0);
        // THEN alice reward is 0 because there is not rewards distributed
        assertEq(gauge.rewards(alice), 0);
        // THEN alice sponsorRewardPerTokenPaid is 0 because there is not rewards distributed
        assertEq(gauge.sponsorRewardPerTokenPaid(alice), 0);
        // THEN alice lastUpdateTime is 0 because there is not rewards distributed
        assertEq(gauge.lastUpdateTime(), 0);
    }

    /**
     * SCENARIO: SponsorsManager deallocates to alice without no rewards distributed
     */
    function test_Deallocate() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice
        gauge.allocate(alice, 1 ether);

        // WHEN deallocates 1 ether
        //  THEN Deallocated event is emitted
        vm.expectEmit();
        emit Deallocated(alice, 1 ether);
        gauge.deallocate(alice, 1 ether);

        // THEN alice allocation is 0
        assertEq(gauge.allocationOf(alice), 0);
        // THEN totalAllocation is 0
        assertEq(gauge.totalAllocation(), 0);
        // THEN totalAllocationByEpoch is 0 on the current epoch
        assertEq(gauge.totalAllocationByEpoch(EpochLib.epochStart(block.timestamp)), 0);
        // THEN rewardPerTokenStored is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerTokenStored(), 0);
        // THEN rewardPerToken is 0 because there is not rewards distributed
        assertEq(gauge.rewardPerToken(), 0);
        // THEN alice reward is 0 because there is not rewards distributed
        assertEq(gauge.rewards(alice), 0);
        // THEN alice sponsorRewardPerTokenPaid is 0 because there is not rewards distributed
        assertEq(gauge.sponsorRewardPerTokenPaid(alice), 0);
        // THEN alice lastUpdateTime is 0 because there is not rewards distributed
        assertEq(gauge.lastUpdateTime(), 0);
    }

    /**
     * SCENARIO: SponsorsManager makes a partial deallocation to alice without no rewards distributed
     */
    function test_DeallocatePartial() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice
        gauge.allocate(alice, 1 ether);

        // WHEN deallocates 0.25 ether
        gauge.deallocate(alice, 0.25 ether);

        // THEN alice allocation is 0.75 ether
        assertEq(gauge.allocationOf(alice), 0.75 ether);
        // THEN totalAllocation is 0.75 ether
        assertEq(gauge.totalAllocation(), 0.75 ether);
        // THEN totalAllocationByEpoch is 0.75 ether on the current epoch
        assertEq(gauge.totalAllocationByEpoch(EpochLib.epochStart(block.timestamp)), 0.75 ether);
    }

    /**
     * SCENARIO: deallocate should revert when trying to deacollate more tokens than the allocated ones
     */
    function test_DeallocateMore() public {
        // GIVEN a SponsorsManager contract
        vm.startPrank(address(sponsorsManager));
        // AND 1 ether allocated to alice
        gauge.allocate(alice, 1 ether);

        // WHEN tries to deallocate 2 ether
        //  THEN tx reverts because underflow arithmetic error
        vm.expectRevert(stdError.arithmeticError);
        gauge.deallocate(alice, 2 ether);
    }
}
