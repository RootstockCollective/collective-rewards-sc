// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, RewardDistributor } from "./BaseTest.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract RewardDistributorTest is BaseTest {
    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        // add some allocations to don't revert by zero division on the notifyRewardAmount
        vm.prank(alice);
        sponsorsManager.allocate(gauge, 0.1 ether);
    }

    /**
     * SCENARIO: functions protected by onlyFoundationTreasury should revert when are not
     *  called by foundation treasury address
     */
    function test_OnlyFoundationTreasury() public {
        // GIVEN a RewardDistributor contract
        vm.startPrank(alice);
        // WHEN alice calls sendRewards
        //  THEN tx reverts because caller is not the foundation treasury address
        vm.expectRevert(RewardDistributor.NotFoundationTreasury.selector);
        rewardDistributor.sendRewards(1 ether, 1 ether);
        // WHEN alice calls sendRewardsAndStartDistribution
        //  THEN tx reverts because caller is not the foundation treasury address
        vm.expectRevert(RewardDistributor.NotFoundationTreasury.selector);
        rewardDistributor.sendRewardsAndStartDistribution(1 ether, 1 ether);
    }

    /**
     * SCENARIO: sendRewards should revert trying to send more tokens than its balance
     */
    function test_InsufficientBalance() public {
        // GIVEN a RewardDistributor contract with 1 ether of reward token
        rewardToken.transfer(address(rewardDistributor), 1 ether);
        vm.startPrank(foundation);
        // WHEN foundation treasury calls sendRewards trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rewardDistributor), 1 ether, 2 ether
            )
        );
        rewardDistributor.sendRewards(2 ether, 0 ether);

        // WHEN foundation treasury calls sendRewardsAndStartDistribution trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rewardDistributor), 1 ether, 2 ether
            )
        );
        rewardDistributor.sendRewardsAndStartDistribution(2 ether, 0 ether);
    }

    /**
     * SCENARIO: sendRewards should revert trying to send more Coinbase than its balance
     */
    function test_InsufficientCoinbaseBalance() public {
        // GIVEN a RewardDistributor contract with 1 ether of coinbase
        Address.sendValue(payable(address(rewardDistributor)), 1 ether);
        vm.startPrank(foundation);
        // WHEN foundation treasury calls sendRewards trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert();
        rewardDistributor.sendRewards(0, 2 ether);

        // WHEN foundation treasury calls sendRewardsAndStartDistribution trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert();
        rewardDistributor.sendRewardsAndStartDistribution(0, 2 ether);
    }

    /**
     * SCENARIO: sends rewards twice on one epoch and then on more time on the next one
     */
    function test_SendRewards() public {
        // GIVEN a RewardDistributor contract with 10 ether of reward token and 5 of coinbase
        rewardToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        // WHEN foundation treasury calls sendRewards transferring 2 ethers of reward token and 1 of coinbase
        vm.startPrank(foundation);
        rewardDistributor.sendRewards(2 ether, 1 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND foundation treasury calls sendRewards transferring 1 ethers of reward token and 0.5 of coinbase
        rewardDistributor.sendRewards(1 ether, 0.5 ether);
        // AND epoch finish
        _skipAndStartNewEpoch();
        // AND foundation treasury calls sendRewards transferring 4 ethers of reward token and 2 of coinbase
        rewardDistributor.sendRewards(4 ether, 2 ether);

        // THEN reward token balance of rewardDistributor is 3 ether
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 3 ether);
        // THEN reward token balance of sponsorsManager is 7 ether
        assertEq(rewardToken.balanceOf(address(sponsorsManager)), 7 ether);
        // THEN coinbase balance of rewardDistributor is 1.5 ether
        assertEq(address(rewardDistributor).balance, 1.5 ether);
        // THEN coinbase balance of sponsorsManager is 3.5 ether
        assertEq(address(sponsorsManager).balance, 3.5 ether);
    }

    /**
     * SCENARIO: sends rewards and starts the distribution
     */
    function test_SendRewardsAndStartDistribution() public {
        // GIVEN a RewardDistributor contract with 10 ether of reward token
        rewardToken.transfer(address(rewardDistributor), 10 ether);
        // AND a foundation with 5 ether of coinbase
        Address.sendValue(payable(foundation), 5 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // WHEN foundation treasury calls sendRewardsAndStartDistribution transferring 2 ethers of reward token and
        // 3 of coinbase
        vm.startPrank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution{ value: 3 ether }(2 ether, 3 ether);
        // THEN reward token balance of gauge is 2 ether
        assertEq(rewardToken.balanceOf(address(gauge)), 2 ether);
        // THEN coinbase balance of gauge is 3 ether
        assertEq(address(gauge).balance, 3 ether);
    }
}
