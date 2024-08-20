// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { Deploy as MockTokenDeployer } from "script/test_mock/MockToken.s.sol";
import { Deploy as ChangeExecutorMockDeployer } from "script/test_mock/ChangeExecutorMock.s.sol";
import { Deploy as GaugeBeaconDeployer } from "script/gauge/GaugeBeacon.s.sol";
import { Deploy as GaugeFactoryDeployer } from "script/gauge/GaugeFactory.s.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { Deploy as RewardDistributorDeployer } from "script/RewardDistributor.s.sol";
import { ChangeExecutorMock } from "./mock/ChangeExecutorMock.sol";
import { ERC20Mock } from "./mock/ERC20Mock.sol";
import { GaugeBeacon } from "src/gauge/GaugeBeacon.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";
import { Gauge } from "src/gauge/Gauge.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { EpochLib } from "src/libraries/EpochLib.sol";

contract BaseTest is Test {
    ChangeExecutorMock public changeExecutorMockImpl;
    ChangeExecutorMock public changeExecutorMock;
    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    GaugeBeacon public gaugeBeacon;
    GaugeFactory public gaugeFactory;
    Gauge public gauge;
    Gauge public gauge2;
    Gauge[] public gaugesArray;
    uint256[] public allocationsArray = [0, 0];
    SponsorsManager public sponsorsManagerImpl;
    SponsorsManager public sponsorsManager;
    RewardDistributor public rewardDistributorImpl;
    RewardDistributor public rewardDistributor;

    /* solhint-disable private-vars-leading-underscore */
    address internal governor = makeAddr("governor"); // TODO: use a GovernorMock contract
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal builder = makeAddr("builder");
    address internal builder2 = makeAddr("builder2");
    address internal builder2Receiver = makeAddr("builder2Receiver");
    address internal kycApprover = makeAddr("kycApprover");
    address internal foundation = makeAddr("foundation");
    /* solhint-enable private-vars-leading-underscore */

    function setUp() public {
        (changeExecutorMock, changeExecutorMockImpl) = new ChangeExecutorMockDeployer().run(governor);
        MockTokenDeployer _mockTokenDeployer = new MockTokenDeployer();
        stakingToken = _mockTokenDeployer.run(0);
        rewardToken = _mockTokenDeployer.run(1);
        gaugeBeacon = new GaugeBeaconDeployer().run(address(changeExecutorMock));
        gaugeFactory = new GaugeFactoryDeployer().run(address(gaugeBeacon), address(rewardToken));
        (sponsorsManager, sponsorsManagerImpl) = new SponsorsManagerDeployer().run(
            address(changeExecutorMock), kycApprover, address(rewardToken), address(stakingToken), address(gaugeFactory)
        );
        (rewardDistributor, rewardDistributorImpl) =
            new RewardDistributorDeployer().run(address(changeExecutorMock), foundation, address(sponsorsManager));

        // allow to execute all the functions protected by governance
        changeExecutorMock.setIsAuthorized(true);

        gauge = _whitelistBuilder(builder, builder, 0.5 ether);
        gauge2 = _whitelistBuilder(builder2, builder2Receiver, 0.5 ether);
        gaugesArray = [gauge, gauge2];

        // mint some stakingTokens to alice and bob
        stakingToken.mint(alice, 100_000 ether);
        stakingToken.mint(bob, 100_000 ether);

        _setUp();
    }

    /// @dev Implement this if you want a custom configured deployment
    function _setUp() internal virtual { }

    function _skipAndStartNewEpoch() internal {
        uint256 _currentEpochRemaining = EpochLib._epochNext(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining);
    }

    function _skipRemainingEpochFraction(uint256 fraction_) internal {
        uint256 _currentEpochRemaining = EpochLib._epochNext(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining / fraction_);
    }

    function _skipToStartDistributionWindow() internal {
        _skipAndStartNewEpoch();
    }

    function _skipToEndDistributionWindow() internal {
        _skipAndStartNewEpoch();
        uint256 _currentEpochRemaining = EpochLib._endDistributionWindow(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining);
    }

    function _whitelistBuilder(
        address builder_,
        address rewardReceiver_,
        uint256 kickbackPct_
    )
        internal
        returns (Gauge)
    {
        vm.prank(kycApprover);
        sponsorsManager.activateBuilder(builder_, rewardReceiver_, kickbackPct_);
        vm.prank(governor);
        return sponsorsManager.whitelistBuilder(builder_);
    }
}
