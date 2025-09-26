// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BaseInvariants } from "./BaseInvariants.sol";

contract RewardInvariants is BaseInvariants {
    /**
     * SCENARIO: all the rewards are distributed to backers and builder
     * Gauges and BackersManagerRootstockCollective only keep with dust because rounding errors
     */
    function invariant_Rewards() public useTime {
        uint256 _totalBuilderBalances;
        uint256 _totalBackersBalances;
        uint256 _totalGaugesBalances;
        uint256 _totalIncentives;
        uint256 _totalBuilderBalancesUsdrif;
        uint256 _totalBackersBalancesUsdrif;
        uint256 _totalGaugesBalancesUsdrif;
        uint256 _totalIncentivesUsdrif;

        timeManager.increaseTimestamp(backersManager.cycleNext(block.timestamp) - block.timestamp);

        _buildersClaim();

        for (uint256 i = 0; i < allocateHandler.backersLength(); i++) {
            vm.prank(allocateHandler.backers(i));
            backersManager.claimBackerRewards(gaugesArray);
            _totalBackersBalances += rifToken.balanceOf(allocateHandler.backers(i));
            _totalBackersBalancesUsdrif += usdrifToken.balanceOf(allocateHandler.backers(i));
        }

        for (uint256 i = 0; i < builders.length; i++) {
            // if builder is also an backers is not considered here to do not add its balance twice
            if (!allocateHandler.backerExists(builders[i])) {
                _totalBuilderBalances += rifToken.balanceOf(builders[i]);
                _totalBuilderBalancesUsdrif += usdrifToken.balanceOf(builders[i]);
            }
        }

        for (uint256 i = 0; i < gaugesArray.length; i++) {
            _totalGaugesBalances += rifToken.balanceOf(address(gaugesArray[i]));
            _totalIncentives += incentivizeHandler.rifTokenIncentives(gaugesArray[i]);
            _totalGaugesBalancesUsdrif += usdrifToken.balanceOf(address(gaugesArray[i]));
            _totalIncentivesUsdrif += incentivizeHandler.usdrifTokenIncentives(gaugesArray[i]);
        }

        uint256 _backersManagerBalance = rifToken.balanceOf(address(backersManager));
        uint256 _backersManagerBalanceUsdrif = usdrifToken.balanceOf(address(backersManager));

        // Check RIF token balances
        assertEq(
            distributionHandler.totalAmountDistributed() + _totalIncentives,
            _totalGaugesBalances + _backersManagerBalance + _totalBuilderBalances + _totalBackersBalances
        );

        assertLe(_backersManagerBalance, DUST);

        // Check USDRIF token balances
        assertEq(
            distributionHandler.totalAmountDistributedUsdrif() + _totalIncentivesUsdrif,
            _totalGaugesBalancesUsdrif + _backersManagerBalanceUsdrif + _totalBuilderBalancesUsdrif
                + _totalBackersBalancesUsdrif
        );

        assertLe(_backersManagerBalanceUsdrif, DUST);

        for (uint256 i = 0; i < gaugesArray.length; i++) {
            uint256 _gaugeBalance = rifToken.balanceOf(address(gaugesArray[i]));
            uint256 _gaugeAccountedBalance;
            if (gaugesArray[i].totalAllocation() > 0) {
                _gaugeAccountedBalance = gaugesArray[i].rewardMissing(address(rifToken)) / 10 ** 18;
            } else {
                _gaugeAccountedBalance = incentivizeHandler.rifTokenIncentives(gaugesArray[i]);
            }
            // There might be dust from previous cycles
            assertLe(_gaugeBalance - _gaugeAccountedBalance, DUST);

            // Check USDRIF token balances for gauges
            uint256 _gaugeBalanceUsdrif = usdrifToken.balanceOf(address(gaugesArray[i]));
            uint256 _gaugeAccountedBalanceUsdrif;
            if (gaugesArray[i].totalAllocation() > 0) {
                _gaugeAccountedBalanceUsdrif = gaugesArray[i].rewardMissing(address(usdrifToken)) / 10 ** 18;
            } else {
                _gaugeAccountedBalanceUsdrif = incentivizeHandler.usdrifTokenIncentives(gaugesArray[i]);
            }
            // There might be dust from previous cycles
            assertLe(_gaugeBalanceUsdrif - _gaugeAccountedBalanceUsdrif, DUST);
        }
    }
}
