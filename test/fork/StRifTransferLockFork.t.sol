// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/src/Test.sol";
import { BackersManagerRootstockCollective } from "src/BackersManagerRootstockCollective.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";
import { IStRIFTokenV02 } from "./interfaces/IStRIFTokenV02.sol";

contract StRifTransferLockFork is Test {
    address public tokenHolderAddress;
    BackersManagerRootstockCollective public backersManager;
    IStRIFTokenV02 public stRif;
    GaugeRootstockCollective public operationalGauge;

    function setUp() public {
        backersManager = BackersManagerRootstockCollective(vm.envAddress("BACKERS_MANAGER_ADDRESS_FORK"));
        tokenHolderAddress = vm.envAddress("TOKEN_HOLDER_ADDRESS_FORK");
        stRif = IStRIFTokenV02(address(backersManager.stakingToken()));
        operationalGauge = _getOperationalGauge();
    }

    /**
     * SCENARIO: A backer allocates their stRIF tokens and tries to transfer them
     */
    function test_fork_LockAllocatedStRif() public {
        // Given a backer with stRIF tokens
        uint256 _balance = stRif.balanceOf(tokenHolderAddress);
        vm.assertTrue(_balance > 0, "Backer has no stRIF tokens");
        uint256 _backerTotalAllocation = backersManager.backerTotalAllocation(tokenHolderAddress);
        uint256 _amountToAllocate = _balance - _backerTotalAllocation;

        // When the backer allocates their stRIF tokens to an operational gauge
        vm.prank(tokenHolderAddress);
        backersManager.allocate(operationalGauge, _amountToAllocate);

        // Then the allocated amount should equal the backer's balance
        uint256 _allocated = operationalGauge.allocationOf(tokenHolderAddress);
        vm.assertEq(_allocated, _balance);

        // And the backer should not be able to transfer their stRIF tokens
        vm.startPrank(tokenHolderAddress);
        bytes memory _withdrawError =
            abi.encodeWithSelector(IStRIFTokenV02.STRIFStakedInCollectiveRewardsCanWithdraw.selector, false);
        vm.expectRevert(_withdrawError);
        stRif.transfer(address(this), _allocated);
        vm.expectRevert(_withdrawError);
        stRif.transfer(address(this), 1);

        // And the backer should not be able to withdraw their stRIF tokens
        vm.expectRevert(_withdrawError);
        stRif.withdrawTo(address(this), 1);
        vm.stopPrank();
    }

    function _getOperationalGauge() internal view returns (GaugeRootstockCollective) {
        uint256 _length = backersManager.getGaugesLength();
        for (uint256 i = 0; i < _length; i++) {
            GaugeRootstockCollective _gauge = GaugeRootstockCollective(backersManager.getGaugeAt(i));
            if (backersManager.isGaugeOperational(_gauge)) {
                return _gauge;
            }
        }
        revert("No operational gauge found");
    }
}
