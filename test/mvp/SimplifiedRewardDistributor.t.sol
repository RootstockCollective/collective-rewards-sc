// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { MVPBaseTest, SimplifiedRewardDistributor } from "./MVPBaseTest.sol";
import { SimplifiedBuilderRegistry } from "../../src/mvp/SimplifiedBuilderRegistry.sol";
import { Governed } from "../../src/governance/Governed.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract SimplifiedRewardDistributorTest is MVPBaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event StateUpdate(
        address indexed builder_,
        SimplifiedBuilderRegistry.BuilderState previousState_,
        SimplifiedBuilderRegistry.BuilderState newState_
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
        simplifiedRewardDistributor.whitelistBuilder(builder);
    }

    /**
     * SCENARIO: kycApprover activates a new builder
     */
    function test_ActivateBuilder() public {
        // GIVEN a kycApprover
        vm.startPrank(kycApprover);
        // AND a new builder
        address payable newBuilder = payable(makeAddr("newBuilder"));
        // WHEN calls activateBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(
            newBuilder,
            SimplifiedBuilderRegistry.BuilderState.Pending,
            SimplifiedBuilderRegistry.BuilderState.KYCApproved
        );
        simplifiedRewardDistributor.activateBuilder(newBuilder, newBuilder);

        // THEN builder.state is KYCApproved
        assertEq(
            uint256(simplifiedRewardDistributor.getState(newBuilder)),
            uint256(SimplifiedBuilderRegistry.BuilderState.KYCApproved)
        );

        // THEN new builder rewards receiver is the same as the new builder
        assertEq(simplifiedRewardDistributor.getRewardReceiver(newBuilder), newBuilder);
    }

    /**
     * SCENARIO: activateBuilder should reverts if the state is not Pending
     */
    function test_ActivateBuilderWrongStatus() public {
        // GIVEN a kycApprover
        vm.startPrank(kycApprover);
        // AND a whitelisted builder
        //  WHEN tries to activateBuilder
        //   THEN tx reverts because is not in the required state
        vm.expectRevert(
            abi.encodeWithSelector(
                SimplifiedBuilderRegistry.RequiredState.selector, SimplifiedBuilderRegistry.BuilderState.Pending
            )
        );
        simplifiedRewardDistributor.activateBuilder(builder, rewardReceiver);
    }

    /**
     * SCENARIO: Governor whitelist a new builder
     */
    function test_WhitelistBuilder() public {
        // GIVEN a kycApprover
        vm.startPrank(kycApprover);
        // AND a new builder activated
        address payable newBuilder = payable(makeAddr("newBuilder"));
        simplifiedRewardDistributor.activateBuilder(newBuilder, newBuilder);

        // WHEN calls whitelistBuilder
        //  THEN StateUpdate event is emitted
        vm.expectEmit();
        emit StateUpdate(
            newBuilder,
            SimplifiedBuilderRegistry.BuilderState.KYCApproved,
            SimplifiedBuilderRegistry.BuilderState.Whitelisted
        );
        simplifiedRewardDistributor.whitelistBuilder(newBuilder);

        // THEN newBuilder.state is Whitelisted
        assertEq(
            uint256(simplifiedRewardDistributor.getState(newBuilder)),
            uint256(SimplifiedBuilderRegistry.BuilderState.Whitelisted)
        );

        // THEN getWhitelistedBuildersLength is 3
        assertEq(simplifiedRewardDistributor.getWhitelistedBuildersLength(), 3);
    }

    /**
     * SCENARIO: whitelistBuilder should reverts if the state is not KYCApproved
     */
    function test_WhitelistBuilderWrongStatus() public {
        // GIVEN a whitelisted builder
        //  WHEN tries to whitelistBuilder
        //   THEN tx reverts because is not the required state
        vm.expectRevert(
            abi.encodeWithSelector(
                SimplifiedBuilderRegistry.RequiredState.selector, SimplifiedBuilderRegistry.BuilderState.KYCApproved
            )
        );
        simplifiedRewardDistributor.whitelistBuilder(builder);
    }

    /**
     * SCENARIO: sendRewardToken should revert trying to send more reward tokens than its balance
     */
    function test_InsufficientBalanceRewardToken() public {
        // GIVEN a simplifiedRewardDistributor contract with 1 ether of reward token
        rewardToken.transfer(address(simplifiedRewardDistributor), 1 ether);
        // WHEN call distributeRewards trying to distribute 1 ether to each builder
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(simplifiedRewardDistributor), 0 ether, 1 ether
            )
        );
        simplifiedRewardDistributor.distributeRewards(2 ether, 0);
    }

    /**
     * SCENARIO: distributeRewards should revert trying to send more coinbase than its balance
     */
    function test_InsufficientBalanceCoinbase() public {
        // GIVEN a simplifiedRewardDistributor contract with 1 ether of coinbase
        Address.sendValue(payable(address(simplifiedRewardDistributor)), 1 ether);
        // WHEN call distributeRewards trying to distribute 1 ether to each builder
        //  THEN tx reverts because insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(Address.AddressInsufficientBalance.selector, address(simplifiedRewardDistributor))
        );
        simplifiedRewardDistributor.distributeRewards(0, 2 ether);
    }

    /**
     * SCENARIO: distributeRewards equally to builders
     */
    function test_DistributeRewards() public {
        // GIVEN a simplifiedRewardDistributor contract with 4 ether of reward token and 3 ether of coinbase
        rewardToken.transfer(address(simplifiedRewardDistributor), 4 ether);
        Address.sendValue(payable(address(simplifiedRewardDistributor)), 3 ether);
        simplifiedRewardDistributor.distributeRewards(4 ether, 3 ether);

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
}
