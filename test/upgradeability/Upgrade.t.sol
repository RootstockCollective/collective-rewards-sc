// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "../BaseTest.sol";
import {
    BuilderRegistryRootstockCollectiveUpgradeMock,
    RewardDistributorRootstockCollectiveUpgradeMock,
    GaugeUpgradeMock,
    GovernanceManagerRootstockCollectiveUpgradeMock
} from "../mock/UpgradesMocks.sol";

contract UpgradeTest is BaseTest {
    /**
     * SCENARIO: BuilderRegistryRootstockCollective is upgraded
     */
    function test_UpgradeBuilderRegistryRootstockCollective() public {
        // GIVEN a BuilderRegistryRootstockCollective proxy with an implementation
        // AND a new implementation
        BuilderRegistryRootstockCollectiveUpgradeMock _builderRegistryNewImpl =
            new BuilderRegistryRootstockCollectiveUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        vm.prank(governor);
        builderRegistry.upgradeToAndCall(
            address(_builderRegistryNewImpl), abi.encodeCall(_builderRegistryNewImpl.initializeMock, (42))
        );
        // THEN getCustomMockValue is 44 = 2 gaugeLength + 42 newVariable
        assertEq(BuilderRegistryRootstockCollectiveUpgradeMock(address(builderRegistry)).getCustomMockValue(), 44);
    }

    /**
     * SCENARIO: RewardDistributorRootstockCollective is upgraded
     */
    function test_UpgradeRewardDistributorRootstockCollective() public {
        // GIVEN a RewardDistributorRootstockCollective proxy with an implementation
        // AND a new implementation
        RewardDistributorRootstockCollectiveUpgradeMock _rewardDistributorNewImpl =
            new RewardDistributorRootstockCollectiveUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        vm.prank(governor);
        rewardDistributor.upgradeToAndCall(
            address(_rewardDistributorNewImpl), abi.encodeCall(_rewardDistributorNewImpl.initializeMock, (43))
        );
        uint256 _newVar = RewardDistributorRootstockCollectiveUpgradeMock(payable(rewardDistributor)).getCustomMockValue(
        ) - (uint256(uint160(foundation)));
        // THEN getCustomMockValue is foundation address + 43 newVariable
        assertEq(_newVar, 43);
    }

    /**
     * SCENARIO: GovernanceManagerRootstockCollective is upgraded
     */
    function test_UpgradeGovernanceManagerRootstockCollective() public {
        // GIVEN a GovernanceManagerRootstockCollective proxy with an implementation
        // AND a new implementation
        GovernanceManagerRootstockCollectiveUpgradeMock _governanceManagerNewImpl =
            new GovernanceManagerRootstockCollectiveUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        vm.prank(governor);
        governanceManager.upgradeToAndCall(
            address(_governanceManagerNewImpl), abi.encodeCall(_governanceManagerNewImpl.initializeMock, (45))
        );
        uint256 _newVar = GovernanceManagerRootstockCollectiveUpgradeMock(address(governanceManager)).getCustomMockValue(
        ) - (uint256(uint160(governor)));
        // THEN getCustomMockValue is governor address + 45 newVariable
        assertEq(_newVar, 45);
    }

    /**
     * SCENARIO: Gauge is upgraded
     */
    function test_UpgradeGauge() public {
        // GIVEN a Gauge proxy with an implementation
        // AND a new implementation
        GaugeUpgradeMock _gaugeNewImpl = new GaugeUpgradeMock();
        //WHEN the proxy is upgraded
        vm.prank(governor);
        gaugeBeacon.upgradeTo(address(_gaugeNewImpl));
        // AND gauge initialized
        GaugeUpgradeMock(address(gauge)).initializeMock(46);
        uint256 _newVar =
            GaugeUpgradeMock(address(gauge)).getCustomMockValue() - (uint256(uint160(address(backersManager))));
        // THEN getCustomMockValue is backersManager address + 46 newVariable
        assertEq(_newVar, 46);
        // AND gauge2 initialized
        GaugeUpgradeMock(address(gauge2)).initializeMock(47);
        uint256 _newVar2 =
            GaugeUpgradeMock(address(gauge2)).getCustomMockValue() - (uint256(uint160(address(backersManager))));
        // THEN getCustomMockValue is backersManager address + 47 newVariable
        assertEq(_newVar2, 47);

        // WHEN new gauge is created through the factory
        address _newBuilder = makeAddr("newBuilder");
        address _newGauge = address(_whitelistBuilder(_newBuilder, _newBuilder, 1 ether));
        // AND gauge3 initialized
        GaugeUpgradeMock(_newGauge).initializeMock(48);
        uint256 _newVar3 =
            GaugeUpgradeMock(_newGauge).getCustomMockValue() - (uint256(uint160(address(backersManager))));
        // THEN getCustomMockValue is backersManager address + 48 newVariable
        assertEq(_newVar3, 48);
    }
}
