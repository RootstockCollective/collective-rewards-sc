// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MVPBaseTest } from "./MVPBaseTest.sol";
import { Governed } from "../../src/governance/Governed.sol";
import { UtilsLib } from "../../src/libraries/UtilsLib.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SimplifiedRewardDistributor } from "../../src/mvp/SimplifiedRewardDistributor.sol";

contract SimplifiedRewardDistributorTest is MVPBaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event Whitelisted(address indexed builder_);
    event Unwhitelisted(address indexed builder_);
    event RewardDistributed(
        address indexed rewardToken_, address indexed builder_, address indexed rewardReceiver_, uint256 amount_
    );

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
        //  THEN Whitelisted event is emitted
        vm.expectEmit();
        emit Whitelisted(_newBuilder);
        simplifiedRewardDistributor.whitelistBuilder(_newBuilder, _newBuilder);
        // THEN newBuilder is whitelisted
        assertTrue(simplifiedRewardDistributor.isWhitelisted(_newBuilder));
        // THEN the new reward receiver is the new builder
        assertEq(simplifiedRewardDistributor.builderRewardReceiver(_newBuilder), _newBuilder);
        // THEN newBuilder is on index 2
        assertEq(simplifiedRewardDistributor.getWhitelistedBuilder(2), _newBuilder);
        // THEN getWhitelistedBuildersLength is 3
        assertEq(simplifiedRewardDistributor.getWhitelistedBuildersLength(), 3);
        // THEN getWhitelistedBuildersArray returns the entire array with all the whitelisted builders
        address[] memory _whitelistedBuildersArray = simplifiedRewardDistributor.getWhitelistedBuildersArray();
        assertEq(_whitelistedBuildersArray.length, 3);
        assertEq(_whitelistedBuildersArray[0], builder);
        assertEq(_whitelistedBuildersArray[1], builder2);
        assertEq(_whitelistedBuildersArray[2], _newBuilder);
    }

    /**
     * SCENARIO: whitelist a whitelisted builder fails
     */
    function test_WhitelistBuilderTwice() public {
        // GIVEN a whitelisted builder
        //  WHEN tries to whitelist it again
        //   THEN reverts
        vm.expectRevert(SimplifiedRewardDistributor.WhitelistStatusWithoutUpdate.selector);
        simplifiedRewardDistributor.whitelistBuilder(builder, rewardReceiver);
    }

    /**
     * SCENARIO: Governor remove builder from whitelist
     */
    function test_RemoveWhitelistedBuilder() public {
        // GIVEN a whitelisted builder
        //  WHEN calls removeWhitelistedBuilder
        //   THEN Unwhitelisted event is emitted
        vm.expectEmit();
        emit Unwhitelisted(builder);
        simplifiedRewardDistributor.removeWhitelistedBuilder(builder);
        // THEN builder is not whitelisted
        assertFalse(simplifiedRewardDistributor.isWhitelisted(builder));
        // THEN the reward receiver is 0
        assertEq(simplifiedRewardDistributor.builderRewardReceiver(builder), address(0));
        // THEN getWhitelistedBuildersLength is 1
        assertEq(simplifiedRewardDistributor.getWhitelistedBuildersLength(), 1);
        // THEN getWhitelistedBuildersArray returns the entire array with all the whitelisted builders
        address[] memory _whitelistedBuildersArray = simplifiedRewardDistributor.getWhitelistedBuildersArray();
        assertEq(_whitelistedBuildersArray.length, 1);
        assertEq(_whitelistedBuildersArray[0], builder2);
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
        //   THEN RewardDistributed event for rewardToken is emitted for builder
        vm.expectEmit();
        emit RewardDistributed(address(rewardToken), builder, rewardReceiver, 2 ether);
        //   THEN RewardDistributed event for coinbase is emitted for builder
        vm.expectEmit();
        emit RewardDistributed(UtilsLib._COINBASE_ADDRESS, builder, rewardReceiver, 1.5 ether);

        //   THEN RewardDistributed event for coinbase is emitted for builder2
        vm.expectEmit();
        emit RewardDistributed(address(rewardToken), builder2, rewardReceiver2, 2 ether);
        //   THEN RewardDistributed event for coinbase is emitted for builder2
        vm.expectEmit();
        emit RewardDistributed(UtilsLib._COINBASE_ADDRESS, builder2, rewardReceiver2, 1.5 ether);
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

    /**
     * SCENARIO: a malicious builder tries to waste gas in the fallback function, the coinbase transfer fails
     *  and the other distributions are not blocked. The remaining balance stays within the simplifiedRewardDistributor
     *  contract
     */
    function test_MaliciousBuilderDoesNotReceiveCoinbase() public {
        // GIVEN a simplifiedRewardDistributor contract with 8 ether of reward token
        rewardToken.transfer(address(simplifiedRewardDistributor), 8 ether);
        // AND a malicious builder is added to the whitelist
        address _maliciousBuilder = makeAddr("maliciousBuilder");
        address payable _maliciousReceiver = payable(address(new MaliciousReceiver()));
        simplifiedRewardDistributor.whitelistBuilder(_maliciousBuilder, _maliciousReceiver);
        // AND another builder is added to the whitelist, so malicious builder is not the last one
        address _newBuilder = makeAddr("newBuilder");
        simplifiedRewardDistributor.whitelistBuilder(_newBuilder, payable(_newBuilder));

        // WHEN distribute is executed sending 16 ethers of coinbase malicious builder coinbase transfer failed
        // THEN simplifiedRewardDistributor is emitted for rewardToken for malicious builder
        vm.expectEmit();
        emit RewardDistributed(address(rewardToken), _maliciousBuilder, _maliciousReceiver, 2 ether);
        simplifiedRewardDistributor.distribute{ value: 16 ether }();

        // THEN maliciousReceiver reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(_maliciousReceiver), 2 ether);
        // THEN maliciousReceiver coinbase balance is 0 ether
        assertEq(_maliciousReceiver.balance, 0);

        // THEN simplifiedRewardDistributor reward token balance is 0 ether, were all distributed
        assertEq(rewardToken.balanceOf(address(simplifiedRewardDistributor)), 0);
        // THEN rewardReceiver reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver), 2 ether);
        // THEN rewardReceiver2 reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(rewardReceiver2), 2 ether);
        // THEN _newBuilder reward token balance is 2 ether
        assertEq(rewardToken.balanceOf(_newBuilder), 2 ether);

        // THEN simplifiedRewardDistributor coinbase balance is 4 ether, malicious builder portion remains there
        assertEq(address(simplifiedRewardDistributor).balance, 4 ether);
        // THEN rewardReceiver coinbase balance is 4 ether
        assertEq(rewardReceiver.balance, 4 ether);
        // THEN rewardReceiver2 coinbase balance is 4 ether
        assertEq(rewardReceiver2.balance, 4 ether);
        // THEN _newBuilder coinbase balance is 4 ether
        assertEq(_newBuilder.balance, 4 ether);
    }
}

/**
 * @title MaliciousReceiver
 * @notice this contract is used in test_MaliciousBuilderDoesNotReceiveCoinbase to validate that a malicious builder
 *  cannot block the distribution for the other builders
 */
contract MaliciousReceiver {
    uint256 public burnGas;

    receive() external payable {
        for (uint256 _i = 0; _i <= 5; _i++) {
            burnGas++;
        }
    }
}
