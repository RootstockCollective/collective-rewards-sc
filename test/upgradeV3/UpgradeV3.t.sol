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

contract UpgradeV3Test is Test {
    IBackersManagerRootstockCollectiveV2 public backersManagerV2;
    BackersManagerRootstockCollective public backersManagerV3;
    BuilderRegistryRootstockCollective public builderRegistry;
    IGovernanceManagerRootstockCollective public governanceManager;
    IRewardDistributorRootstockCollectiveV2 public rewardDistributorV2;
    RewardDistributorRootstockCollective public rewardDistributorV3;
    GaugeBeaconRootstockCollective public gaugeBeacon;
    UpgradeV3 public upgradeV3;
    address public upgrader;
    address public configurator = makeAddr("configurator");
    address public alice = makeAddr("alice");
    address public usdrifToken = vm.envAddress("USDRIF_TOKEN_ADDRESS");

    function setUp() public {
        backersManagerV2 =
            IBackersManagerRootstockCollectiveV2(vm.envOr("BackersManagerRootstockCollectiveProxy", address(0)));
        builderRegistry =
            BuilderRegistryRootstockCollective(vm.envOr("BuilderRegistryRootstockCollectiveProxy", address(0)));
        governanceManager =
            IGovernanceManagerRootstockCollective(vm.envOr("GovernanceManagerRootstockCollectiveProxy", address(0)));
        rewardDistributorV2 = IRewardDistributorRootstockCollectiveV2(
            payable(vm.envOr("RewardDistributorRootstockCollectiveProxy", address(0)))
        );
        GaugeFactoryRootstockCollective _gaugeFactory =
            GaugeFactoryRootstockCollective(vm.envOr("GaugeFactoryRootstockCollective", address(0)));
        gaugeBeacon = GaugeBeaconRootstockCollective(_gaugeFactory.beacon());

        upgrader = governanceManager.upgrader();

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
        vm.assertEq(address(upgradeV3.backersManagerProxyV2()), address(backersManagerV2));
        vm.assertNotEq(address(upgradeV3.backersManagerImplV3()), address(0));

        vm.assertEq(address(upgradeV3.builderRegistryProxy()), address(builderRegistry));
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
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN backersManagerV2 should have the new implementation
        vm.assertEq(_getImplementation(address(backersManagerV2)), address(upgradeV3.backersManagerImplV3()));
        // AND should follow v3 interface
        vm.assertEq(backersManagerV3.maxDistributionsPerBatch(), upgradeV3.MAX_DISTRIBUTIONS_PER_BATCH());
    }

    /**
     * SCENARIO: BuilderRegistry is upgraded to v3
     */
    function test_fork_upgradeBuilderRegistry() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN BuilderRegistry should have the new implementation
        vm.assertEq(_getImplementation(address(builderRegistry)), address(upgradeV3.builderRegistryImplV3()));
        // AND should follow v3 interface
        vm.assertEq(builderRegistry.rewardReceiver(alice), address(0));
        // AND should have the new GaugeFactory set
        vm.assertEq(address(builderRegistry.gaugeFactory()), address(upgradeV3.gaugeFactoryV3()));
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
        vm.assertNotEq(governanceManager.configurator(), address(0));
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
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN rewardDistributor should have the new implementation
        vm.assertEq(_getImplementation(address(rewardDistributorV3)), address(upgradeV3.rewardDistributorImplV3()));
        // AND usdrifToken should be initialized with the same token as backersManagerV2
        vm.assertEq(address(rewardDistributorV3.usdrifToken()), address(backersManagerV3.usdrifToken()));
        vm.assertEq(address(rewardDistributorV3.usdrifToken()), usdrifToken);
        // AND rifToken should be initialized with the same token as backersManagerV3
        vm.assertEq(address(rewardDistributorV3.rifToken()), address(backersManagerV3.rifToken()));
        vm.assertNotEq(address(rewardDistributorV3.rifToken()), address(0));
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
        vm.assertEq(address(rewardDistributorV3.rifToken()), address(backersManagerV3.rifToken()));
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
     * SCENARIO: initializeUsdrifToken works correctly during upgrade
     */
    function test_fork_initializeUsdrifToken() public {
        // GIVEN the contracts are not yet upgraded
        // WHEN the upgrade is performed
        _upgradeV3();

        // THEN usdrifToken should be properly initialized
        vm.assertNotEq(address(rewardDistributorV3.usdrifToken()), address(0));
        vm.assertEq(address(rewardDistributorV3.usdrifToken()), usdrifToken);
        vm.assertEq(address(rewardDistributorV3.usdrifToken()), address(backersManagerV3.usdrifToken()));
    }

    /**
     * SCENARIO: initializeUsdrifToken cannot be called twice
     */
    function test_fork_initializeUsdrifToken_cannotCallTwice() public {
        // GIVEN the upgrade is performed and usdrifToken is initialized
        _upgradeV3();
        vm.assertNotEq(address(rewardDistributorV3.usdrifToken()), address(0));

        // WHEN trying to call initializeUsdrifToken again
        // THEN it should revert with UsdrifTokenAlreadyInitialized
        vm.expectRevert(RewardDistributorRootstockCollective.UsdrifTokenAlreadyInitialized.selector);
        rewardDistributorV3.initializeUsdrifToken();
    }

    /**
     * SCENARIO: GaugeFactory is deployed with correct parameters
     */
    function test_fork_gaugeFactoryV3Setup() public {
        // GIVEN the upgrade is performed
        _upgradeV3();

        // THEN GaugeFactory should be properly configured
        GaugeFactoryRootstockCollective _gaugeFactory = upgradeV3.gaugeFactoryV3();
        vm.assertEq(_gaugeFactory.beacon(), address(gaugeBeacon));
        vm.assertEq(_gaugeFactory.rifToken(), address(backersManagerV3.rifToken()));
        vm.assertEq(_gaugeFactory.usdrifToken(), usdrifToken);
    }

    /**
     * @dev Upgrades the contracts to v3
     */
    function _upgradeV3() internal {
        vm.prank(upgrader);
        governanceManager.updateUpgrader(address(upgradeV3));
        upgradeV3.run();
        backersManagerV3 = BackersManagerRootstockCollective(address(upgradeV3.backersManagerProxyV2()));
        rewardDistributorV3 = RewardDistributorRootstockCollective(payable(address(upgradeV3.rewardDistributorProxy())));
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
