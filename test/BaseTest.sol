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
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract BaseTest is Test {
    ChangeExecutorMock public changeExecutorMockImpl;
    ChangeExecutorMock public changeExecutorMock;
    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    GaugeBeacon public gaugeBeacon;
    GaugeFactory public gaugeFactory;
    address[] public builders;
    Gauge public gauge;
    Gauge public gauge2;
    Gauge[] public gaugesArray;
    uint256[] public allocationsArray = [0, 0];
    SponsorsManager public sponsorsManagerImpl;
    SponsorsManager public sponsorsManager;
    RewardDistributor public rewardDistributorImpl;
    RewardDistributor public rewardDistributor;

    uint32 public epochDuration = 1 weeks;
    uint24 public epochStartOffset = 0 days;
    uint128 public kickbackCooldown = 2 weeks;

    /* solhint-disable private-vars-leading-underscore */
    address internal governor = makeAddr("governor"); // TODO: use a GovernorMock contract
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal builder = makeAddr("builder");
    address internal builder2 = makeAddr("builder2");
    address internal incentivizer = makeAddr("incentivizer");
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

        (rewardDistributor, rewardDistributorImpl) =
            new RewardDistributorDeployer().run(address(changeExecutorMock), foundation);

        (sponsorsManager, sponsorsManagerImpl) = new SponsorsManagerDeployer().run(
            address(changeExecutorMock),
            kycApprover,
            address(rewardToken),
            address(stakingToken),
            address(gaugeFactory),
            address(rewardDistributor),
            epochDuration,
            epochStartOffset,
            kickbackCooldown
        );

        rewardDistributor.initializeBIMAddresses(address(sponsorsManager));

        // allow to execute all the functions protected by governance
        changeExecutorMock.setIsAuthorized(true);

        builders.push(builder);
        builders.push(builder2);
        gauge = _whitelistBuilder(builder, builder, 0.5 ether);
        gauge2 = _whitelistBuilder(builder2, builder2Receiver, 0.5 ether);
        gaugesArray = [gauge, gauge2];

        // mint some stakingTokens to alice and bob
        stakingToken.mint(alice, 100_000 ether);
        stakingToken.mint(bob, 100_000 ether);

        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(sponsorsManager), 100_000 ether);

        _setUp();
    }

    /// @dev Implement this if you want a custom configured deployment
    function _setUp() internal virtual { }

    function _skipAndStartNewEpoch() internal {
        uint256 _currentEpochRemaining = sponsorsManager.epochNext(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining);
    }

    function _skipRemainingEpochFraction(uint256 fraction_) internal {
        uint256 _currentEpochRemaining = sponsorsManager.epochNext(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining / fraction_);
    }

    function _skipToStartDistributionWindow() internal {
        _skipAndStartNewEpoch();
    }

    function _skipToEndDistributionWindow() internal {
        _skipAndStartNewEpoch();
        uint256 _currentEpochRemaining = sponsorsManager.endDistributionWindow(block.timestamp) - block.timestamp;
        skip(_currentEpochRemaining);
    }

    function _whitelistBuilder(
        address builder_,
        address rewardReceiver_,
        uint64 kickbackPct_
    )
        internal
        returns (Gauge newGauge_)
    {
        vm.startPrank(kycApprover);
        sponsorsManager.activateBuilder(builder_, rewardReceiver_, kickbackPct_);
        vm.startPrank(governor);
        newGauge_ = sponsorsManager.whitelistBuilder(builder_);
        vm.stopPrank();
    }

    function _createGauge(uint64 kickback_) internal {
        address _newBuilder = makeAddr(string(abi.encode(gaugesArray.length)));
        builders.push(_newBuilder);
        Gauge _newGauge = _whitelistBuilder(_newBuilder, _newBuilder, kickback_);
        gaugesArray.push(_newGauge);
    }

    function _createGauges(uint256 amount_, uint64 kickback_) internal {
        for (uint256 i = 0; i < amount_; i++) {
            _createGauge(kickback_);
        }
    }

    function _initialDistribution() internal {
        // GIVEN alice allocates to builder and builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        // AND bob allocates to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND half epoch pass
        _skipRemainingEpochFraction(2);
    }

    function _distribute(uint256 amountERC20_, uint256 amountCoinbase_) internal {
        _skipToStartDistributionWindow();
        rewardToken.mint(address(rewardDistributor), amountERC20_);
        vm.deal(address(rewardDistributor), amountCoinbase_ + address(rewardDistributor).balance);
        vm.startPrank(foundation);
        rewardDistributor.sendRewardsAndStartDistribution(amountERC20_, amountCoinbase_);
        while (sponsorsManager.onDistributionPeriod()) {
            sponsorsManager.distribute();
        }
        vm.stopPrank();
    }

    function _buildersClaim() internal {
        for (uint256 i = 0; i < gaugesArray.length; i++) {
            address _builder = sponsorsManager.gaugeToBuilder(gaugesArray[i]);
            vm.startPrank(_builder);
            gaugesArray[i].claimBuilderReward();
        }
        vm.stopPrank();
    }

    /**
     * @notice returns reward token balance and clear it.
     *  Used to simplify maths and asserts considering only tokens received
     */
    function _clearERC20Balance(address address_) internal returns (uint256 balance_) {
        balance_ = rewardToken.balanceOf(address_);
        vm.startPrank(address_);
        rewardToken.transfer(address(this), balance_);
        vm.stopPrank();
    }

    /**
     * @notice returns reward token balance and clear it.
     *  Used to simplify maths and asserts considering only tokens received
     */
    function _clearCoinbaseBalance(address address_) internal returns (uint256 balance_) {
        balance_ = address_.balance;
        vm.startPrank(address_);
        Address.sendValue(payable(address(this)), balance_);
        vm.stopPrank();
    }

    receive() external payable { }
}
