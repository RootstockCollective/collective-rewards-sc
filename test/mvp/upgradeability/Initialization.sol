// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { MVPBaseTest } from "../MVPBaseTest.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MVPInitializationTest is MVPBaseTest {
    /**
     * SCENARIO: SimplifiedRewardDistributor cannot be initialized twice
     */
    function test_RevertSimplifiedRewardDistributorInitialize() public {
        // GIVEN a SimplifiedRewardDistributor initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        simplifiedRewardDistributor.initialize(address(changeExecutorMock), address(rewardToken), address(kycApprover));
    }
}
