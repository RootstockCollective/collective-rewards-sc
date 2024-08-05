// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { MVPBaseTest } from "../MVPBaseTest.sol";
import { SimplifiedRewardDistributorUpgradeMock } from "../../mock/UpgradesMocks.sol";

contract MVPUpgradeTest is MVPBaseTest {
    /**
     * SCENARIO: SimplifiedRewardDistributor is upgraded
     */
    function test_UpgradeSimplifiedRewardDistributorr() public {
        // GIVEN a SimplifiedRewardDistributor proxy with an implementation
        // AND a new implementation
        SimplifiedRewardDistributorUpgradeMock simplifiedRewardDistributorNewImpl =
            new SimplifiedRewardDistributorUpgradeMock();
        //WHEN the proxy is upgraded and initialized
        simplifiedRewardDistributor.upgradeToAndCall(
            address(simplifiedRewardDistributorNewImpl),
            abi.encodeCall(simplifiedRewardDistributorNewImpl.initializeMock, (30))
        );
        uint256 newVar = SimplifiedRewardDistributorUpgradeMock(payable(address(simplifiedRewardDistributor)))
            .getCustomMockValue() - (uint256(uint160(governor)));
        // THEN getCustomMockValue is governor address + 30 newVariable
        assertEq(newVar, 30);
    }
}
