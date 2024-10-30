// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MVPBaseTest } from "../MVPBaseTest.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MVPInitializationTest is MVPBaseTest {
    /**
     * SCENARIO: SimplifiedRewardDistributorRootstockCollective cannot be initialized twice
     */
    function test_RevertSimplifiedRewardDistributorInitialize() public {
        // GIVEN a SimplifiedRewardDistributorRootstockCollective initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        simplifiedRewardDistributor.initialize(address(changeExecutorMock), address(rewardToken));
    }

    /**
     * SCENARIO: ChangeExecutor cannot be initialized twice
     */
    function test_RevertChangeExecutorInitialize() public {
        // GIVEN a ChangeExecutor initialized
        //  WHEN tries to initialize the proxy again
        //   THEN tx reverts because InvalidInitialization
        vm.prank(governor);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        changeExecutorMock.initialize(governor);
    }
}
