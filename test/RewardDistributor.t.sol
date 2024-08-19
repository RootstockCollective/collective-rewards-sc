// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest, RewardDistributor } from "./BaseTest.sol";
import { EpochLib } from "../src/libraries/EpochLib.sol";
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
        // WHEN alice calls sendRewardToken
        //  THEN tx reverts because caller is not the foundation treasury address
        vm.expectRevert(RewardDistributor.NotFoundationTreasury.selector);
        rewardDistributor.sendRewardToken(1 ether, 1 ether);
        // WHEN alice calls sendRewardTokenAndStartDistribution
        //  THEN tx reverts because caller is not the foundation treasury address
        vm.expectRevert(RewardDistributor.NotFoundationTreasury.selector);
        rewardDistributor.sendRewardTokenAndStartDistribution(1 ether, 1 ether);
    }

    /**
     * SCENARIO: sendRewardToken should revert trying to send more tokens than its balance
     */
    function test_InsufficientBalance() public {
        // GIVEN a RewardDistributor contract with 1 ether of reward token
        rewardToken.transfer(address(rewardDistributor), 1 ether);
        vm.startPrank(foundation);
        // WHEN foundation treasury calls sendRewardToken trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rewardDistributor), 1 ether, 2 ether
            )
        );
        rewardDistributor.sendRewardToken(2 ether, 0 ether);

        // WHEN foundation treasury calls sendRewardTokenAndStartDistribution trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rewardDistributor), 1 ether, 2 ether
            )
        );
        rewardDistributor.sendRewardTokenAndStartDistribution(2 ether, 0 ether);
    }

    /**
     * SCENARIO: sendRewardToken should revert trying to send more Coinbase than its balance
     */
    function test_InsufficientCoinbaseBalance() public {
        // GIVEN a RewardDistributor contract with 1 ether of coinbase
        Address.sendValue(payable(address(rewardDistributor)), 1 ether);
        vm.startPrank(foundation);
        // WHEN foundation treasury calls sendRewardToken trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert();
        rewardDistributor.sendRewardToken(0, 2 ether);

        // WHEN foundation treasury calls sendRewardTokenAndStartDistribution trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert();
        rewardDistributor.sendRewardTokenAndStartDistribution(0, 2 ether);
    }

    /**
     * SCENARIO: sends rewards tokens twice on one epoch and then on more time on the next one
     */
    function test_SendRewardToken() public {
        // GIVEN a RewardDistributor contract with 10 ether of reward token and 5 of coinbase
        rewardToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        uint256 _epoch1Timestamp = EpochLib._epochStart(block.timestamp);
        // WHEN foundation treasury calls sendRewardToken transferring 2 ethers of reward token and 1 of coinbase
        vm.startPrank(foundation);
        rewardDistributor.sendRewardToken(2 ether, 1 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
        // AND foundation treasury calls sendRewardToken transferring 1 ethers of reward token and 0.5 of coinbase
        rewardDistributor.sendRewardToken(1 ether, 0.5 ether);
        // AND epoch finish
        _skipAndStartNewEpoch();
        uint256 _epoch2Timestamp = EpochLib._epochStart(block.timestamp);
        // AND foundation treasury calls sendRewardToken transferring 4 ethers of reward token and 2 of coinbase
        rewardDistributor.sendRewardToken(4 ether, 2 ether);

        // THEN reward token balance of rewardDistributor is 3 ether
        assertEq(rewardToken.balanceOf(address(rewardDistributor)), 3 ether);
        // THEN reward token balance of sponsorsManager is 7 ether
        assertEq(rewardToken.balanceOf(address(sponsorsManager)), 7 ether);
        // THEN coinbase balance of rewardDistributor is 1.5 ether
        assertEq(address(rewardDistributor).balance, 1.5 ether);
        // THEN coinbase balance of sponsorsManager is 3.5 ether
        assertEq(address(sponsorsManager).balance, 3.5 ether);

        // THEN reward token sent on epoch 1 is 3 ether
        assertEq(rewardDistributor.rewardTokenAmountPerEpoch(_epoch1Timestamp), 3 ether);
        // THEN reward token sent on epoch 2 is 4 ether
        assertEq(rewardDistributor.rewardTokenAmountPerEpoch(_epoch2Timestamp), 4 ether);
        // THEN coinbase sent on epoch 1 is 1.5 ether
        assertEq(rewardDistributor.rewardCoinbaseAmountPerEpoch(_epoch1Timestamp), 1.5 ether);
        // THEN coinbase sent on epoch 2 is 2 ether
        assertEq(rewardDistributor.rewardCoinbaseAmountPerEpoch(_epoch2Timestamp), 2 ether);
    }

    /**
     * SCENARIO: sends rewards tokens and starts the distribution
     */
    function test_SendRewardTokenAndStartDistribution() public {
        // GIVEN a RewardDistributor contract with 10 ether of reward token
        rewardToken.transfer(address(rewardDistributor), 10 ether);
        // AND a foundation with 5 ether of coinbase
        Address.sendValue(payable(foundation), 5 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // WHEN foundation treasury calls sendRewardTokenAndStartDistribution transferring 2 ethers of reward token and
        // 3 of coinbase
        vm.startPrank(foundation);
        rewardDistributor.sendRewardTokenAndStartDistribution{ value: 3 ether }(2 ether, 3 ether);
        // THEN reward token balance of gauge is 2 ether
        assertEq(rewardToken.balanceOf(address(gauge)), 2 ether);
        // THEN coinbase balance of gauge is 3 ether
        assertEq(address(gauge).balance, 3 ether);
    }
}
