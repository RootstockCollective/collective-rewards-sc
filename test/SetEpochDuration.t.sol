// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { Governed } from "../src/governance/Governed.sol";
import { EpochTimeKeeper } from "../src/EpochTimeKeeper.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract SetEpochDurationTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewEpochDurationScheduled(uint256 newEpochDuration_, uint256 cooldownEndTime_);

    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(sponsorsManager), 100_000 ether);
    }

    function _initialState() internal {
        // GIVEN alice allocates to builder and builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        sponsorsManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
    }

    /**
     * SCENARIO: functions protected by OnlyGovernor should revert when are not
     *  called by Governor
     */
    function test_OnlyGovernor() public {
        // GIVEN a sponsor alice
        vm.startPrank(alice);

        // GIVEN mock authorized is false
        changeExecutorMock.setIsAuthorized(false);

        // WHEN alice calls setEpochDuration
        //  THEN tx reverts because caller is not the Governor
        vm.expectRevert(Governed.NotGovernorOrAuthorizedChanger.selector);
        sponsorsManager.setEpochDuration(3 weeks);
    }

    /**
     * SCENARIO: setEpochDuration reverts if the new duration is shorter than 2 times the distribution window
     */
    function test_RevertEpochDurationTooShort() public {
        // GIVEN a distribution window of 1 hour
        //  WHEN tries to setEpochDuration with 1.5 hours of duration
        //   THEN tx reverts because is too short
        vm.expectRevert(EpochTimeKeeper.EpochDurationTooShort.selector);
        sponsorsManager.setEpochDuration(1.5 hours);
    }

    /**
     * SCENARIO: setEpochDuration reverts if the new duration is not divisible by 1 hour
     */
    function test_RevertEpochDurationNotHourBasis() public {
        // GIVEN an epoch duration of 1 week
        //  WHEN tries to setEpochDuration with 2 weeks + 1 of duration
        //   THEN tx reverts because durations are not multiple
        vm.expectRevert(EpochTimeKeeper.EpochDurationNotHourBasis.selector);
        sponsorsManager.setEpochDuration(2 weeks + 1);
    }

    /**
     * SCENARIO: setEpochDuration reverts if the new duration is not multiple of the previous one
     */
    function test_RevertEpochDurationAreNotMultiples() public {
        // GIVEN an epoch duration of 1 week
        //  WHEN tries to setEpochDuration with 1.5 weeks of duration
        //   THEN tx reverts because durations are not multiple
        vm.expectRevert(EpochTimeKeeper.EpochDurationsAreNotMultiples.selector);
        sponsorsManager.setEpochDuration(1.5 weeks);
        //  WHEN tries to setEpochDuration with 5 days of duration
        //   THEN tx reverts because durations are not multiple
        vm.expectRevert(EpochTimeKeeper.EpochDurationsAreNotMultiples.selector);
        sponsorsManager.setEpochDuration(5 days);

        // GIVEN an epoch duration of 4 week
        sponsorsManager.setEpochDuration(4 weeks);
        _skipAndStartNewEpoch();
        _skipAndStartNewEpoch();
        assertEq(sponsorsManager.getEpochDuration(), 4 weeks);
        //  WHEN tries to setEpochDuration with 5 weeks of duration
        //   THEN tx reverts because durations are not multiple
        vm.expectRevert(EpochTimeKeeper.EpochDurationsAreNotMultiples.selector);
        sponsorsManager.setEpochDuration(5 weeks);
        //  WHEN tries to setEpochDuration with 3 weeks of duration
        //   THEN tx reverts because durations are not multiple
        vm.expectRevert(EpochTimeKeeper.EpochDurationsAreNotMultiples.selector);
        sponsorsManager.setEpochDuration(3 weeks);

        // GIVEN an epoch duration of 0.5 week
        sponsorsManager.setEpochDuration(0.5 weeks);
        _skipAndStartNewEpoch();
        assertEq(sponsorsManager.getEpochDuration(), 0.5 weeks);
        //  WHEN tries to setEpochDuration with 4 days of duration
        //   THEN tx reverts because durations are not multiple
        vm.expectRevert(EpochTimeKeeper.EpochDurationsAreNotMultiples.selector);
        sponsorsManager.setEpochDuration(4 days);
        //  WHEN tries to setEpochDuration with 2 days of duration
        //   THEN tx reverts because durations are not multiple
        vm.expectRevert(EpochTimeKeeper.EpochDurationsAreNotMultiples.selector);
        sponsorsManager.setEpochDuration(2 days);
    }

    /**
     * SCENARIO: governor sets a new epoch duration
     */
    function test_SetEpochDuration() public {
        // GIVEN a governor
        //  WHEN calls setEpochDuration
        //   THEN NewEpochDurationScheduled event is emitted
        uint256 _nextEpoch = UtilsLib._calcEpochNext(3 weeks, block.timestamp);
        vm.expectEmit();
        emit NewEpochDurationScheduled(3 weeks, _nextEpoch);
        sponsorsManager.setEpochDuration(3 weeks);

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.epochDuration();
        // THEN previous epoch duration is 1 week
        assertEq(_previous, 1 weeks);
        // THEN next epoch duration is 3 weeks
        assertEq(_next, 3 weeks);
        // THEN epoch duration is 1 week
        assertEq(sponsorsManager.getEpochDuration(), 1 weeks);
        // THEN cooldown end time is at the end of the 3 weeks epoch
        assertEq(_cooldownEndTime, _nextEpoch);

        // AND cooldown time ends
        vm.warp(_cooldownEndTime);
        // AND governor sets a new epoch duration of 6 weeks
        sponsorsManager.setEpochDuration(6 weeks);
        (_previous, _next, _cooldownEndTime) = sponsorsManager.epochDuration();
        // THEN previous epoch duration is 6 week
        assertEq(_previous, 3 weeks);
        // THEN next epoch duration is 6 weeks
        assertEq(_next, 6 weeks);
        // THEN epoch duration is 3 week
        assertEq(sponsorsManager.getEpochDuration(), 3 weeks);
        // THEN cooldown end time is at the end of the 6 weeks epoch
        assertEq(_cooldownEndTime, UtilsLib._calcEpochNext(6 weeks, block.timestamp));
    }

    /**
     * SCENARIO: governor sets a new epoch duration with the same value
     */
    function test_SetEpochDurationSameValue() public {
        // GIVEN an epoch duration of 1 week
        //  WHEN calls setEpochDuration again with 1 week
        vm.prank(builder);
        sponsorsManager.setEpochDuration(1 weeks);

        (uint64 _previous, uint64 _next,) = sponsorsManager.epochDuration();
        // THEN previous and next epoch durations are the same
        assertEq(_previous, _next);
    }

    /**
     * SCENARIO: governor sets a new epoch duration again before the current epoch finishes and the second one is
     * applied
     */
    function test_SetEpochDurationTwiceBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND governor sets a new epoch duration of 3 weeks
        sponsorsManager.setEpochDuration(3 weeks);

        (uint64 _previous, uint64 _next, uint128 _cooldownEndTime) = sponsorsManager.epochDuration();
        // AND cooldown time didn't end
        vm.warp(_cooldownEndTime - 1);

        // AND governor sets a new epoch duration of 4 weeks
        sponsorsManager.setEpochDuration(4 weeks);
        (_previous, _next, _cooldownEndTime) = sponsorsManager.epochDuration();
        // THEN previous epoch duration is 1 week
        assertEq(_previous, 1 weeks);
        // THEN next epoch duration is 4 weeks
        assertEq(_next, 4 weeks);
        // THEN epoch duration is 1 week
        assertEq(sponsorsManager.getEpochDuration(), 1 weeks);
        // THEN cooldown end time is at the end of the 4 weeks epoch
        assertEq(_cooldownEndTime, UtilsLib._calcEpochNext(4 weeks, block.timestamp));
    }

    /**
     * SCENARIO: governor sets a new longer epoch duration
     */
    function test_SetEpochDurationLonger() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND governor sets a new epoch duration of 3 weeks
        sponsorsManager.setEpochDuration(3 weeks);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN epoch duration is 1 weeks
        assertEq(sponsorsManager.getEpochDuration(), 1 weeks);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN epoch duration is 1 weeks
        assertEq(sponsorsManager.getEpochDuration(), 1 weeks);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN epoch duration is 3 weeks
        assertEq(sponsorsManager.getEpochDuration(), 3 weeks);

        // THEN period finish in 3 weeks
        assertEq(sponsorsManager.periodFinish(), block.timestamp + 3 weeks);
        // THEN totalPotentialReward is 16 * 3 weeks
        assertEq(sponsorsManager.totalPotentialReward(), 16 ether * 3 weeks);
        // THEN gauge rewardRate in rewardToken is 6.25 / 3 weeks; 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 6.25 ether / uint256(3 weeks));
        // THEN gauge rewardRate in coinbase is 0.625 / 3 weeks; 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0.625 ether / uint256(3 weeks));
        // THEN gauge2 rewardRate in rewardToken is 43.75 / 3 weeks; 43.75 = (100 * 2 / 16) * 0.5
        assertEq(gauge2.rewardRate(address(rewardToken)) / 10 ** 18, 43.75 ether / uint256(3 weeks));
        // THEN gauge2 rewardRate in coinbase is 4.375 / 3 weeks; 4.375 = (10 * 2 / 16) * 0.5
        assertEq(gauge2.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 4.375 ether / uint256(3 weeks));

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN gauge rewardPerToken in rewardToken is 9.375 = 6.25 * 3 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(address(rewardToken)), 9.375 ether, 100);
        // THEN gauge rewardPerToken in coinbase is 0.9375 = 0.625 * 3 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0.9375 ether, 100);
        // THEN gauge2 rewardPerToken in rewardToken is 9.375 = 43.75 * 3 distributions / 14 allocations
        assertApproxEqAbs(gauge2.rewardPerToken(address(rewardToken)), 9.375 ether, 100);
        // THEN gauge2 rewardPerToken in coinbase is 0.9375 = 4.375 * 3 distributions / 2 allocations
        assertApproxEqAbs(gauge2.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0.9375 ether, 100);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertEq(_clearERC20Balance(builder), 18.75 ether);
        // THEN builder receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertEq(_clearCoinbaseBalance(builder), 1.875 ether);

        // WHEN alice claims the rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 18.75 ether, 100);
        // THEN alice receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1.875 ether, 100);
    }

    /**
     * SCENARIO: governor sets a new shorter epoch duration
     */
    function test_SetEpochDurationShorter() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND governor sets a new epoch duration of 4 weeks
        sponsorsManager.setEpochDuration(0.5 weeks);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN epoch duration is 0.5 week
        assertEq(sponsorsManager.getEpochDuration(), 0.5 weeks);

        // THEN period finish in 0.5 weeks
        assertEq(sponsorsManager.periodFinish(), block.timestamp + 0.5 weeks);
        // THEN totalPotentialReward is 16 * 0.5 weeks
        assertEq(sponsorsManager.totalPotentialReward(), 16 ether * 0.5 weeks);
        // THEN gauge rewardRate in rewardToken is 6.25 / 0.5 weeks; 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 6.25 ether / uint256(0.5 weeks));
        // THEN gauge rewardRate in coinbase is 0.625 / 0.5 weeks; 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0.625 ether / uint256(0.5 weeks));
        // THEN gauge2 rewardRate in rewardToken is 43.75 / 0.5 weeks; 43.75 = (100 * 2 / 16) * 0.5
        assertEq(gauge2.rewardRate(address(rewardToken)) / 10 ** 18, 43.75 ether / uint256(0.5 weeks));
        // THEN gauge2 rewardRate in coinbase is 4.375 / 0.5 weeks; 4.375 = (10 * 2 / 16) * 0.5
        assertEq(gauge2.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 4.375 ether / uint256(0.5 weeks));

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN gauge rewardPerToken in rewardToken is 3.125 = 6.25 * 1 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(address(rewardToken)), 3.125 ether, 100);
        // THEN gauge rewardPerToken in coinbase is 0.3125 = 0.625 * 1 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0.3125 ether, 100);
        // THEN gauge2 rewardPerToken in rewardToken is 3.125 = 43.75 * 1 distributions / 14 allocations
        assertApproxEqAbs(gauge2.rewardPerToken(address(rewardToken)), 3.125 ether, 100);
        // THEN gauge2 rewardPerToken in coinbase is 0.3125 = 4.375 * 1 distributions / 2 allocations
        assertApproxEqAbs(gauge2.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0.3125 ether, 100);

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 50% of rewardToken 6.25 = (100 * 2 / 16) * 0.5
        assertEq(_clearERC20Balance(builder), 6.25 ether);
        // THEN builder receives 50% of coinbase 0.625 = (10 * 2 / 16) * 0.5
        assertEq(_clearCoinbaseBalance(builder), 0.625 ether);

        // WHEN alice claims the rewards
        vm.prank(alice);
        gauge.claimSponsorReward(alice);
        // THEN alice receives 50% of rewardToken 6.25 = (100 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 6.25 ether, 100);
        // THEN alice receives 50% of coinbase 0.625 = (10 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 0.625 ether, 100);
    }
}
