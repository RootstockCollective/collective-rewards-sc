// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";
import { ResumeBuilderBehavior } from "./ResumeBuilderBehavior.t.sol";

contract RevokeKYCTest is HaltedBuilderBehavior, ResumeBuilderBehavior {
    function _initialState() internal override(HaltedBuilderBehavior, ResumeBuilderBehavior) {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
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
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is KYC revoked
        _initialState();

        // WHEN builder claim rewards
        vm.startPrank(builder);
        gauge.claimBuilderReward();

        // THEN builder rewardToken balance is 0 because rewards were sent to rewardDistributor
        assertEq(rewardToken.balanceOf(builder), 0 ether);
        // THEN builder coinbase balance is 0 because rewards were sent to rewardDistributor
        assertEq(builder.balance, 0 ether);

        // THEN builderRewards is 0
        assertEq(gauge.builderRewards(address(rewardToken)), 0 ether);
    }

    /**
     * SCENARIO: builder is KYC revoked in the middle of an cycle having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_BuilderUnclaimedRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is KYC revoked
        _initialState();

        // THEN rewardDistributor rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
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
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        //    AND builder is KYC revoked
        _initialState();

        // AND builder is KYC approved again
        vm.startPrank(kycApprover);
        builderRegistry.approveBuilderKYC(builder);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // WHEN builders claim rewards
        _buildersClaim();

        // THEN rewardDistributor rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        // THEN builder rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder), 6.25 ether);
        // THEN builder coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(builder.balance, 0.625 ether);

        // THEN builder2Receiver rewardToken balance is 87.5 = (200 * 14 / 16) * 0.5
        assertEq(rewardToken.balanceOf(builder2Receiver), 87.5 ether);
        // THEN builder2Receiver coinbase balance is 8.75 = (20 * 14 / 16) * 0.5
        assertEq(builder2Receiver.balance, 8.75 ether);
    }

    /**
     * SCENARIO: builder is KYC paused and KYC revoked in the middle of an cycle having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_PausedBuilderIsKYCRevoked() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        _initialDistribution();
        // AND builder is KYC paused
        vm.startPrank(kycApprover);
        builderRegistry.pauseBuilderKYC(builder, "paused");
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // THEN rewardDistributor rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        uint256 _gaugeRewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge));
        uint256 _gaugeCoinbaseBalanceBefore = (address(gauge)).balance;

        uint256 _gauge2RewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge2));
        uint256 _gauge2CoinbaseBalanceBefore = (address(gauge2)).balance;
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN gauge rewardToken balance is the same, it didn't receive distributions
        assertEq(rewardToken.balanceOf(address(gauge)), _gaugeRewardTokenBalanceBefore);
        // THEN gauge coinbase balance is the same, it didn't receive distributions
        assertEq(address(gauge).balance, _gaugeCoinbaseBalanceBefore);

        // THEN gauge2 rewardToken balance increases 100 ether, it received all the distributions
        assertEq(rewardToken.balanceOf(address(gauge2)), _gauge2RewardTokenBalanceBefore + 100 ether);
        // THEN gauge2 coinbase balance 10 ether, it received all the distributions
        assertEq(address(gauge2).balance, _gauge2CoinbaseBalanceBefore + 10 ether);
    }

    /**
     * SCENARIO: builder has revoked itself and KYC revoked in the middle of an cycle having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_RevokedBuilderIsKYCRevoked() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half cycle pass
        _initialDistribution();
        // AND builder pauses himself
        vm.startPrank(builder);
        builderRegistry.pauseSelf();
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        builderRegistry.revokeBuilderKYC(builder);

        // THEN rewardDistributor rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        uint256 _gaugeRewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge));
        uint256 _gaugeCoinbaseBalanceBefore = (address(gauge)).balance;

        uint256 _gauge2RewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge2));
        uint256 _gauge2CoinbaseBalanceBefore = (address(gauge2)).balance;
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN gauge rewardToken balance is the same, it didn't receive distributions
        assertEq(rewardToken.balanceOf(address(gauge)), _gaugeRewardTokenBalanceBefore);
        // THEN gauge coinbase balance is the same, it didn't receive distributions
        assertEq(address(gauge).balance, _gaugeCoinbaseBalanceBefore);

        // THEN gauge2 rewardToken balance increases 100 ether, it received all the distributions
        assertEq(rewardToken.balanceOf(address(gauge2)), _gauge2RewardTokenBalanceBefore + 100 ether);
        // THEN gauge2 coinbase balance 10 ether, it received all the distributions
        assertEq(address(gauge2).balance, _gauge2CoinbaseBalanceBefore + 10 ether);
    }

    /**
     * SCENARIO: builder is revoked itself and KYC revoked.
     * It is approved again for both
     */
    function test_HaltedGaugeDoNotResumeTwice() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
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
        assertEq(backersManager.isGaugeHalted(address(gauge)), true);
        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation is 8467200 ether = 14 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 8_467_200 ether);

        // AND builder unpauses himself again
        vm.startPrank(builder);
        builderRegistry.unpauseSelf(0.1 ether);

        // THEN gauge is not halted anymore
        assertEq(backersManager.isGaugeHalted(address(gauge)), false);
        // THEN gauge rewardShares is 1209600 ether = 2 * 1 WEEK
        assertEq(gauge.rewardShares(), 1_209_600 ether);
        // THEN total allocation is 8467200 ether = 16 * 1 WEEK
        assertEq(backersManager.totalPotentialReward(), 9_676_800 ether);
    }
}
