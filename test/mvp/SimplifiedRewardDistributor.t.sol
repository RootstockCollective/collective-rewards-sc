// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { MVPBaseTest } from "./MVPBaseTest.sol";
import { Governed } from "../../src/governance/Governed.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SimplifiedRewardDistributor } from "../../src/mvp/SimplifiedRewardDistributor.sol";

contract SimplifiedRewardDistributorTest is MVPBaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    /**
     * SCENARIO: functions protected by OnlyGovernor should revert when are not
     *  called by Governor
     */
    function test_OnlyGovernor() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);

        // GIVEN mock authorized is false
        changeExecutorMock.setIsAuthorized(false);

        // WHEN alice calls whitelistBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        simplifiedRewardDistributor.whitelistBuilder(builder, rewardReceiver);

        // WHEN alice calls removeWhitelistedBuilder
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        simplifiedRewardDistributor.removeWhitelistedBuilder(builder);
    }

    /**
     * SCENARIO: Governor whitelist a new builder
     */
    function test_WhitelistBuilder() public {
        // GIVEN a new builder
        address payable _newBuilder = payable(makeAddr("newBuilder"));
        // WHEN calls whitelistBuilder
        simplifiedRewardDistributor.whitelistBuilder(_newBuilder, _newBuilder);
        // THEN newBuilder is whitelisted
        assertTrue(simplifiedRewardDistributor.isWhitelisted(_newBuilder));
        // THEN the new reward receiver is the new builder
        assertEq(simplifiedRewardDistributor.builderRewardReceiver(_newBuilder), _newBuilder);
        // THEN newBuilder is on index 2
        assertEq(simplifiedRewardDistributor.getWhitelistedBuilder(2), _newBuilder);
        // THEN getWhitelistedBuildersLength is 3
        assertEq(simplifiedRewardDistributor.getWhitelistedBuildersLength(), 3);
    }

    /**
     * SCENARIO: whitelist a whistelited builder fails
     */
    function test_WhistelitBuilderTwice() public {
        // GIVEN a whitelisted builder
        //  WHEN tries to whistelist it again
        // THEN reverts
        vm.expectRevert(SimplifiedRewardDistributor.WhitelistStatusWithoutUpdate.selector);
        simplifiedRewardDistributor.whitelistBuilder(builder, rewardReceiver);
    }

    /**
     * SCENARIO: Governor remove builder from whitelist
     */
    function test_RemoveWhitelistedBuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN calls removeWhitelistedBuilder
        simplifiedRewardDistributor.removeWhitelistedBuilder(builder);
        // THEN builder is not whitelisted
        assertFalse(simplifiedRewardDistributor.isWhitelisted(builder));
        // THEN the reward receiver is 0
        assertEq(simplifiedRewardDistributor.builderRewardReceiver(builder), address(0));
        // THEN getWhitelistedBuildersLength is 1
        assertEq(simplifiedRewardDistributor.getWhitelistedBuildersLength(), 1);
    }

    /**
     * SCENARIO: remove a non-whitelisted builder reverts
     */
    function test_RemoveNonWhitelistedBuilder() public {
        // GIVEN a new builder
        address payable _newBuilder = payable(makeAddr("newBuilder"));
        //  WHEN tries to remove it form the whitelist
        // THEN reverts
        vm.expectRevert(SimplifiedRewardDistributor.WhitelistStatusWithoutUpdate.selector);
        simplifiedRewardDistributor.removeWhitelistedBuilder(_newBuilder);
    }

    /**
     * SCENARIO: distribute reward token and coinbase equally to builders
     */
    function test_Distribute() public {
        // GIVEN a simplifiedRewardDistributor contract with 4 ether of reward token and 3 ether of coinbase
        rewardToken.transfer(address(simplifiedRewardDistributor), 4 ether);
        Address.sendValue(payable(address(simplifiedRewardDistributor)), 3 ether);
        // WHEN distribute is executed
        simplifiedRewardDistributor.distribute();

        // THEN simplifiedRewardDistributor reward token balance is 0 ether
        assertEq(rewardToken.balanceOf(address(simplifiedRewardDistributor)), 0);
        // THEN rewardReceiver reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver), 2 ether);
        // THEN rewardReceiver2 reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver2), 2 ether);

        // THEN simplifiedRewardDistributor coinbase balance is 0 ether
        assertEq(address(simplifiedRewardDistributor).balance, 0 ether);
        // THEN rewardReceiver coinbase balance is 1.5 ether
        assertEq(rewardReceiver.balance, 1.5 ether);
        // THEN rewardReceiver2 coinbase balance is 1.5 ether
        assertEq(rewardReceiver2.balance, 1.5 ether);
    }

    /**
     * SCENARIO: distribute sending coinbase
     */
    function test_DistributeSendingCoinbase() public {
        // GIVEN a simplifiedRewardDistributor contract with 4 ether of reward token
        rewardToken.transfer(address(simplifiedRewardDistributor), 4 ether);
        // WHEN distribute is executed sending 3 ethers of coinbase
        simplifiedRewardDistributor.distribute{ value: 3 ether }();

        // THEN simplifiedRewardDistributor reward token balance is 0 ether
        assertEq(rewardToken.balanceOf(address(simplifiedRewardDistributor)), 0);
        // THEN rewardReceiver reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver), 2 ether);
        // THEN rewardReceiver2 reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver2), 2 ether);

        // THEN simplifiedRewardDistributor coinbase balance is 0 ether
        assertEq(address(simplifiedRewardDistributor).balance, 0 ether);
        // THEN rewardReceiver coinbase balance is 1.5 ether
        assertEq(rewardReceiver.balance, 1.5 ether);
        // THEN rewardReceiver2 coinbase balance is 1.5 ether
        assertEq(rewardReceiver2.balance, 1.5 ether);
    }

    /**
     * SCENARIO: distribute only reward token equally to builders
     */
    function test_DistributeRewardToken() public {
        // GIVEN a simplifiedRewardDistributor contract with 4 ether of reward token and 3 ether of coinbase
        rewardToken.transfer(address(simplifiedRewardDistributor), 4 ether);
        Address.sendValue(payable(address(simplifiedRewardDistributor)), 3 ether);
        // WHEN distributeRewardToken is executed
        simplifiedRewardDistributor.distributeRewardToken();

        // THEN simplifiedRewardDistributor reward token balance is 0 ether
        assertEq(rewardToken.balanceOf(address(simplifiedRewardDistributor)), 0);
        // THEN rewardReceiver reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver), 2 ether);
        // THEN rewardReceiver2 reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver2), 2 ether);

        // THEN simplifiedRewardDistributor coinbase balance is 3 ether
        assertEq(address(simplifiedRewardDistributor).balance, 3 ether);
        // THEN rewardReceiver coinbase balance is 0 ether
        assertEq(rewardReceiver.balance, 0 ether);
        // THEN rewardReceiver2 coinbase balance is 0 ether
        assertEq(rewardReceiver2.balance, 0 ether);
    }

    /**
     * SCENARIO: distribute only coinbase equally to builders
     */
    function test_DistributeCoinbase() public {
        // GIVEN a simplifiedRewardDistributor contract with 4 ether of reward token
        rewardToken.transfer(address(simplifiedRewardDistributor), 4 ether);
        // WHEN distribute is executed sending 3 ethers of coinbase
        simplifiedRewardDistributor.distributeCoinbase{ value: 3 ether }();

        // THEN simplifiedRewardDistributor reward token balance is 4 ether
        assertEq(rewardToken.balanceOf(address(simplifiedRewardDistributor)), 4 ether);
        // THEN rewardReceiver reward token balance is 0 ether
        assertEq(rewardToken.balanceOf(rewardReceiver), 0 ether);
        // THEN rewardReceiver2 reward token balance is 0 ether
        assertEq(rewardToken.balanceOf(rewardReceiver2), 0 ether);

        // THEN simplifiedRewardDistributor coinbase balance is 0 ether
        assertEq(address(simplifiedRewardDistributor).balance, 0 ether);
        // THEN rewardReceiver coinbase balance is 1.5 ether
        assertEq(rewardReceiver.balance, 1.5 ether);
        // THEN rewardReceiver2 coinbase balance is 1.5 ether
        assertEq(rewardReceiver2.balance, 1.5 ether);
    }
}
