// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { Deploy as MockTokenDeployer } from "script/test_mock/MockToken.s.sol";
import { Deploy as GaugeBeaconDeployer } from "script/gauge/GaugeBeacon.s.sol";
import { Deploy as GaugeFactoryDeployer } from "script/gauge/GaugeFactory.s.sol";
import { Deploy as SponsorsManagerDeployer } from "script/SponsorsManager.s.sol";
import { Deploy as RewardDistributorDeployer } from "script/RewardDistributor.s.sol";
import { Deploy as ChangeExecutorDeployer } from "script/governance/ChangeExecutor.s.sol";
import { ERC20Mock } from "./mock/ERC20Mock.sol";
import { GaugeBeacon } from "src/gauge/GaugeBeacon.sol";
import { GaugeFactory } from "src/gauge/GaugeFactory.sol";
import { ChangeExecutor } from "src/governance/ChangeExecutor.sol";
import { Gauge } from "src/gauge/Gauge.sol";
import { SponsorsManager } from "src/SponsorsManager.sol";
import { RewardDistributor } from "src/RewardDistributor.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Deploy as GovernedDeployer } from "script/governance/Governed.s.sol";
import { IGoverned } from "src/interfaces/IGoverned.sol";

contract BaseTest is Test {
    ChangeExecutor public changeExecutorImpl;
    ChangeExecutor public changeExecutor;
    ERC20Mock public stakingToken;
    ERC20Mock public rewardToken;

    IGoverned public governed;
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
    address public kycApprover = makeAddr("kycApprover");
    address public foundation = makeAddr("foundation");
    /* solhint-enable private-vars-leading-underscore */

    function setUp() public {
        (governed,) = new GovernedDeployer().run(address(this), foundation, kycApprover);
        (changeExecutor, changeExecutorImpl) = new ChangeExecutorDeployer().run(address(governed));
        governed.updateChangerAdmin(address(changeExecutor));
        governed.updateGovernor(governor);

        MockTokenDeployer _mockTokenDeployer = new MockTokenDeployer();
        stakingToken = _mockTokenDeployer.run(0);
        rewardToken = _mockTokenDeployer.run(1);
        gaugeBeacon = new GaugeBeaconDeployer().run(address(governed));
        gaugeFactory = new GaugeFactoryDeployer().run(address(gaugeBeacon), address(rewardToken));

        (rewardDistributor, rewardDistributorImpl) = new RewardDistributorDeployer().run(address(governed));

        (sponsorsManager, sponsorsManagerImpl) = new SponsorsManagerDeployer().run(
            address(governed),
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

        gauge = _whitelistBuilder(builder, builder, 0.5 ether);
        gauge2 = _whitelistBuilder(builder2, builder2Receiver, 0.5 ether);

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
        vm.prank(kycApprover);
        sponsorsManager.activateBuilder(builder_, rewardReceiver_, kickbackPct_);
        builders.push(builder_);
        vm.prank(governor);
        newGauge_ = sponsorsManager.whitelistBuilder(builder_);
        gaugesArray.push(newGauge_);
    }

    function _createGauge(uint64 kickback_) internal {
        address _newBuilder = makeAddr(string(abi.encode(gaugesArray.length)));
        _whitelistBuilder(_newBuilder, _newBuilder, kickback_);
    }

    function _createGauges(uint256 amount_, uint64 kickback_) internal {
        for (uint256 i = 0; i < amount_; i++) {
            _createGauge(kickback_);
        }
    }

    function _initialDistribution() internal {
        // GIVEN alice allocates to builder and builder2
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        vm.prank(alice);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        // AND bob allocates to builder2
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        vm.prank(bob);
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);

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

    function addGauge(Gauge gauge_) public {
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
