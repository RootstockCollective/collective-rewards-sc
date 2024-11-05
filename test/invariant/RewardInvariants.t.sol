// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseInvariants } from "./BaseInvariants.sol";

contract RewardInvariants is BaseInvariants {
    /**
     * SCENARIO: all the rewards are distributed to sponsors and builder
     * Gauges and SponsorsManagerRootstockCollective only keep with dust because rounding errors
     */
    function invariant_Rewards() public useTime {
        uint256 _totalBuilderBalances;
        uint256 _totalSponsorsBalances;
        uint256 _totalGaugesBalances;
        uint256 _totalIncentives;

        timeManager.increaseTimestamp(sponsorsManager.cycleNext(block.timestamp) - block.timestamp);

        _buildersClaim();

        for (uint256 i = 0; i < allocateHandler.sponsorsLength(); i++) {
            vm.prank(allocateHandler.sponsors(i));
            sponsorsManager.claimSponsorRewards(gaugesArray);
            _totalSponsorsBalances += rewardToken.balanceOf(allocateHandler.sponsors(i));
        }

        for (uint256 i = 0; i < builders.length; i++) {
            // if builder is also an sponsors is not considered here to do not add its balance twice
            if (!allocateHandler.sponsorExists(builders[i])) {
                _totalBuilderBalances += rewardToken.balanceOf(builders[i]);
            }
        }

        for (uint256 i = 0; i < gaugesArray.length; i++) {
            _totalGaugesBalances += rewardToken.balanceOf(address(gaugesArray[i]));
            _totalIncentives += incentivizeHandler.rewardTokenIncentives(gaugesArray[i]);
        }

        uint256 _sponsorsManagerBalance = rewardToken.balanceOf(address(sponsorsManager));

        assertEq(
            distributionHandler.totalAmountDistributed() + _totalIncentives,
            _totalGaugesBalances + _sponsorsManagerBalance + _totalBuilderBalances + _totalSponsorsBalances
        );

        assertLe(_sponsorsManagerBalance, 10_000);

        for (uint256 i = 0; i < gaugesArray.length; i++) {
            if (gaugesArray[i].totalAllocation() > 0) {
                uint256 _gaugeBalance = rewardToken.balanceOf(address(gaugesArray[i]))
                    - gaugesArray[i].rewardMissing(address(rewardToken)) / 10 ** 18;
                assertLe(_gaugeBalance, 10_000);
            } else {
                assertEq(
                    rewardToken.balanceOf(address(gaugesArray[i])),
                    incentivizeHandler.rewardTokenIncentives(gaugesArray[i])
                );
            }
        }
    }
}
