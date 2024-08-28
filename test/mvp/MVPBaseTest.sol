// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";

import { Deploy as MockTokenDeployer } from "script/test_mock/MockToken.s.sol";
import { Deploy as ChangeExecutorMockDeployer } from "script/test_mock/ChangeExecutorMock.s.sol";
import { Deploy as SimplifiedRewardDistributorDeployer } from "script/mvp/SimplifiedRewardDistributor.s.sol";
import { ChangeExecutorMock } from "../mock/ChangeExecutorMock.sol";
import { ERC20Mock } from "../mock/ERC20Mock.sol";
import { SimplifiedRewardDistributor } from "src/mvp/SimplifiedRewardDistributor.sol";

contract MVPBaseTest is Test {
    ChangeExecutorMock public changeExecutorMock;
    ChangeExecutorMock public changeExecutorMockImpl;
    ERC20Mock public rewardToken;
    SimplifiedRewardDistributor public simplifiedRewardDistributor;
    SimplifiedRewardDistributor public simplifiedRewardDistributorImpl;

    address internal governor = makeAddr("governor");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal builder = makeAddr("builder");
    address internal builder2 = makeAddr("builder2");
    address payable internal rewardReceiver = payable(makeAddr("rewardReceiver"));
    address payable internal rewardReceiver2 = payable(makeAddr("rewardReceiver2"));

    function setUp() public {
        (changeExecutorMock, changeExecutorMockImpl) = new ChangeExecutorMockDeployer().run(governor);
        MockTokenDeployer mockTokenDeployer = new MockTokenDeployer();
        rewardToken = mockTokenDeployer.run(0);
        (simplifiedRewardDistributor, simplifiedRewardDistributorImpl) =
            new SimplifiedRewardDistributorDeployer().run(address(changeExecutorMock), address(rewardToken));

        // allow to execute all the functions protected by governance
        changeExecutorMock.setIsAuthorized(true);

        // mint some rewardToken and coinbase to the test contract
        rewardToken.mint(address(this), 100_000 ether);
        vm.deal(address(this), 100_000 ether);

        simplifiedRewardDistributor.whitelistBuilder(builder, rewardReceiver);
        simplifiedRewardDistributor.whitelistBuilder(builder2, rewardReceiver2);

        _setUp();
    }

    /// @dev Implement this if you want a custom configured deployment
    function _setUp() internal virtual { }
}
