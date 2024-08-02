// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";

import { Deploy as MockTokenDeployer } from "script/test_mock/MockToken.s.sol";
import { Deploy as ChangeExecutorMockDeployer } from "script/test_mock/ChangeExecutorMock.s.sol";
import { Deploy as GaugeFactoryDeployer } from "script/gauge/GaugeFactory.s.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { Deploy as BuilderRegistryDeployer } from "script/BuilderRegistry.s.sol";
import { Deploy as RewardDistributorDeployer } from "script/RewardDistributor.s.sol";
import { ChangeExecutorMock } from "./mock/ChangeExecutorMock.sol";
import { ERC20Mock } from "./mock/ERC20Mock.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";
import { Gauge } from "src/gauge/Gauge.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { EpochLib } from "src/libraries/EpochLib.sol";

contract BaseTest is Test {
    ChangeExecutorMock public changeExecutorMock;
    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    GaugeFactory public gaugeFactory;
    Gauge public gauge;
    Gauge public gauge2;
    Gauge[] public gaugesArray;
    uint256[] public allocationsArray = [0, 0];
    SponsorsManager public sponsorsManager;
    BuilderRegistry public builderRegistry;
    RewardDistributor public rewardDistributor;
    uint256 public epochDuration;

    address internal governor = makeAddr("governor"); // TODO: use a GovernorMock contract
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal builder = makeAddr("builder");
    address internal builder2 = makeAddr("builder2");
    address internal foundation = makeAddr("foundation");

    function setUp() public {
        changeExecutorMock = new ChangeExecutorMockDeployer().run(governor);
        MockTokenDeployer mockTokenDeployer = new MockTokenDeployer();
        stakingToken = mockTokenDeployer.run(0);
        rewardToken = mockTokenDeployer.run(1);
        builderRegistry = new BuilderRegistryDeployer().run(governor, address(changeExecutorMock), foundation);
        gaugeFactory = new GaugeFactoryDeployer().run();
        sponsorsManager = new SponsorsManagerDeployer().run(
            governor, address(changeExecutorMock), address(rewardToken), address(stakingToken), address(gaugeFactory)
        );
        rewardDistributor =
            new RewardDistributorDeployer().run(foundation, address(rewardToken), address(sponsorsManager));
        gauge = sponsorsManager.createGauge(builder);
        gauge2 = sponsorsManager.createGauge(builder2);
        gaugesArray = [gauge, gauge2];
        epochDuration = EpochLib.WEEK;

        // mint some stakingTokens to alice and bob
        stakingToken.mint(alice, 100_000 ether);
        stakingToken.mint(bob, 100_000 ether);

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

    function _skipToStartDistributionWindow() internal {
        _skipAndStartNewEpoch();
    }

    function _skipToEndDistributionWindow() internal {
        _skipAndStartNewEpoch();
        uint256 _currentEpochRemaining = EpochLib.endDistributionWindow(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining);
    }
}
