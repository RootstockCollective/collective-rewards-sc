// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";
import { ResumeBuilderBehavior } from "./ResumeBuilderBehavior.t.sol";

contract RevokeKYCTest is HaltedBuilderBehavior, ResumeBuilderBehavior {
    function _initialState() internal override(HaltedBuilderBehavior, ResumeBuilderBehavior) {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        _initialDistribution();

        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);
        vm.stopPrank();
    }

    function _haltGauge() internal override {
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);
        vm.stopPrank();
    }

    function _resumeGauge() internal override {
        // AND builder is KYC approved again
        vm.startPrank(kycApprover);
        builderRegistry.approveBuilderKYC(builder);
        vm.stopPrank();
    }

    /**
     * SCENARIO: builder is KYC revoked in the middle of an cycle having allocation.
     *  builder does not receive rewards, they were sent to rewardDistributor
     */
    function test_BuilderClaimRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC revoked
        _initialState();

        // WHEN builder claim rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rifToken balance is 0 because rewards were sent to rewardDistributor
        assertEq(rifToken.balanceOf(builder), 0 ether);
        // THEN builder usdrifToken balance is 0 because rewards were sent to rewardDistributor
        assertEq(usdrifToken.balanceOf(builder), 0 ether);
        // THEN builder native tokens balance is 0 because rewards were sent to rewardDistributor
        assertEq(builder.balance, 0 ether);

        // THEN builderRewards is 0
        assertEq(gauge.builderRewards(address(rifToken)), 0 ether);
    }

    /**
     * SCENARIO: builder is KYC revoked in the middle of an cycle having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_BuilderUnclaimedRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC revoked
        _initialState();

        // THEN rewardDistributor rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor usdrifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor native tokens balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);
    }

    /**
     * SCENARIO: There is a distribution, builder is halted, is resumed
     *  and there is a new distribution
     *  rewardDistributor receives the first distribution and the
     *  builder receive rewards the second one
     */
    function test_ResumedBuilderClaimsAll() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        //    AND builder is KYC revoked
        _initialState();

        // AND builder is KYC approved again
        vm.startPrank(kycApprover);
        builderRegistry.approveBuilderKYC(builder);

        // AND 100 rif, 100 usdrif and 10 native tokens are distributed
        _distribute(100 ether, 100 ether, 10 ether);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN rewardDistributor rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor native balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        // THEN builder rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder), 6.25 ether);
        // THEN builder usdrifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder), 6.25 ether);
        // THEN builder native balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rifToken balance is 87.5 = (200 * 14 / 16) * 0.5
        assertEq(rifToken.balanceOf(builder2Receiver), 87.5 ether);
        // THEN builder2Receiver usdrifToken balance is 87.5 = (200 * 14 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(builder2Receiver), 87.5 ether);
        // THEN builder2Receiver native tokens balance is 8.75 = (20 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 8.75 ether);
    }

    /**
     * SCENARIO: builder is KYC paused and KYC revoked in the middle of an cycle having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_PausedBuilderIsKYCRevoked() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        _initialDistribution();
        // AND builder is KYC paused
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // THEN rewardDistributor rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor usdrifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor native balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        uint256 _gaugerifTokenBalanceBefore = rifToken.balanceOf(address(gauge));
        uint256 _gaugeNativeBalanceBefore = (address(gauge)).balance;

        uint256 _gauge2rifTokenBalanceBefore = rifToken.balanceOf(address(gauge2));
        uint256 _gauge2NativeBalanceBefore = (address(gauge2)).balance;
        // AND 100 rif, 100 usdrif and 10 native tokens are distributed
        _distribute(100 ether, 100 ether, 10 ether);

        // THEN gauge rifToken balance is the same, it didn't receive distributions
        assertEq(rifToken.balanceOf(address(gauge)), _gaugerifTokenBalanceBefore);
        // THEN gauge usdrifToken balance is the same, it didn't receive distributions
        assertEq(usdrifToken.balanceOf(address(gauge)), _gaugerifTokenBalanceBefore);
        // THEN gauge native balance is the same, it didn't receive distributions
        assertEq(address(gauge).balance, _gaugeNativeBalanceBefore);

        // THEN gauge2 rifToken balance increases 100 ether, it received all the distributions
        assertEq(rifToken.balanceOf(address(gauge2)), _gauge2rifTokenBalanceBefore + 100 ether);
        // THEN gauge2 usdrifToken balance increases 100 ether, it received all the distributions
        assertEq(usdrifToken.balanceOf(address(gauge2)), _gauge2rifTokenBalanceBefore + 100 ether);
        // THEN gauge2 native balance 10 ether, it received all the distributions
        assertEq(address(gauge2).balance, _gauge2NativeBalanceBefore + 10 ether);
    }

    /**
     * SCENARIO: builder has revoked itself and KYC revoked in the middle of an cycle having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_RevokedBuilderIsKYCRevoked() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        _initialDistribution();
        // AND builder pauses himself
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // THEN rewardDistributor rifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rifToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor usdrifToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(usdrifToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor native balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        uint256 _gaugerifTokenBalanceBefore = rifToken.balanceOf(address(gauge));
        uint256 _gaugeNativeBalanceBefore = (address(gauge)).balance;

        uint256 _gauge2rifTokenBalanceBefore = rifToken.balanceOf(address(gauge2));
        uint256 _gauge2NativeBalanceBefore = (address(gauge2)).balance;
        // AND 100 rif, 100 usdrif and 10 native tokens are distributed
        _distribute(100 ether, 100 ether, 10 ether);

        // THEN gauge rifToken balance is the same, it didn't receive distributions
        assertEq(rifToken.balanceOf(address(gauge)), _gaugerifTokenBalanceBefore);
        // THEN gauge usdrifToken balance is the same, it didn't receive distributions
        assertEq(usdrifToken.balanceOf(address(gauge)), _gaugerifTokenBalanceBefore);
        // THEN gauge native balance is the same, it didn't receive distributions
        assertEq(address(gauge).balance, _gaugeNativeBalanceBefore);

        // THEN gauge2 rifToken balance increases 100 ether, it received all the distributions
        assertEq(rifToken.balanceOf(address(gauge2)), _gauge2rifTokenBalanceBefore + 100 ether);
        // THEN gauge2 usdrifToken balance increases 100 ether, it received all the distributions
        assertEq(usdrifToken.balanceOf(address(gauge2)), _gauge2rifTokenBalanceBefore + 100 ether);
        // THEN gauge2 native balance 10 ether, it received all the distributions
        assertEq(address(gauge2).balance, _gauge2NativeBalanceBefore + 10 ether);
    }

    /**
     * SCENARIO: builder is revoked itself and KYC revoked.
     * It is approved again for both
     */
    function test_HaltedGaugeDoNotResumeTwice() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rifToken and 10 native tokens are distributed
        //   AND half cycle pass
        _initialDistribution();
        // AND builder pauses himself
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation is 8467200 ether = 14 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 8_467_200 ether);

        // AND builder is KYC approved again
        vm.startPrank(kycApprover);
        builderRegistry.approveBuilderKYC(builder);

        // THEN gauge is still halted
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), true);
        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation is 8467200 ether = 14 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 8_467_200 ether);

        // AND builder unpauses himself again
        vm.startPrank(builder);
        builderRegistry.unpauseSelf(0.1 ether);

        // THEN gauge is not halted anymore
        assertEq(builderRegistry.isGaugeHalted(address(gauge)), false);
        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation is 8467200 ether = 16 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 9_676_800 ether);
    }
}
