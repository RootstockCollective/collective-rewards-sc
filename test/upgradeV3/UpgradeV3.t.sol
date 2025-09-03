// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { IGovernanceManagerRootstockCollective } from "src/interfaces/IGovernanceManagerRootstockCollective.sol";
import { UpgradeV3 } from "src/upgrades/UpgradeV3.sol";
import { BuilderRegistryRootstockCollective } from "src/builderRegistry/BuilderRegistryRootstockCollective.sol";
import { BackersManagerRootstockCollective } from "src/backersManager/BackersManagerRootstockCollective.sol";
import { UpgradeV3Deployer } from "script/upgrades/UpgradeV3.s.sol";
import { GaugeFactoryRootstockCollective } from "src/gauge/GaugeFactoryRootstockCollective.sol";
import { RewardDistributorRootstockCollective } from "src/RewardDistributorRootstockCollective.sol";
import { GaugeBeaconRootstockCollective } from "src/gauge/GaugeBeaconRootstockCollective.sol";
import { IBackersManagerRootstockCollectiveV2 } from "src/interfaces/v2/IBackersManagerRootstockCollectiveV2.sol";
import { IRewardDistributorRootstockCollectiveV2 } from "src/interfaces/v2/IRewardDistributorRootstockCollectiveV2.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IBuilderRegistryRootstockCollectiveV2 } from "src/interfaces/v2/IBuilderRegistryRootstockCollectiveV2.sol";

contract UpgradeV3Test is Test {
    IBackersManagerRootstockCollectiveV2 public backersManagerV2;
    BackersManagerRootstockCollective public backersManagerV3;
    IBuilderRegistryRootstockCollectiveV2 public builderRegistryV2;
    BuilderRegistryRootstockCollective public builderRegistryV3;
    IGovernanceManagerRootstockCollective public governanceManager;
    IRewardDistributorRootstockCollectiveV2 public rewardDistributorV2;
    RewardDistributorRootstockCollective public rewardDistributorV3;
    GaugeBeaconRootstockCollective public gaugeBeacon;
    UpgradeV3 public upgradeV3;
    address public upgrader;
    address public configurator;
    address public alice;
    address public usdrifToken;
    address public rifTokenAddress;
    address public configuratorAddress;

    function setUp() public {
        // Initialize environment variables as state variables
        usdrifToken = vm.envAddress("USDRIF_TOKEN_ADDRESS");
        rifTokenAddress = vm.envAddress("RIF_TOKEN_ADDRESS");
        configuratorAddress = vm.envAddress("CONFIGURATOR_ADDRESS");

        backersManagerV2 = IBackersManagerRootstockCollectiveV2(vm.envAddress("BackersManagerRootstockCollectiveProxy"));
        builderRegistryV2 =
            IBuilderRegistryRootstockCollectiveV2(vm.envAddress("BuilderRegistryRootstockCollectiveProxy"));
        governanceManager =
            IGovernanceManagerRootstockCollective(vm.envAddress("GovernanceManagerRootstockCollectiveProxy"));
        rewardDistributorV2 =
            IRewardDistributorRootstockCollectiveV2(payable(vm.envAddress("RewardDistributorRootstockCollectiveProxy")));
        GaugeFactoryRootstockCollective _gaugeFactory =
            GaugeFactoryRootstockCollective(vm.envAddress("GaugeFactoryRootstockCollective"));
        gaugeBeacon = GaugeBeaconRootstockCollective(_gaugeFactory.beacon());

        upgrader = governanceManager.upgrader();
        alice = makeAddr("alice");
        configurator = makeAddr("configurator");

        // Setup UpgradeV3
        UpgradeV3Deployer _upgradeV3Deployer = new UpgradeV3Deployer();
        upgradeV3 = _upgradeV3Deployer.run(
            IBackersManagerRootstockCollectiveV2(backersManagerV2),
            rewardDistributorV2,
            configurator,
            usdrifToken,
            address(gaugeBeacon),
            false
        );
    }

    /**
     * SCENARIO: Upgrade v3 is setup correctly
     */
    function test_fork_upgradeV3Setup() public view {
        // GIVEN UpgradeV3 is setup
        // THEN UpgradeV3 should have the expected initialization state
        vm.assertEq(address(upgradeV3.backersManagerProxy()), address(backersManagerV2));
        vm.assertNotEq(address(upgradeV3.backersManagerImplV3()), address(0));

        vm.assertEq(address(upgradeV3.builderRegistryProxy()), address(builderRegistryV2));
        vm.assertNotEq(address(upgradeV3.builderRegistryImplV3()), address(0));

        vm.assertEq(address(upgradeV3.governanceManagerProxy()), address(governanceManager));
        vm.assertNotEq(address(upgradeV3.governanceManagerImplV3()), address(0));

        vm.assertEq(address(upgradeV3.gaugeBeacon()), address(gaugeBeacon));
        vm.assertNotEq(address(upgradeV3.gaugeImplV3()), address(0));

        vm.assertEq(address(upgradeV3.rewardDistributorProxy()), address(rewardDistributorV2));
        vm.assertNotEq(address(upgradeV3.rewardDistributorImplV3()), address(0));

        vm.assertNotEq(address(upgradeV3.gaugeFactoryV3()), address(0));

        vm.assertEq(upgradeV3.upgrader(), upgrader);

        vm.assertNotEq(address(upgradeV3.configurator()), address(0));
        vm.assertGt(upgradeV3.MAX_DISTRIBUTIONS_PER_BATCH(), 0);
    }

    /**
     * SCENARIO: original upgrader can reclaim UpgradeV3 upgrader role
     */
    function test_fork_upgradeV3ResetUpgrader() public {
        // GIVEN UpgradeV3 is setup
        // AND the upgrader is set to UpgradeV3 address
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(upgradeV3));
        vm.assertEq(address(governanceManager.upgrader()), address(upgradeV3));

        // WHEN the upgrader is reset
        vm.prank(upgrader);
        upgradeV3.resetUpgrader();
        // THEN the upgrader should match the original upgrader
        vm.assertEq(address(governanceManager.upgrader()), upgrader);
    }

    /**
     * SCENARIO: only original upgrader can reclaim UpgradeV3 upgrader role
     */
    function test_fork_upgradeV3ResetUpgrader_unauthorized() public {
        // GIVEN UpgradeV3 is setup
        // AND the upgrader is set to UpgradeV3 address
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(upgradeV3));

        // WHEN the upgrader is reset by an unauthorized address
        // THEN the upgrader should revert with NotUpgrader error
        vm.prank(address(this));
        vm.expectRevert(UpgradeV3.NotUpgrader.selector);
        upgradeV3.resetUpgrader();
    }

    /**
     * SCENARIO: backersManagerV2 is upgraded to v3
     */
    function test_fork_upgradeBackersManager() public {
        // GIVEN v2 values before upgrade
        uint256 _v2RewardsERC20 = backersManagerV2.rewardsERC20();
        uint256 _v2RewardsCoinbase = backersManagerV2.rewardsCoinbase();
        address _v2RewardToken = backersManagerV2.rewardToken();

        // WHEN the upgrade is performed
        _upgradeV3();

        // THEN backersManagerV2 should have the new implementation
        vm.assertEq(_getImplementation(address(backersManagerV2)), address(upgradeV3.backersManagerImplV3()));

        // AND v3 interface should work with preserved values
        // rewardToken should be renamed to rifToken
        vm.assertEq(address(backersManagerV3.rifToken()), rifTokenAddress);
        vm.assertEq(address(backersManagerV3.rifToken()), _v2RewardToken);
        // rewardsERC20 should be preserved as rewardsRif
        vm.assertEq(backersManagerV3.rewardsRif(), _v2RewardsERC20);
        // rewardsCoinbase should be preserved as rewardsNative
        vm.assertEq(backersManagerV3.rewardsNative(), _v2RewardsCoinbase);

        // AND new v3 variables should be properly initialized
        // maxDistributionsPerBatch should be set to the expected value (new in v3)
        vm.assertEq(backersManagerV3.maxDistributionsPerBatch(), upgradeV3.MAX_DISTRIBUTIONS_PER_BATCH());
        vm.assertEq(backersManagerV3.maxDistributionsPerBatch(), 20);
        // usdrifToken should be set (new in v3)
        vm.assertEq(address(backersManagerV3.usdrifToken()), usdrifToken);
        // rewardsUsdrif should be initialized to 0 (new variable in v3)
        vm.assertEq(backersManagerV3.rewardsUsdrif(), 0);

        // AND v2 functions should no longer be accessible
        vm.expectRevert();
        IBackersManagerRootstockCollectiveV2(address(backersManagerV3)).rewardToken();
    }

    /**
     * SCENARIO: BuilderRegistry is upgraded to v3
     */
    function test_fork_upgradeBuilderRegistry() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN BuilderRegistry should have the new implementation
        vm.assertEq(_getImplementation(address(builderRegistryV3)), address(upgradeV3.builderRegistryImplV3()));

        // AND new v3 features should be properly initialized
        // should have the new GaugeFactory set
        vm.assertEq(address(builderRegistryV3.gaugeFactory()), address(upgradeV3.gaugeFactoryV3()));
        // rewardReceiver for new addresses should return 0 (default behavior)
        vm.assertEq(builderRegistryV3.rewardReceiver(alice), address(0));
    }

    /**
     * SCENARIO: Builder reward receiver mappings are preserved during upgrade for all builders
     */
    function test_fork_builderRewardReceiverPreservation() public {
        // GIVEN we collect all builders and their v2 reward receiver mappings before upgrade
        uint256 _gaugesLength = builderRegistryV2.getGaugesLength();
        require(_gaugesLength > 0, "No builders in the registry");

        // Collect all builders and their v2 reward receiver data
        address[] memory _builders = new address[](_gaugesLength);
        address[] memory _v2RewardReceivers = new address[](_gaugesLength);
        address[] memory _v2RewardReceiverReplacements = new address[](_gaugesLength);

        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _gauge = builderRegistryV2.getGaugeAt(i);
            address _builder = builderRegistryV2.gaugeToBuilder(_gauge);
            _builders[i] = _builder;

            // Capture v2 reward receiver mappings before upgrade
            _v2RewardReceivers[i] = builderRegistryV2.builderRewardReceiver(_builder);
            _v2RewardReceiverReplacements[i] = builderRegistryV2.builderRewardReceiverReplacement(_builder);
        }

        // WHEN the upgrade is performed
        _upgradeV3();

        // THEN verify all builders' reward receiver mappings are preserved
        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _builder = _builders[i];

            // Verify builderRewardReceiver -> rewardReceiver mapping
            vm.assertEq(builderRegistryV3.rewardReceiver(_builder), _v2RewardReceivers[i]);

            // Verify builderRewardReceiverReplacement -> rewardReceiverUpdate mapping
            vm.assertEq(builderRegistryV3.rewardReceiverUpdate(_builder), _v2RewardReceiverReplacements[i]);
        }
    }

    /**
     * SCENARIO: BuilderState fields are preserved during upgrade with proper renames for all builders
     */
    function test_fork_builderStatePreservation() public {
        // GIVEN we collect all builders and their v2 states before upgrade
        uint256 _gaugesLength = builderRegistryV2.getGaugesLength();
        require(_gaugesLength > 0, "No builders in the registry");

        // Collect all builders and their v2 renamed fields states
        address[] memory _builders = new address[](_gaugesLength);
        bool[] memory _v2Activated = new bool[](_gaugesLength);
        bool[] memory _v2Paused = new bool[](_gaugesLength);
        bool[] memory _v2Revoked = new bool[](_gaugesLength);

        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _gauge = builderRegistryV2.getGaugeAt(i);
            address _builder = builderRegistryV2.gaugeToBuilder(_gauge);
            _builders[i] = _builder;

            // Capture v2 BuilderState renamed fields values before upgrade
            (
                bool _activated,
                , // kycApproved (unchanged)
                , // communityApproved (unchanged)
                bool paused,
                bool revoked,
                , // reserved (unchanged)
                    // pausedReason (unchanged)
            ) = builderRegistryV2.builderState(_builder);

            _v2Activated[i] = _activated;
            _v2Paused[i] = paused;
            _v2Revoked[i] = revoked;
        }

        // WHEN the upgrade is performed
        _upgradeV3();

        // THEN verify all builders' states are preserved with renamed fields
        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _builder = _builders[i];

            // Get v3 BuilderState values
            (
                bool _v3Initialized,
                , // kycApproved (unchanged)
                , // communityApproved (unchanged)
                bool v3KycPaused,
                bool v3SelfPaused,
                , // reserved (unchanged)
                    // pausedReason (unchanged)
            ) = builderRegistryV3.builderState(_builder);

            // Verify renamed fields for this builder
            vm.assertEq(_v3Initialized, _v2Activated[i]);
            vm.assertEq(v3KycPaused, _v2Paused[i]);
            vm.assertEq(v3SelfPaused, _v2Revoked[i]);
        }
    }

    /**
     * SCENARIO: GovernanceManager is upgraded to v3
     */
    function test_fork_upgradeGovernanceManager() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN governanceManager should have the new implementation
        vm.assertEq(_getImplementation(address(governanceManager)), address(upgradeV3.governanceManagerImplV3()));
        // AND should follow v3 interface
        vm.assertNotEq(governanceManager.configurator(), configuratorAddress);
    }

    /**
     * SCENARIO: Gauge is upgraded to v3
     */
    function test_fork_upgradeGauge() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN gaugeBeacon should have the new implementation
        vm.assertEq(gaugeBeacon.implementation(), address(upgradeV3.gaugeImplV3()));
    }
    /**
     * SCENARIO: rewardDistributorV2 is upgraded to v3
     */

    function test_fork_upgradeRewardDistributor() public {
        // GIVEN v2 values before upgrade
        uint256 _v2DefaultRewardTokenAmount = rewardDistributorV2.defaultRewardTokenAmount();
        uint256 _v2DefaultRewardCoinbaseAmount = rewardDistributorV2.defaultRewardCoinbaseAmount();

        // WHEN the upgrade is performed
        _upgradeV3();

        // THEN rewardDistributor should have the new implementation
        vm.assertEq(_getImplementation(address(rewardDistributorV3)), address(upgradeV3.rewardDistributorImplV3()));
        // AND usdrifToken should be initialized with the same token as backersManagerV2
        vm.assertEq(address(rewardDistributorV3.usdrifToken()), usdrifToken);
        // AND rifToken should be initialized with the same token as backersManagerV3
        vm.assertEq(address(rewardDistributorV3.rifToken()), rifTokenAddress);
        // AND defaultRifAmount should preserve the v2 defaultRewardTokenAmount value
        vm.assertEq(rewardDistributorV3.defaultRifAmount(), _v2DefaultRewardTokenAmount);
        // AND defaultNativeAmount should preserve the v2 defaultRewardCoinbaseAmount value
        vm.assertEq(rewardDistributorV3.defaultNativeAmount(), _v2DefaultRewardCoinbaseAmount);
        // AND defaultUsdrifAmount should be initialized to 0 (new variable in v3)
        vm.assertEq(rewardDistributorV3.defaultUsdrifAmount(), 0);
        // AND lastFundedCycleStart should be initialized to 0 (new variable in v3)
        vm.assertEq(rewardDistributorV3.lastFundedCycleStart(), 0);
    }

    /**
     * SCENARIO: rewardToken was renamed to rifToken in V3
     */
    function test_fork_rewardTokenRenamedToRifToken() public {
        // GIVEN the rewardDistributor is still v2
        // THEN calling rifToken should revert
        vm.expectRevert();
        RewardDistributorRootstockCollective(payable(address(rewardDistributorV2))).rifToken();

        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN rifToken should be initialized with the same token as backersManagerV3
        vm.assertEq(address(rewardDistributorV3.rifToken()), rifTokenAddress);
        // AND calling rewardToken should revert
        vm.expectRevert();
        IRewardDistributorRootstockCollectiveV2(payable(address(rewardDistributorV3))).rewardToken();
    }

    /**
     * SCENARIO: usdrifToken does not exist in the rewardDistributor v2
     */
    function test_fork_usdrifTokenDoesNotExistBeforeUpgrade() public {
        // GIVEN the rewardDistributor is still v2
        // THEN it should revert when accessing usdrifToken
        vm.expectRevert();
        RewardDistributorRootstockCollective(payable(address(rewardDistributorV2))).usdrifToken();
    }

    /**
     * SCENARIO: rewardDistributor initializeV3 sets usdrifToken correctly during upgrade
     */
    function test_fork_rewardDistributorInitializeV3() public {
        // GIVEN the contracts are not yet upgraded
        // WHEN the upgrade is performed
        _upgradeV3();

        // THEN usdrifToken should be properly initialized
        vm.assertEq(address(rewardDistributorV3.usdrifToken()), usdrifToken);
    }

    /**
     * SCENARIO: rewardDistributor initializeV3 cannot be called twice
     */
    function test_fork_rewardDistributorInitializeV3_cannotCallTwice() public {
        // GIVEN the upgrade is performed and usdrifToken is initialized
        _upgradeV3();
        vm.assertEq(address(rewardDistributorV3.usdrifToken()), usdrifToken);

        // WHEN trying to call initializeV3 again
        // THEN it should revert with InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        rewardDistributorV3.initializeV3();
    }

    /**
     * SCENARIO: GaugeFactory is upgraded to v3 with correct parameters
     */
    function test_fork_gaugeFactoryV3Upgrade() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN GaugeFactory should be properly configured
        GaugeFactoryRootstockCollective _gaugeFactory = upgradeV3.gaugeFactoryV3();
        vm.assertEq(_gaugeFactory.beacon(), address(gaugeBeacon));
        vm.assertEq(_gaugeFactory.rifToken(), rifTokenAddress);
        vm.assertEq(_gaugeFactory.usdrifToken(), usdrifToken);

        // AND GaugeBeacon should be upgraded to the new implementation
        vm.assertEq(gaugeBeacon.implementation(), address(upgradeV3.gaugeImplV3()));

        // AND Gauge V3 functions should be accessible (not revert)
        GaugeRootstockCollective _gaugeV3 = GaugeRootstockCollective(address(gaugeBeacon.implementation()));
        // AND rifToken and usdrifToken should be zero address as _gaugeV3 is the implementation, not the proxy, so
        // there is no storage set
        vm.assertEq(_gaugeV3.rifToken(), address(0));
        vm.assertEq(_gaugeV3.usdrifToken(), address(0));
    }

    /**
     * SCENARIO: All gauges are upgraded to v3 and have rifToken and usdrifToken initialized
     */
    function test_fork_allGaugesUpgradedToV3() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // WHEN iterating over all gauges in the BuilderRegistry
        uint256 _gaugesLength = builderRegistryV3.getGaugesLength();

        // THEN each gauge should have rifToken and usdrifToken properly initialized
        for (uint256 i = 0; i < _gaugesLength; i++) {
            address _gaugeAddress = builderRegistryV3.getGaugeAt(i);
            GaugeRootstockCollective _gauge = GaugeRootstockCollective(_gaugeAddress);

            // Check that rifToken exists and is not zero address
            address _rifToken = _gauge.rifToken();
            vm.assertEq(_rifToken, rifTokenAddress);

            // Check that usdrifToken exists and is not zero address
            address _usdrifToken = _gauge.usdrifToken();
            vm.assertEq(_usdrifToken, usdrifToken);
            vm.assertEq(_usdrifToken, usdrifToken);
        }
    }

    /**
     * SCENARIO: All halted gauges are upgraded to v3 and have rifToken and usdrifToken initialized
     */
    function test_fork_allHaltedGaugesUpgradedToV3() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // WHEN iterating over all halted gauges in the BuilderRegistry
        uint256 _haltedGaugesLength = builderRegistryV3.getHaltedGaugesLength();
        for (uint256 i = 0; i < _haltedGaugesLength; i++) {
            address _gaugeAddress = builderRegistryV3.getHaltedGaugeAt(i);
            GaugeRootstockCollective _gauge = GaugeRootstockCollective(_gaugeAddress);

            // Check that usdrifToken exists and is not zero address
            address _usdrifToken = _gauge.usdrifToken();
            vm.assertEq(_usdrifToken, usdrifToken);
            vm.assertEq(_usdrifToken, usdrifToken);
        }
    }

    /**
     * @dev Upgrades the contracts to v3
     */
    function _upgradeV3() internal {
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(upgradeV3));
        upgradeV3.run();
        backersManagerV3 = BackersManagerRootstockCollective(address(upgradeV3.backersManagerProxy()));
        rewardDistributorV3 = RewardDistributorRootstockCollective(payable(address(upgradeV3.rewardDistributorProxy())));
        builderRegistryV3 = BuilderRegistryRootstockCollective(address(upgradeV3.builderRegistryProxy()));
    }

    /**
     * @dev Returns the implementation address of a proxy contract.
     * @param proxy_ The address of the proxy contract.
     * @return The implementation address of the proxy contract.
     */
    function _getImplementation(address proxy_) internal view returns (address) {
        return
            address(uint160(uint256(vm.load(proxy_, bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)))));
    }
}
