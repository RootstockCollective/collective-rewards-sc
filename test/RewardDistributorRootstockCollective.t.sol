// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";

contract RewardDistributorRootstockCollectiveTest is BaseTest {
    function _setUp() internal override {
        // mint some rifTokens to this contract for reward distribution
        rifToken.mint(address(this), 100_000 ether);
        // mint some usdrifTokens to this contract for reward distribution
        usdrifToken.mint(address(this), 100_000 ether);
        // add some allocations to don't revert by zero division on the notifyRewardAmount
        vm.prank(alice);
        backersManager.allocate(gauge, 0.1 ether);
    }

    /**
     * SCENARIO: functions protected by onlyFoundationTreasury should revert when are not
     *  called by foundation treasury address
     */
    function test_OnlyFoundationTreasury() public {
        // GIVEN a RewardDistributorRootstockCollective contract
        vm.startPrank(alice);
        // WHEN alice calls sendRewards
        //  THEN tx reverts because caller is not the foundation treasury address
        vm.expectRevert(IGovernanceManagerRootstockCollective.NotFoundationTreasury.selector);
        rewardDistributor.sendRewards(1 ether, 0, 1 ether);
        // WHEN alice calls sendRewardsAndStartDistribution
        //  THEN tx reverts because caller is not the foundation treasury address

        vm.expectRevert(IGovernanceManagerRootstockCollective.NotFoundationTreasury.selector);
        rewardDistributor.sendRewardsAndStartDistribution(1 ether, 0, 1 ether);
    }

    /**
     * SCENARIO: sendRewards should revert trying to send more tokens than its balance
     */
    function test_InsufficientBalance() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 1 ether of rif token
        rifToken.transfer(address(rewardDistributor), 1 ether);
        vm.startPrank(foundation);
        // WHEN foundation treasury calls sendRewards trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rewardDistributor), 1 ether, 2 ether
            )
        );
        rewardDistributor.sendRewards(2 ether, 2 ether, 0 ether);

        // WHEN foundation treasury calls sendRewardsAndStartDistribution trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rewardDistributor), 1 ether, 2 ether
            )
        );
        rewardDistributor.sendRewardsAndStartDistribution(2 ether, 2 ether, 0 ether);
    }

    /**
     * SCENARIO: sendRewards should revert trying to send more native tokens than its balance
     */
    function test_InsufficientNativeBalance() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 1 ether of native tokens
        Address.sendValue(payable(address(rewardDistributor)), 1 ether);
        vm.startPrank(foundation);
        // WHEN foundation treasury calls sendRewards trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert();
        rewardDistributor.sendRewards(0, 0, 2 ether);

        // WHEN foundation treasury calls sendRewardsAndStartDistribution trying to transfer 2 ethers
        //  THEN tx reverts because insufficient balance
        vm.expectRevert();
        rewardDistributor.sendRewardsAndStartDistribution(0, 0, 2 ether);
    }

    /**
     * SCENARIO: sends rewards twice on one cycle and then on more time on the next one
     */
    function test_SendRewards() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 10 ether of rif token and 5 of native tokens
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        // WHEN foundation treasury calls sendRewards transferring 2 ethers of rif token and 1 of native tokens
        vm.startPrank(foundation);
        rewardDistributor.sendRewards(2 ether, 2 ether, 1 ether);
        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // AND foundation treasury calls sendRewards transferring 1 ethers of rif token and 0.5 of native tokens
        rewardDistributor.sendRewards(1 ether, 1 ether, 0.5 ether);
        // AND cycle finish
        _skipAndStartNewCycle();
        // AND foundation treasury calls sendRewards transferring 4 ethers of rif token and 2 of native tokens
        rewardDistributor.sendRewards(4 ether, 4 ether, 2 ether);

        // THEN rif token balance of rewardDistributor is 3 ether
        assertEq(rifToken.balanceOf(address(rewardDistributor)), 3 ether);
        // THEN rif token balance of backersManager is 7 ether
        assertEq(rifToken.balanceOf(address(backersManager)), 7 ether);
        // THEN usdrif token balance of rewardDistributor is 3 ether
        assertEq(usdrifToken.balanceOf(address(rewardDistributor)), 3 ether);
        // THEN usdrif token balance of backersManager is 7 ether
        assertEq(usdrifToken.balanceOf(address(backersManager)), 7 ether);
        // THEN native tokens balance of rewardDistributor is 1.5 ether
        assertEq(address(rewardDistributor).balance, 1.5 ether);
        // THEN native tokens balance of backersManager is 3.5 ether
        assertEq(address(backersManager).balance, 3.5 ether);
    }

    /**
     * SCENARIO: sends rewards and starts the distribution
     */
    function test_SendRewardsAndStartDistribution() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 10 ether of rif token
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        // AND a foundation with 5 ether of native tokens
        Address.sendValue(payable(foundation), 5 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // WHEN foundation treasury calls sendRewardsAndStartDistribution transferring 2 ethers of rif token and
        // 3 of native tokens
        vm.startPrank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution{ value: 3 ether }(2 ether, 0, 3 ether);
        // THEN rif token balance of gauge is 2 ether
        assertEq(rifToken.balanceOf(address(gauge)), 2 ether);
        // THEN native tokens balance of gauge is 3 ether
        assertEq(address(gauge).balance, 3 ether);
    }

    /**
     * SCENARIO: sends rewards twice on one cycle and then on more time on the next one with default amounts
     */
    function test_SendRewardsWithDefaultAmount() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 10 ether of rif token and 5 of native tokens
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        // WHEN foundation treasury calls sendRewardsWithDefaultAmount
        // setting as default values 2 ethers of rif token and 1 of native tokens
        vm.startPrank(foundation);
        rewardDistributor.setDefaultRewardAmount(2 ether, 2 ether, 1 ether);
        rewardDistributor.sendRewardsWithDefaultAmount();
        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // AND foundation treasury calls sendRewards transferring 1 ethers of rif token and 0.5 of native tokens
        rewardDistributor.sendRewards(1 ether, 1 ether, 0.5 ether);
        // AND cycle finish
        _skipAndStartNewCycle();
        // AND foundation treasury calls sendRewards transferring 4 ethers of rif token and 2 of native tokens
        rewardDistributor.sendRewards(4 ether, 4 ether, 2 ether);

        // THEN rif token balance of rewardDistributor is 3 ether
        assertEq(rifToken.balanceOf(address(rewardDistributor)), 3 ether);
        // THEN rif token balance of backersManager is 7 ether
        assertEq(rifToken.balanceOf(address(backersManager)), 7 ether);
        // THEN usdrif token balance of rewardDistributor is 3 ether
        assertEq(usdrifToken.balanceOf(address(rewardDistributor)), 3 ether);
        // THEN usdrif token balance of backersManager is 7 ether
        assertEq(usdrifToken.balanceOf(address(backersManager)), 7 ether);
        // THEN native tokens balance of rewardDistributor is 1.5 ether
        assertEq(address(rewardDistributor).balance, 1.5 ether);
        // THEN native tokens balance of backersManager is 3.5 ether
        assertEq(address(backersManager).balance, 3.5 ether);
    }

    /**
     * SCENARIO: sends rewards and starts the distribution with default amounts
     */
    function test_SendRewardsAndStartDistributionWithDefaultAmount() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 10 ether of rif token
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        // AND a foundation with 5 ether of native tokens
        Address.sendValue(payable(foundation), 5 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();
        // WHEN foundation treasury calls sendRewardsAndStartDistribution transferring 2 ethers of rif token and
        // 3 of native tokens
        vm.startPrank(foundation);
        rewardDistributor.setDefaultRewardAmount(2 ether, 0, 3 ether);
        rewardDistributor.sendRewardsAndStartDistributionWithDefaultAmount{ value: 3 ether }();
        // THEN rif token balance of gauge is 2 ether
        assertEq(rifToken.balanceOf(address(gauge)), 2 ether);
        // THEN native tokens balance of gauge is 3 ether
        assertEq(address(gauge).balance, 3 ether);
    }

    function test_RevertSendRewardsAndStartDistributionWithDefaultAmountTwicePerCycle() public {
        // GIVEN a funded Reward Distributor contract
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(foundation), 5 ether);
        _skipToStartDistributionWindow();
        // WHEN cycle is funded with default amounts and distribution is started
        vm.startPrank(foundation);
        rewardDistributor.setDefaultRewardAmount(2 ether, 0, 1 ether);
        rewardDistributor.sendRewardsAndStartDistributionWithDefaultAmount{ value: 1 ether }();

        // THEN the same cycle cannot be funded again
        vm.expectRevert(RewardDistributorRootstockCollective.CycleAlreadyFunded.selector);
        rewardDistributor.sendRewardsAndStartDistributionWithDefaultAmount{ value: 1 ether }();
    }

    /**
     * SCENARIO: Revert if cycle is funded with default amounts more than once per cycle
     */
    function test_RevertSendRewardsWithDefaultAmountTwicePerCycle() public {
        // GIVEN a funded Reward Distributor contract
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        // WHEN the default rewards are set
        vm.startPrank(foundation);
        rewardDistributor.setDefaultRewardAmount(2 ether, 0, 1 ether);
        // AND the rewards are sent by permissionless address
        vm.startPrank(bob);
        rewardDistributor.sendRewardsWithDefaultAmount();
        // AND half cycle pass
        _skipRemainingCycleFraction(2);
        // THEN the same cycle cannot be funded again
        vm.expectRevert(RewardDistributorRootstockCollective.CycleAlreadyFunded.selector);
        rewardDistributor.sendRewardsWithDefaultAmount();
    }

    /**
     * SCENARIO: Send default rewards once per cycle restriction is reseted in a new cycle
     */
    function test_SendRewardsWithDefaultAmountInNewCycle() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 10 ether of rif token and 5 of native tokens
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        // WHEN foundation treasury calls sendRewardsWithDefaultAmount
        vm.startPrank(foundation);
        rewardDistributor.setDefaultRewardAmount(2 ether, 0, 1 ether);
        rewardDistributor.sendRewardsWithDefaultAmount();
        // AND cycle finish
        _skipAndStartNewCycle();
        // THEN foundation treasury can send rewards again in the new cycle
        rewardDistributor.sendRewardsWithDefaultAmount();
    }

    /**
     * SCENARIO: should fail when sends rewards several times on one cycle with default amounts
     */
    function test_FailSendRewardsWithDefaultAmountForTokens() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 10 ether of rif token and 5 of native tokens
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        // WHEN foundation treasury calls sendRewardsWithDefaultAmount
        // setting as default values 6 ethers of rif token and 1 of native tokens
        vm.startPrank(foundation);
        rewardDistributor.setDefaultRewardAmount(6 ether, 0, 1 ether);
        rewardDistributor.sendRewardsWithDefaultAmount();
        // should fail because send the default Token amount twice exceeding the balance
        vm.expectRevert();
        rewardDistributor.sendRewardsWithDefaultAmount();
    }

    /**
     * SCENARIO: should fail when sends rewards several times on one cycle with default amounts
     */
    function test_FailSendRewardsWithDefaultAmountForNativeTokens() public {
        // GIVEN a RewardDistributorRootstockCollective contract with 10 ether of rif token and 5 of native tokens
        rifToken.transfer(address(rewardDistributor), 10 ether);
        usdrifToken.transfer(address(rewardDistributor), 10 ether);
        Address.sendValue(payable(address(rewardDistributor)), 5 ether);
        // WHEN foundation treasury calls sendRewardsWithDefaultAmount
        // setting as default values 6 ethers of rif token and 1 of native tokens
        vm.startPrank(foundation);
        rewardDistributor.setDefaultRewardAmount(1 ether, 0, 3 ether);
        rewardDistributor.sendRewardsWithDefaultAmount();
        // should fail because send the default native tokens amount twice exceeding the balance
        vm.expectRevert();
        rewardDistributor.sendRewardsWithDefaultAmount();
    }
}
