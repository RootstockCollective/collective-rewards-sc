// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { HaltedBuilderBehavior } from "./HaltedBuilderBehavior.t.sol";
import { BuilderRegistry } from "../src/BuilderRegistry.sol";
import { Gauge } from "../src/gauge/Gauge.sol";

contract RevokeKYCTest is HaltedBuilderBehavior {
    function _initialState() internal override {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();

        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder, address(rewardDistributor));
        vm.stopPrank();
    }

    /**
     * SCENARIO: builder is KYC revoked in the middle of an epoch having allocation.
     *  builder receives all the rewards for the current epoch
     */
    function test_RevertBuilderClaimRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is KYC revoked
        _initialState();

        // WHEN builder claim rewards
        //  THEN tx reverts because builder rewards are locked
        vm.startPrank(builder);
        vm.expectRevert(Gauge.BuilderRewardsLocked.selector);
        gauge.claimBuilderReward();
    }

    /**
     * SCENARIO: builder is KYC revoked in the middle of an epoch having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_BuilderUnclaimedRewards() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        //    AND builder is KYC revoked
        _initialState();

        // THEN rewardDistributor rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);
    }

    /**
     * SCENARIO: builder is paused and KYC revoked in the middle of an epoch having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_PausedBuilderIsKYCRevoked() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();
        // AND builder is paused
        vm.startPrank(kycApprover);
        sponsorsManager.pauseBuilder(builder, "paused");
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder, address(rewardDistributor));

        // THEN rewardDistributor rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        uint256 gaugeRewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge));
        uint256 gaugeCoinbaseBalanceBefore = (address(gauge)).balance;

        uint256 gauge2RewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge2));
        uint256 gauge2CoinbaseBalanceBefore = (address(gauge2)).balance;
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN gauge rewardToken balance is the same, it didn't receive distributions
        assertEq(rewardToken.balanceOf(address(gauge)), gaugeRewardTokenBalanceBefore);
        // THEN gauge coinbase balance is the same, it didn't receive distributions
        assertEq(address(gauge).balance, gaugeCoinbaseBalanceBefore);

        // THEN gauge2 rewardToken balance increases 100 ether, it received all the distributions
        assertEq(rewardToken.balanceOf(address(gauge2)), gauge2RewardTokenBalanceBefore + 100 ether);
        // THEN gauge2 coinbase balance 10 ether, it received all the distributions
        assertEq(address(gauge2).balance, gauge2CoinbaseBalanceBefore + 10 ether);
    }

    /**
     * SCENARIO: builder has revoked itself and KYC revoked in the middle of an epoch having allocation.
     *  builder's unclaimed rewards are sent to rewardDistributor
     */
    function test_RevokedBuilderIsKYCRevoked() public {
        // GIVEN alice and bob allocate to builder and builder2
        //  AND 100 rewardToken and 10 coinbase are distributed
        //   AND half epoch pass
        _initialDistribution();
        // AND builder is revoked
        vm.startPrank(builder);
        sponsorsManager.revokeBuilder();
        // AND builder is KYC revoked
        vm.startPrank(kycApprover);
        sponsorsManager.revokeBuilderKYC(builder, address(rewardDistributor));

        // THEN rewardDistributor rewardToken balance is 6.25 = (100 * 2 / 16) * 0.5
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 6.25 ether);
        // THEN rewardDistributor coinbase balance is 0.625 = (10 * 2 / 16) * 0.5
        assertEq(address(rewardDistributor).balance, 0.625 ether);

        uint256 gaugeRewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge));
        uint256 gaugeCoinbaseBalanceBefore = (address(gauge)).balance;

        uint256 gauge2RewardTokenBalanceBefore = rewardToken.balanceOf(address(gauge2));
        uint256 gauge2CoinbaseBalanceBefore = (address(gauge2)).balance;
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN gauge rewardToken balance is the same, it didn't receive distributions
        assertEq(rewardToken.balanceOf(address(gauge)), gaugeRewardTokenBalanceBefore);
        // THEN gauge coinbase balance is the same, it didn't receive distributions
        assertEq(address(gauge).balance, gaugeCoinbaseBalanceBefore);

        // THEN gauge2 rewardToken balance increases 100 ether, it received all the distributions
        assertEq(rewardToken.balanceOf(address(gauge2)), gauge2RewardTokenBalanceBefore + 100 ether);
        // THEN gauge2 coinbase balance 10 ether, it received all the distributions
        assertEq(address(gauge2).balance, gauge2CoinbaseBalanceBefore + 10 ether);
    }
}
