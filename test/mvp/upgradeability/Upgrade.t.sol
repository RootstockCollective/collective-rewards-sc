// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MVPBaseTest } from "../MVPBaseTest.sol";
import { SimplifiedRewardDistributorUpgradeMock } from "../../mock/UpgradesMocks.sol";

contract MVPUpgradeTest is MVPBaseTest {
    /**
     * SCENARIO: SimplifiedRewardDistributorRootstockCollective is upgraded
     */
    function test_UpgradeSimplifiedRewardDistributorr() public {
        // GIVEN a SimplifiedRewardDistributorRootstockCollective proxy with an implementation
        // AND a new implementation
        SimplifiedRewardDistributorUpgradeMock _simplifiedRewardDistributorNewImpl =
            new SimplifiedRewardDistributorUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        simplifiedRewardDistributor.upgradeToAndCall(
            address(_simplifiedRewardDistributorNewImpl),
            abi.encodeCall(_simplifiedRewardDistributorNewImpl.initializeMock, (30))
        );
        uint256 _newVar = SimplifiedRewardDistributorUpgradeMock(payable(address(simplifiedRewardDistributor)))
            .getCustomMockValue() - (uint256(uint160(governor)));
        // THEN getCustomMockValue is governor address + 30 newVariable
        assertEq(_newVar, 30);
    }
}
