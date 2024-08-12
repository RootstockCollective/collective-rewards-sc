// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "../BaseTest.sol";
import {
    SupportHubUpgradeMock,
    RewardDistributorUpgradeMock,
    BuilderRegistryUpgradeMock,
    ChangeExecutorUpgradeMock
} from "../mock/UpgradesMocks.sol";

contract UpgradeTest is BaseTest {
    /**
     * SCENARIO: SupportHub is upgraded
     */
    function test_UpgradeSponsorsManager() public {
        // GIVEN a SupportHub proxy with an implementation
        // AND a new implementation
        SupportHubUpgradeMock supportHubNewImpl = new SupportHubUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        supportHub.upgradeToAndCall(address(supportHubNewImpl), abi.encodeCall(supportHubNewImpl.initializeMock, (42)));
        // THEN getCustomMockValue is 44 = 2 builderGaugeLength + 42 newVariable
        assertEq(SupportHubUpgradeMock(address(supportHub)).getCustomMockValue(), 44);
    }

    /**
     * SCENARIO: RewardDistributor is upgraded
     */
    function test_UpgradeRewardDistributor() public {
        // GIVEN a RewardDistributor proxy with an implementation
        // AND a new implementation
        RewardDistributorUpgradeMock rewardDistributorNewImpl = new RewardDistributorUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        rewardDistributor.upgradeToAndCall(
            address(rewardDistributorNewImpl), abi.encodeCall(rewardDistributorNewImpl.initializeMock, (43))
        );
        uint256 newVar = RewardDistributorUpgradeMock(address(rewardDistributor)).getCustomMockValue()
            - (uint256(uint160(foundation)));
        // THEN getCustomMockValue is foundation address + 43 newVariable
        assertEq(newVar, 43);
    }

    /**
     * SCENARIO: BuilderRegistry is upgraded
     */
    function test_UpgradeBuilderRegistry() public {
        // GIVEN a BuilderRegistry proxy with an implementation
        // AND a new implementation
        BuilderRegistryUpgradeMock builderRegistryNewImpl = new BuilderRegistryUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        builderRegistry.upgradeToAndCall(
            address(builderRegistryNewImpl), abi.encodeCall(builderRegistryNewImpl.initializeMock, (44))
        );
        uint256 newVar =
            BuilderRegistryUpgradeMock(address(builderRegistry)).getCustomMockValue() - (uint256(uint160(governor)));
        // THEN getCustomMockValue is governor address + 44 newVariable
        assertEq(newVar, 44);
    }

    /**
     * SCENARIO: ChangeExecutor is upgraded
     */
    function test_UpgradeChangeExecutor() public {
        // GIVEN a ChangeExecutor proxy with an implementation
        // AND a new implementation
        ChangeExecutorUpgradeMock changeExecutorNewImpl = new ChangeExecutorUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        vm.prank(governor);
        changeExecutorMock.upgradeToAndCall(
            address(changeExecutorNewImpl), abi.encodeCall(changeExecutorNewImpl.initializeMock, (45))
        );
        uint256 newVar =
            ChangeExecutorUpgradeMock(address(changeExecutorMock)).getCustomMockValue() - (uint256(uint160(governor)));
        // THEN getCustomMockValue is governor address + 45 newVariable
        assertEq(newVar, 45);
    }
}
