// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { Deploy as MockTokenDeployer } from "script/test_mock/MockToken.s.sol";
import { Deploy as MockStakingTokenDeployer } from "script/test_mock/MockStakingToken.s.sol";
import { Deploy as GaugeBeaconRootstockCollectiveDeployer } from "script/gauge/GaugeBeaconRootstockCollective.s.sol";
import { Deploy as GaugeFactoryRootstockCollectiveDeployer } from "script/gauge/GaugeFactoryRootstockCollective.s.sol";
import { Deploy as BackersManagerRootstockCollectiveDeployer } from "script/BackersManagerRootstockCollective.s.sol";
import { Deploy as BuilderRegistryRootstockCollectiveDeployer } from "script/BuilderRegistryRootstockCollective.s.sol";
import { Deploy as RewardDistributorRootstockCollectiveDeployer } from
    "script/RewardDistributorRootstockCollective.s.sol";
import { ERC20Mock } from "./mock/ERC20Mock.sol";
import { StakingTokenMock } from "./mock/StakingTokenMock.sol";
import { GaugeBeaconRootstockCollective } from "src/gauge/GaugeBeaconRootstockCollective.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { BuilderRegistryRootstockCollective } from "src/backersManager/BuilderRegistryRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Deploy as GovernanceManagerRootstockCollectiveDeployer } from
    "script/governance/GovernanceManagerRootstockCollective.s.sol";
import { GovernanceManagerRootstockCollective } from "src/governance/GovernanceManagerRootstockCollective.sol";

contract BaseTest is Test {
    StakingTokenMock public stakingToken;
    ERC20Mock public rewardToken;

    GovernanceManagerRootstockCollective public governanceManager;
    GaugeBeaconRootstockCollective public gaugeBeacon;
    GaugeFactoryRootstockCollective public gaugeFactory;
    address[] public builders;
    GaugeRootstockCollective public gauge;
    GaugeRootstockCollective public gauge2;
    GaugeRootstockCollective[] public gaugesArray;
    uint256[] public allocationsArray = [0, 0];
    BackersManagerRootstockCollective public backersManagerImpl;
    BackersManagerRootstockCollective public backersManager;
    RewardDistributorRootstockCollective public rewardDistributorImpl;
    RewardDistributorRootstockCollective public rewardDistributor;
    BuilderRegistryRootstockCollective public builderRegistryImpl;
    BuilderRegistryRootstockCollective public builderRegistry;

    uint32 public cycleDuration = 1 weeks;
    uint24 public cycleStartOffset = 0 days;
    uint32 public distributionDuration = 1 hours;
    uint128 public rewardPercentageCooldown = 2 weeks;

    /* solhint-disable private-vars-leading-underscore */
    address internal governor = makeAddr("governor"); // TODO: use a GovernorMock contract
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal builder = makeAddr("builder");
    address internal builder2 = makeAddr("builder2");
    address internal incentivizer = makeAddr("incentivizer");
    address internal builder2Receiver = makeAddr("builder2Receiver");
    address public kycApprover = makeAddr("kycApprover");
    address public foundation = makeAddr("foundation");
    address public upgrader = makeAddr("upgrader");

    /* solhint-enable private-vars-leading-underscore */

    function setUp() public {
        (governanceManager,) =
            new GovernanceManagerRootstockCollectiveDeployer().run(governor, foundation, kycApprover, upgrader);

        MockTokenDeployer _mockTokenDeployer = new MockTokenDeployer();
        MockStakingTokenDeployer _mockStakingTokenDeployer = new MockStakingTokenDeployer();
        stakingToken = _mockStakingTokenDeployer.run(0);
        rewardToken = _mockTokenDeployer.run(1);
        gaugeBeacon = new GaugeBeaconRootstockCollectiveDeployer().run(address(governanceManager));
        gaugeFactory = new GaugeFactoryRootstockCollectiveDeployer().run(address(gaugeBeacon), address(rewardToken));

        (rewardDistributor, rewardDistributorImpl) =
            new RewardDistributorRootstockCollectiveDeployer().run(address(governanceManager));

        (builderRegistry, builderRegistryImpl) = new BuilderRegistryRootstockCollectiveDeployer().run(
            address(governanceManager), address(gaugeFactory), address(rewardDistributor), rewardPercentageCooldown
        );

        (backersManager, backersManagerImpl) = new BackersManagerRootstockCollectiveDeployer().run(
            address(governanceManager),
            address(builderRegistry),
            address(rewardToken),
            address(stakingToken),
            cycleDuration,
            cycleStartOffset,
            distributionDuration
        );

        builderRegistry.setBackersManager(backersManager);

        rewardDistributor.initializeCollectiveRewardsAddresses(address(backersManager));

        // allow to execute all the functions protected by governance

        gauge = _whitelistBuilder(builder, builder, 0.5 ether);
        gauge2 = _whitelistBuilder(builder2, builder2Receiver, 0.5 ether);

        // mint some stakingTokens to alice and bob
        stakingToken.mint(alice, 100_000 ether);
        stakingToken.mint(bob, 100_000 ether);

        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(backersManager), 100_000 ether);

        _setUp();
    }

    /// @dev Implement this if you want a custom configured deployment
    function _setUp() internal virtual { }

    function _skipAndStartNewCycle() internal {
        uint256 _currentCycleRemaining = backersManager.cycleNext(block.timestamp) - block.timestamp;
        skip(_currentCycleRemaining);
    }

    function _skipRemainingCycleFraction(uint256 fraction_) internal {
        uint256 _currentCycleRemaining = backersManager.cycleNext(block.timestamp) - block.timestamp;
        skip(_currentCycleRemaining / fraction_);
    }

    function _skipToStartDistributionWindow() internal {
        _skipAndStartNewCycle();
    }

    function _skipToEndDistributionWindow() internal {
        _skipAndStartNewCycle();
        uint256 _currentCycleRemaining = backersManager.endDistributionWindow(block.timestamp) - block.timestamp;
        skip(_currentCycleRemaining);
    }

    function _whitelistBuilder(
        address builder_,
        address rewardReceiver_,
        uint64 rewardPercentage_
    )
        internal
        returns (GaugeRootstockCollective newGauge_)
    {
        vm.prank(kycApprover);
        builderRegistry.activateBuilder(builder_, rewardReceiver_, rewardPercentage_);
        builders.push(builder_);
        vm.prank(governor);
        newGauge_ = builderRegistry.communityApproveBuilder(builder_);
        gaugesArray.push(newGauge_);
    }

    function _createGauge(uint64 rewardPercentage_) internal {
        address _newBuilder = makeAddr(string(abi.encode(gaugesArray.length)));
        _whitelistBuilder(_newBuilder, _newBuilder, rewardPercentage_);
    }

    function _createGauges(uint256 amount_, uint64 rewardPercentage_) internal {
        for (uint256 i = 0; i < amount_; i++) {
            _createGauge(rewardPercentage_);
        }
    }

    function _initialDistribution() internal {
        // GIVEN alice allocates to builder and builder2
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        vm.prank(alice);
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        // AND bob allocates to builder2
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        vm.prank(bob);
        backersManager.allocateBatch(gaugesArray, allocationsArray);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND half cycle pass
        _skipRemainingCycleFraction(2);
    }

    /**
     * @notice skips to new cycle and executes a distribution.
     */
    function _distribute(uint256 amountERC20_, uint256 amountCoinbase_) internal {
        _skipToStartDistributionWindow();
        rewardToken.mint(address(rewardDistributor), amountERC20_);
        vm.deal(address(rewardDistributor), amountCoinbase_ + address(rewardDistributor).balance);
        vm.startPrank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(amountERC20_, amountCoinbase_);
        while (backersManager.onDistributionPeriod()) {
            backersManager.distribute();
        }
        vm.stopPrank();
    }

    /// @dev if any amount is zero, it will not be skipped
    function _incentivize(GaugeRootstockCollective gauge_, uint256 amountERC20_, uint256 amountCoinbase_) internal {
        if (amountCoinbase_ > 0) {
            vm.deal(incentivizer, amountCoinbase_);
            gauge_.incentivizeWithCoinbase{ value: amountCoinbase_ }();
        }
        if (amountERC20_ > 0) {
            rewardToken.mint(address(incentivizer), amountERC20_);
            vm.prank(address(incentivizer));
            rewardToken.approve(address(gauge_), amountERC20_);
            vm.prank(address(incentivizer));
            gauge_.incentivizeWithRewardToken(amountERC20_);
        }
    }

    function _buildersClaim() internal {
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            address _builder = builderRegistry.gaugeToBuilder(gaugesArray[i]);
            vm.prank(_builder);
            gaugesArray[i].claimBuilderReward();
        }
    }

    /**
     * @notice returns reward token balance and clear it.
     *  Used to simplify maths and asserts considering only tokens received
     */
    function _clearERC20Balance(address address_) internal returns (uint256 balance_) {
        balance_ = rewardToken.balanceOf(address_);
        vm.prank(address_);
        rewardToken.transfer(address(this), balance_);
    }

    /**
     * @notice returns reward token balance and clear it.
     *  Used to simplify maths and asserts considering only tokens received
     */
    function _clearCoinbaseBalance(address address_) internal returns (uint256 balance_) {
        balance_ = address_.balance;
        vm.prank(address_);
        Address.sendValue(payable(address(this)), balance_);
    }

    function gaugesArrayLength() public view returns (uint256) {
        return gaugesArray.length;
    }

    function addGauge(GaugeRootstockCollective gauge_) public {
        gaugesArray.push(gauge_);
    }

    function buildersArrayLength() public view returns (uint256) {
        return builders.length;
    }

    function addBuilder(address builder_) public {
        builders.push(builder_);
    }

    receive() external payable { }
}
