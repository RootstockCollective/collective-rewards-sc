// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { Deploy as MockTokenDeployer } from "script/test_mock/MockToken.s.sol";
import { Deploy as ChangeExecutorMockDeployer } from "script/test_mock/ChangeExecutorMock.s.sol";
import { Deploy as BuilderGaugeFactoryDeployer } from "script/builder/BuilderGaugeFactory.s.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { Deploy as BuilderRegistryDeployer } from "script/BuilderRegistry.s.sol";
import { Deploy as RewardDistributorDeployer } from "script/RewardDistributor.s.sol";
import { ChangeExecutorMock } from "./mock/ChangeExecutorMock.sol";
import { ERC20Mock } from "./mock/ERC20Mock.sol";
import { BuilderGaugeFactory } from "src/builder/BuilderGaugeFactory.sol";
import { BuilderGauge } from "src/builder/BuilderGauge.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { BuilderRegistry } from "src/BuilderRegistry.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { EpochLib } from "src/libraries/EpochLib.sol";

contract BaseTest is Test {
    ChangeExecutorMock public changeExecutorMockImpl;
    ChangeExecutorMock public changeExecutorMock;
    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    BuilderGaugeFactory public builderGaugeFactory;
    BuilderGauge public builderGauge;
    BuilderGauge public builderGauge2;
    BuilderGauge[] public builderGaugesArray;
    uint256[] public allocationsArray = [0, 0];
    SponsorsManager public sponsorsManagerImpl;
    SponsorsManager public sponsorsManager;
    BuilderRegistry public builderRegistryImpl;
    BuilderRegistry public builderRegistry;
    RewardDistributor public rewardDistributorImpl;
    RewardDistributor public rewardDistributor;

    /* solhint-disable private-vars-leading-underscore */
    address internal governor = makeAddr("governor"); // TODO: use a GovernorMock contract
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal builder = makeAddr("builder");
    address internal builder2 = makeAddr("builder2");
    address internal kycApprover = makeAddr("kycApprover");
    address internal foundation = makeAddr("foundation");
    /* solhint-enable private-vars-leading-underscore */

    function setUp() public {
        (changeExecutorMock, changeExecutorMockImpl) = new ChangeExecutorMockDeployer().run(governor);
        MockTokenDeployer _mockTokenDeployer = new MockTokenDeployer();
        stakingToken = _mockTokenDeployer.run(0);
        rewardToken = _mockTokenDeployer.run(1);
        (builderRegistry, builderRegistryImpl) =
            new BuilderRegistryDeployer().run(address(changeExecutorMock), kycApprover);
        builderGaugeFactory = new BuilderGaugeFactoryDeployer().run();
        (sponsorsManager, sponsorsManagerImpl) = new SponsorsManagerDeployer().run(
            address(changeExecutorMock),
            address(rewardToken),
            address(stakingToken),
            address(builderGaugeFactory),
            address(builderRegistry)
        );
        (rewardDistributor, rewardDistributorImpl) =
            new RewardDistributorDeployer().run(address(changeExecutorMock), foundation, address(sponsorsManager));

        // allow to execute all the functions protected by governance
        changeExecutorMock.setIsAuthorized(true);

        builderGauge = sponsorsManager.createBuilderGauge(builder);
        builderGauge2 = sponsorsManager.createBuilderGauge(builder2);
        builderGaugesArray = [builderGauge, builderGauge2];

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
}
