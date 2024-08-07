// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "../BaseTest.sol";
import {
    SponsorsManagerUpgradeMock,
    RewardDistributorUpgradeMock,
    BuilderRegistryUpgradeMock,
    ChangeExecutorUpgradeMock
} from "../mock/UpgradesMocks.sol";

contract UpgradeTest is BaseTest {
    /**
     * SCENARIO: SponsorsManager is upgraded
     */
    function test_UpgradeSponsorsManager() public {
        // GIVEN a SponsorsManager proxy with an implementation
        // AND a new implementation
        SponsorsManagerUpgradeMock _sponsorsManagerNewImpl = new SponsorsManagerUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        sponsorsManager.upgradeToAndCall(
            address(_sponsorsManagerNewImpl), abi.encodeCall(_sponsorsManagerNewImpl.initializeMock, (42))
        );
        // THEN getCustomMockValue is 44 = 2 gaugeLength + 42 newVariable
        assertEq(SponsorsManagerUpgradeMock(address(sponsorsManager)).getCustomMockValue(), 44);
    }

    /**
     * SCENARIO: RewardDistributor is upgraded
     */
    function test_UpgradeRewardDistributor() public {
        // GIVEN a RewardDistributor proxy with an implementation
        // AND a new implementation
        RewardDistributorUpgradeMock _rewardDistributorNewImpl = new RewardDistributorUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        rewardDistributor.upgradeToAndCall(
            address(_rewardDistributorNewImpl), abi.encodeCall(_rewardDistributorNewImpl.initializeMock, (43))
        );
        uint256 _newVar = RewardDistributorUpgradeMock(address(rewardDistributor)).getCustomMockValue()
            - (uint256(uint160(foundation)));
        // THEN getCustomMockValue is foundation address + 43 newVariable
        assertEq(_newVar, 43);
    }

    /**
     * SCENARIO: BuilderRegistry is upgraded
     */
    function test_UpgradeBuilderRegistry() public {
        // GIVEN a BuilderRegistry proxy with an implementation
        // AND a new implementation
        BuilderRegistryUpgradeMock _builderRegistryNewImpl = new BuilderRegistryUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        builderRegistry.upgradeToAndCall(
            address(_builderRegistryNewImpl), abi.encodeCall(_builderRegistryNewImpl.initializeMock, (44))
        );
        uint256 _newVar =
            BuilderRegistryUpgradeMock(address(builderRegistry)).getCustomMockValue() - (uint256(uint160(governor)));
        // THEN getCustomMockValue is governor address + 44 newVariable
        assertEq(_newVar, 44);
    }

    /**
     * SCENARIO: ChangeExecutor is upgraded
     */
    function test_UpgradeChangeExecutor() public {
        // GIVEN a ChangeExecutor proxy with an implementation
        // AND a new implementation
        ChangeExecutorUpgradeMock _changeExecutorNewImpl = new ChangeExecutorUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        vm.prank(governor);
        changeExecutorMock.upgradeToAndCall(
            address(_changeExecutorNewImpl), abi.encodeCall(_changeExecutorNewImpl.initializeMock, (45))
        );
        uint256 _newVar =
            ChangeExecutorUpgradeMock(address(changeExecutorMock)).getCustomMockValue() - (uint256(uint160(governor)));
        // THEN getCustomMockValue is governor address + 45 newVariable
        assertEq(_newVar, 45);
    }
}
