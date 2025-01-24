// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest, BackersManagerRootstockCollective } from "./BaseTest.sol";

contract OptOutRewardsBehaviour is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event BackerRewardsOptedOut(address indexed backer_);
    event BackerRewardsOptedIn(address indexed backer_);

    /**
     * SCENARIO: Can only OptOut if not already opted out
     */
    function test_OptOutAlreadyOptedOut() public {
        // GIVEN alice OptOut
        vm.startPrank(alice);
        backersManager.optOutRewards(alice);
        //  WHEN alice tries to OptOut again
        //   THEN tx reverts because AlreadyOptedOut
        vm.expectRevert(BackersManagerRootstockCollective.BackerOptedOutRewards.selector);
        backersManager.optOutRewards(alice);
    }

    /**
     * SCENARIO: Can only OptIn if already opted out
     */
    function test_OptInWhileNotOptedOutRevert() public {
        // GIVEN alice tries to OptIn
        vm.startPrank(alice);
        //   THEN tx reverts because is not opted out
        vm.expectRevert(BackersManagerRootstockCollective.AlreadyOptedInRewards.selector);
        backersManager.optInRewards(alice);
    }

    /**
     * SCENARIO: Only KYC approver or the backer itself can OptOut
     */
    function test_OptOutAuthorization() public {
        //  GIVEN alice tries to OptOut Bob
        vm.prank(alice);
        //   THEN tx reverts because NotAuthorized
        vm.expectRevert(BackersManagerRootstockCollective.NotAuthorized.selector);
        backersManager.optOutRewards(bob);

        //  GIVEN KYC approver tries to OptOut Bob
        vm.prank(kycApprover);
        //   THEN tx is successful
        vm.expectEmit();
        emit BackerRewardsOptedOut(bob);
        backersManager.optOutRewards(bob);

        // GIVEN alice tries to OptOut
        vm.prank(alice);
        //   THEN tx is successful
        vm.expectEmit();
        emit BackerRewardsOptedOut(alice);
        backersManager.optOutRewards(alice);
    }

    /**
     * SCENARIO: OptOut Backer cannot allocate
     */
    function test_OptOutAllocateRevert() public {
        // GIVEN alice OptOut
        vm.startPrank(alice);
        backersManager.optOutRewards(alice);
        //  WHEN alice tries to allocate
        //   THEN tx reverts because OptedOut
        vm.expectRevert(BackersManagerRootstockCollective.BackerOptedOutRewards.selector);
        backersManager.allocate(gauge, 0.1 ether);
    }

    /**
     * SCENARIO: Backer can only OptOut if has no allocations
     */
    function test_OptOutWithAllocation() public {
        // GIVEN alice allocates 0.1 ether
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0.1 ether);
        //  WHEN alice tries to OptOut
        //   THEN tx reverts because BackerHasAllocations
        vm.expectRevert(BackersManagerRootstockCollective.BackerHasAllocations.selector);
        backersManager.optOutRewards(alice);
        //  WHEN alice removes the allocation
        backersManager.allocate(gauge, 0 ether);
        //  THEN alice can OptOut
        vm.expectEmit();
        emit BackerRewardsOptedOut(alice);
        backersManager.optOutRewards(alice);
    }

    /**
     * SCENARIO: OptIn Backer can allocate
     */
    function test_OptInAndAllocate() public {
        // GIVEN alice OptOut
        vm.startPrank(alice);
        backersManager.optOutRewards(alice);
        //  WHEN alice tries to allocate
        //   THEN tx reverts because OptedOut
        vm.expectRevert(BackersManagerRootstockCollective.BackerOptedOutRewards.selector);
        backersManager.allocate(gauge, 0.1 ether);
        //  WHEN alice OptIn
        backersManager.optInRewards(alice);
        //  THEN alice can allocate
        vm.expectEmit();
        emit NewAllocation(alice, address(gauge), 0.1 ether);
        backersManager.allocate(gauge, 0.1 ether);
    }
}
