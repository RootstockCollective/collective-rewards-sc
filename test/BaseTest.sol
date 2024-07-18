// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { ERC20Mock } from "./mock/ERC20Mock.sol";
import { GaugeFactory } from "../src/gauge/GaugeFactory.sol";
import { Gauge } from "../src/gauge/Gauge.sol";
import { SponsorsManager } from "../src/SponsorsManager.sol";
import { EpochLib } from "../src/libraries/EpochLib.sol";

contract BaseTest is Test {
    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    GaugeFactory public gaugeFactory;
    Gauge public gauge;
    SponsorsManager public sponsorsManager;
    uint256 public initialTimestamp;
    uint256 public epochDuration;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        stakingToken = new ERC20Mock();
        rewardToken = new ERC20Mock();
        gaugeFactory = new GaugeFactory();
        sponsorsManager = new SponsorsManager(address(rewardToken), address(gaugeFactory));
        gauge = Gauge(sponsorsManager.createGauge());
        initialTimestamp = block.timestamp;
        epochDuration = EpochLib.WEEK;
        _setUp();
    }

    /// @dev Implement this if you want a custom configured deployment
    function _setUp() internal virtual { }

    function _skipAndStartNewEpoch() internal {
        uint256 _currentEpochRemaining = EpochLib.epochNext(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining);
    }

    function _skipRemainingEpochFraction(uint256 fraction_) internal {
        uint256 _currentEpochRemaining = EpochLib.epochNext(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining / fraction_);
    }
}
