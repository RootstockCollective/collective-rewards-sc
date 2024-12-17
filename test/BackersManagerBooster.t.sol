// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { stdStorage, StdStorage } from "forge-std/src/Test.sol";
import { BaseTest } from "./BaseTest.sol";
import { BoosterMock } from "./mock/BoosterMock.sol";
import { IBoosterRootstockCollective as IBooster } from "src/interfaces/IBoosterRootstockCollective.sol";

contract BackersManagerRootstockCollectiveTest is BaseTest {
    using stdStorage for StdStorage;
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------

    event NewAllocation(address indexed backer_, address indexed gauge_, uint256 allocation_);
    event NotifyReward(address indexed rewardToken_, address indexed sender_, uint256 amount_);
    event RewardDistributionStarted(address indexed sender_);
    event RewardDistributed(address indexed sender_);
    event RewardDistributionFinished(address indexed sender_);

    IBooster public boosterMock;

    function _setUp() internal override {
        BoosterMock _boosterMock = new BoosterMock();
        _boosterMock.mint(alice, 1);
        _boosterMock.mint(bob, 2);
        boosterMock = IBooster(address(_boosterMock));
        backersManager.whitelistBoosters(boosterMock, 2);
    }

    /**
     * SCENARIO: alice and bob allocates to 2 gauges and distribute rewards to them
     */
    function test_BoosterDistribute() public {
        // GIVEN a BackerManager contract
        vm.startPrank(alice);
        uint256 _tokenId = 1;
        // AND alice allocates 2 ether to builder and 6 ether to builder2
        backersManager.allocateWithBooster(IBooster(boosterMock), _tokenId, gauge, 2 ether);
        backersManager.allocateWithBooster(IBooster(boosterMock), _tokenId, gauge2, 6 ether);
        vm.stopPrank();

        _tokenId = 2;
        // AND bob allocates 4 ether to builder and 10 ether to builder2
        vm.startPrank(bob);
        backersManager.allocateWithBooster(IBooster(boosterMock), _tokenId, gauge, 4 ether);
        backersManager.allocateWithBooster(IBooster(boosterMock), _tokenId, gauge2, 10 ether);
        vm.stopPrank();

        //  AND 100 ether reward are added
        backersManager.notifyRewardAmount(100 ether);
        // AND distribution window starts
        _skipToStartDistributionWindow();

        //  WHEN distribute is executed
        //   THEN RewardDistributionStarted event is emitted
        vm.expectEmit();
        emit RewardDistributionStarted(address(this));
        //   THEN RewardDistributed event is emitted
        vm.expectEmit();
        emit RewardDistributed(address(this));
        //   THEN RewardDistributionFinished event is emitted
        vm.expectEmit();
        emit RewardDistributionFinished(address(this));
        backersManager.startDistribution();
        // THEN reward token balance of gauge is 27.272727272727272727 = 100 * 6 / 22
        assertEq(rewardToken.balanceOf(address(gauge)), 27_272_727_272_727_272_727);
        // THEN reward token balance of gauge2 is 72.727272727272727272 = 100 * 16 / 22
        assertEq(rewardToken.balanceOf(address(gauge2)), 72_727_272_727_272_727_272);
    }
}
