// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { BaseTest } from "./BaseTest.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";
import { BuilderRegistryRootstockCollective } from "../src/builderRegistry/BuilderRegistryRootstockCollective.sol";

contract PauseBuilderKYCTest is BaseTest {
    function _initialState() internal {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        //   AND half cycle pass
        _initialDistribution();

        // AND builder is KYC paused
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        vm.stopPrank();
    }

    /**
     * SCENARIO: builder is KYC paused in the middle of an cycle having allocation.
     *  Backers claim all the rewards
     */
    function test_PausedGaugeBackersReceiveRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC paused
        _initialState();
        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN alice claim rewards
        vm.startPrank(alice);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN alice rifToken balance is 25 = (100 * 8 / 16) * 0.5
        assertApproxEqAbs(rifToken.balanceOf(alice), 25 ether, 100);
        // THEN alice usdrifToken balance is 25 = (100 * 8 / 16) * 0.5
        assertApproxEqAbs(usdrifToken.balanceOf(alice), 25 ether, 100);
        // THEN alice native tokens balance is 2.5 = (10 * 8 / 16) * 0.5
        assertApproxEqAbs(alice.balance, 2.5 ether, 100);

        // WHEN bob claim rewards
        vm.startPrank(bob);
        backersManager.claimBackerRewards(gaugesArray);

        // THEN bob rifToken balance is 25 = (100 * 8 / 16) * 0.5
        assertApproxEqAbs(rifToken.balanceOf(bob), 25 ether, 100);
        // THEN bob usdrifToken balance is 25 = (100 * 8 / 16) * 0.5
        assertApproxEqAbs(usdrifToken.balanceOf(bob), 25 ether, 100);
        // THEN bob native tokens balance is 2.5 = (10 * 8 / 16) * 0.5
        assertApproxEqAbs(bob.balance, 2.5 ether, 100);
    }

    /**
     * SCENARIO: builder is KYC paused in the middle of an cycle having allocation.
     *  If the builder calls claimBuilderReward the tx reverts
     */
    function test_PausedGaugeBuilderCannotReceiveRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC paused
        _initialState();
        // AND cycle finish
        _skipAndStartNewCycle();

        // WHEN builder claim rewards
        vm.startPrank(builder);
        // THEN tx reverts because builder rewards are locked
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderRewardsLocked.selector);
        gauge.claimBuilderReward();

        // THEN builder rifToken balance is 0
        assertEq(rifToken.balanceOf(builder), 0);
        // THEN builder usdrifToken balance is 0
        assertEq(usdrifToken.balanceOf(builder), 0);
        // THEN builder native tokens balance is 0
        assertEq(builder.balance, 0);
        // THEN builder rifToken pending to claim are 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.builderRewards(address(rifToken)), 6.25 ether);
        // THEN builder usdrifToken pending to claim are 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.builderRewards(address(usdrifToken)), 6.25 ether);
        // THEN builder native tokens pending to claim are 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.builderRewards(UtilsLib._NATIVE_ADDRESS), 0.625 ether);

        // WHEN builder2 claim rewards
        vm.startPrank(builder2);
        gauge2.claimBuilderReward();

        // THEN builder2Receiver rifToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver usdrifToken balance is 43.75 = (100 * 14 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder2Receiver), 43.75 ether);
        // THEN builder2Receiver native tokens balance is 4.375 = (10 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 4.375 ether);
    }

    /**
     * SCENARIO: builder is KYC paused in the middle of an cycle having allocation.
     *  Alice can modify its allocation
     */
    function test_PausedGaugeModifyAllocation() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC paused
        _initialState();

        // WHEN alice removes allocations from paused builder
        vm.startPrank(alice);
        backersManager.allocate(gauge, 0);
        // THEN gauge rewardShares is 604800 ether = 2 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 604_800 ether);
        // THEN total allocation is 9072000 ether = 2 * 1/2 WEEK + 14 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 9_072_000 ether);

        // WHEN alice adds allocations to paused builder
        vm.startPrank(alice);
        backersManager.allocate(gauge, 4 ether);
        // THEN gauge rewardShares is 1814400 ether = 2 * 1/2 WEEK + 4 * 1/2 WEEK
        assertEq(gauge.rewardShares(), 1_814_400 ether);
        // THEN total allocation is 10281600 ether =  2 * 1/2 WEEK + 4 * 1/2 WEEK + 14 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 10_281_600 ether);
    }

    /**
     * SCENARIO: builder is KYC paused in the middle of an cycle having rewards to claim,
     *  is unpaused in the same cycle and can claim them
     */
    function test_ResumeGaugeInSameCycle() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC paused
        _initialState();

        // AND 3/4 cycle pass
        _skipRemainingCycleFraction(2);

        // WHEN builder's gauge is KYC unpaused
        vm.startPrank(kycApprover);
        builderRegistry.unpauseBuilderKYC(builder);

        // WHEN builder claim rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder), 6.25 ether);
        // THEN builder usdrifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder), 6.25 ether);
        // THEN builder native tokens balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);
        // THEN builder rifToken pending to claim are 0
        assertEq(gauge.builderRewards(address(rifToken)), 0);
        // THEN builder usdrifToken pending to claim are 0
        assertEq(gauge.builderRewards(address(usdrifToken)), 0);
        // THEN builder native tokens pending to claim are 0
        assertEq(gauge.builderRewards(UtilsLib._NATIVE_ADDRESS), 0);
    }

    /**
     * SCENARIO: builder is KYC paused in the middle of an cycle having rewards to claim,
     *  is unpaused in the next cycle and can claim the previous rewards and the new ones
     */
    function test_ResumeGaugeInNextCycle() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC paused
        _initialState();

        // AND cycle finish
        _skipAndStartNewCycle();
        // AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        _distribute(100 ether, 100 ether, 10 ether);

        // WHEN gauge is KYC unpaused
        vm.startPrank(kycApprover);
        builderRegistry.unpauseBuilderKYC(builder);

        // WHEN builder claim rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rifToken balance is 12.5 = (200 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder), 12.5 ether);
        // THEN builder usdrifToken balance is 12.5 = (200 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder), 12.5 ether);
        // THEN builder native tokens balance is 1.25 = (20 * 2 / 16) * 0.5
        assertEq(builder.balance, 1.25 ether);
        // THEN builder rifToken pending to claim are 0
        assertEq(gauge.builderRewards(address(rifToken)), 0);
        // THEN builder usdrifToken pending to claim are 0
        assertEq(gauge.builderRewards(address(usdrifToken)), 0);
        // THEN builder native tokens pending to claim are 0
        assertEq(gauge.builderRewards(UtilsLib._NATIVE_ADDRESS), 0);
    }

    /**
     * SCENARIO: self paused builder is KYC paused
     *  If the builder calls claimBuilderReward the tx reverts
     */
    function test_RevokedGaugeIsPaused() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken, 100 usdrifToken and 10 native tokens are distributed
        //   AND half cycle pass
        _initialDistribution();
        // AND builder pauses himself
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        // AND builder is KYC paused
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");

        // WHEN builder claim rewards
        vm.startPrank(builder);
        // THEN tx reverts because builder rewards are locked
        vm.expectRevert(BuilderRegistryRootstockCollective.BuilderRewardsLocked.selector);
        gauge.claimBuilderReward();
    }
}
