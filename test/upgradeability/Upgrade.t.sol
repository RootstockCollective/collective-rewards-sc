// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "../BaseTest.sol";
import {
    SponsorsManagerUpgradeMock,
    RewardDistributorUpgradeMock,
    GaugeUpgradeMock,
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
            GaugeUpgradeMock(address(gauge)).getCustomMockValue() - (uint256(uint160(address(sponsorsManager))));
        // THEN getCustomMockValue is sponsorsManager address + 46 newVariable
        assertEq(_newVar, 46);
        // AND gauge2 initialized
        GaugeUpgradeMock(address(gauge2)).initializeMock(47);
        uint256 _newVar2 =
            GaugeUpgradeMock(address(gauge2)).getCustomMockValue() - (uint256(uint160(address(sponsorsManager))));
        // THEN getCustomMockValue is sponsorsManager address + 47 newVariable
        assertEq(_newVar2, 47);

        // WHEN new gauge is created through the factory
        address _newBuilder = makeAddr("newBuilder");
        address _newGauge = address(_whitelistBuilder(_newBuilder, _newBuilder, 1 ether));
        // AND gauge3 initialized
        GaugeUpgradeMock(_newGauge).initializeMock(48);
        uint256 _newVar3 =
            GaugeUpgradeMock(_newGauge).getCustomMockValue() - (uint256(uint160(address(sponsorsManager))));
        // THEN getCustomMockValue is sponsorsManager address + 48 newVariable
        assertEq(_newVar3, 48);
    }
}
