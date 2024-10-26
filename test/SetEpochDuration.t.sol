// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { EpochTimeKeeper } from "../src/EpochTimeKeeper.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";
import { IGovernanceManager } from "src/interfaces/IGovernanceManager.sol";

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
        //  WHEN alice calls setEpochDuration
        //   THEN tx reverts because caller is not the Governor

        vm.prank(alice);
        vm.expectRevert(IGovernanceManager.NotAuthorizedChanger.selector);
        sponsorsManager.setEpochDuration(3 weeks, 0 days);
    }

    /**
     * SCENARIO: setEpochDuration reverts if the new duration is shorter than 2 times the distribution window
     */
    function test_RevertEpochDurationTooShort() public {
        // GIVEN a distribution window of 1 hour
        //  WHEN governor tries to setEpochDuration with 1.5 hours of duration
        //   THEN tx reverts because is too short
        vm.prank(governor);
        vm.expectRevert(EpochTimeKeeper.EpochDurationTooShort.selector);
        sponsorsManager.setEpochDuration(1.5 hours, 0 days);
    }

    /**
     * SCENARIO: governor sets a new epoch duration
     */
    function test_SetEpochDuration() public {
        // GIVEN a governor
        //  WHEN calls setEpochDuration
        //   THEN NewEpochDurationScheduled event is emitted
        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart,) =
            sponsorsManager.epochData();
        uint256 _nextEpoch = UtilsLib._calcEpochNext(_previousStart, 1 weeks, block.timestamp);
        vm.prank(governor);
        vm.expectEmit();
        emit NewEpochDurationScheduled(3 weeks, _nextEpoch);
        sponsorsManager.setEpochDuration(3 weeks, 0 days);

        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = sponsorsManager.epochData();
        // THEN previous epoch duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next epoch duration is 3 weeks
        assertEq(_nextDuration, 3 weeks);
        // THEN previous epoch starts is now
        assertEq(_previousStart, block.timestamp);
        // THEN next epoch starts in 1 weeks from now
        assertEq(_nextStart, block.timestamp + 1 weeks);

        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch start is now
        assertEq(_epochStart, block.timestamp);
        // THEN epoch duration is 1 week
        assertEq(_epochDuration, 1 weeks);
        // THEN epoch finishes in 1 week
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1 weeks);

        // AND epoch finishes
        _skipAndStartNewEpoch();
        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = sponsorsManager.epochData();
        // THEN previous epoch duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next epoch duration is 3 weeks
        assertEq(_nextDuration, 3 weeks);
        // THEN previous epoch starts is 1 weeks ago
        assertEq(_previousStart, block.timestamp - 1 weeks);
        // THEN next epoch starts is now
        assertEq(_nextStart, block.timestamp);

        // AND governor sets a new epoch duration of 6 weeks
        vm.prank(governor);
        sponsorsManager.setEpochDuration(6 weeks, 0 days);
        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = sponsorsManager.epochData();
        // THEN previous epoch duration is 3 week
        assertEq(_previousDuration, 3 weeks);
        // THEN next epoch duration is 6 weeks
        assertEq(_nextDuration, 6 weeks);
        // THEN previous epoch starts is now
        assertEq(_previousStart, block.timestamp);
        // THEN next epoch starts in 3 weeks from now
        assertEq(_nextStart, block.timestamp + 3 weeks);

        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch start is now
        assertEq(_epochStart, block.timestamp);
        // THEN epoch duration is 3 week
        assertEq(_epochDuration, 3 weeks);
        // THEN epoch finishes in 3 week
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 3 weeks);
    }

    /**
     * SCENARIO: governor sets a new epoch duration with the same value
     */
    function test_SetEpochDurationSameValue() public {
        // GIVEN an epoch duration of 1 week
        //  WHEN calls setEpochDuration again with 1 week
        vm.prank(governor);
        sponsorsManager.setEpochDuration(1 weeks, 0 days);

        (uint32 _previousDuration, uint32 _nextDuration,,,) = sponsorsManager.epochData();
        // THEN previous and next epoch durations are the same
        assertEq(_previousDuration, _nextDuration);
    }

    /**
     * SCENARIO: governor sets a new epoch duration again before the current epoch finishes and the second one is
     * applied
     */
    function test_SetEpochDurationTwiceBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND governor sets a new epoch duration of 3 weeks
        vm.prank(governor);
        sponsorsManager.setEpochDuration(3 weeks, 0 days);

        (uint32 _previousDuration, uint32 _nextDuration,, uint64 _nextStart,) = sponsorsManager.epochData();
        // AND epoch didn't finish, 1 sec is remaining
        vm.warp(block.timestamp + 1 weeks - 1);

        // AND governor sets a new epoch duration of 4 weeks
        vm.prank(governor);
        sponsorsManager.setEpochDuration(4 weeks, 0 days);
        (_previousDuration, _nextDuration,, _nextStart,) = sponsorsManager.epochData();
        // THEN previous epoch duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next epoch duration is 4 weeks
        assertEq(_nextDuration, 4 weeks);
        // THEN next epoch starts in 1 sec
        assertEq(_nextStart, block.timestamp + 1);

        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 1 week
        assertEq(_epochDuration, 1 weeks);
        // THEN epoch started 1 week ago
        assertEq(_epochStart, block.timestamp - 1 weeks + 1);

        // AND epoch finishes
        _skipAndStartNewEpoch();

        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 4 weeks
        assertEq(_epochDuration, 4 weeks);
        // THEN epoch starts now
        assertEq(_epochStart, block.timestamp);
    }

    /**
     * SCENARIO: governor sets a new longer epoch duration
     */
    function test_SetEpochDurationLonger() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a new epoch duration of 3 weeks
        vm.prank(governor);
        sponsorsManager.setEpochDuration(3 weeks, 0 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 3 weeks
        assertEq(_epochDuration, 3 weeks);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN epochs start time is 3 weeks ago
        assertEq(_epochStart, block.timestamp - 3 weeks);
        // THEN epoch starts now
        assertEq(sponsorsManager.epochStart(block.timestamp), block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 3 weeks
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 3 weeks);

        // THEN period finish in 3 weeks
        assertEq(sponsorsManager.periodFinish(), block.timestamp + 3 weeks);
        // THEN totalPotentialReward is 16 * 3 weeks
        assertEq(sponsorsManager.totalPotentialReward(), 16 ether * 3 weeks);
        // THEN gauge rewardRate in rewardToken is 6.25 / 3 weeks; 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 6.25 ether / uint256(3 weeks));
        // THEN gauge rewardRate in coinbase is 0.625 / 3 weeks; 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0.625 ether / uint256(3 weeks));
        // THEN gauge2 rewardRate in rewardToken is 43.75 / 3 weeks; 43.75 = (100 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(address(rewardToken)) / 10 ** 18, 43.75 ether / uint256(3 weeks));
        // THEN gauge2 rewardRate in coinbase is 4.375 / 3 weeks; 4.375 = (10 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 4.375 ether / uint256(3 weeks));

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN gauge rewardPerToken in rewardToken is 9.375 = 6.25 * 3 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(address(rewardToken)), 9.375 ether, 100);
        // THEN gauge rewardPerToken in coinbase is 0.9375 = 0.625 * 3 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0.9375 ether, 100);
        // THEN gauge2 rewardPerToken in rewardToken is 9.375 = 43.75 * 3 distributions / 14 allocations
        assertApproxEqAbs(gauge2.rewardPerToken(address(rewardToken)), 9.375 ether, 100);
        // THEN gauge2 rewardPerToken in coinbase is 0.9375 = 4.375 * 3 distributions / 14 allocations
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
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a new epoch duration of 0.5 weeks
        vm.prank(governor);
        sponsorsManager.setEpochDuration(0.5 weeks, 0 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN epoch duration is 0.5 week
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        assertEq(_epochDuration, 0.5 weeks);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN epochs start time is 0.5 weeks ago
        assertEq(_epochStart, block.timestamp - 0.5 weeks);
        // THEN epoch starts now
        assertEq(sponsorsManager.epochStart(block.timestamp), block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 0.5 weeks
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 0.5 weeks);

        // THEN period finish in 0.5 weeks
        assertEq(sponsorsManager.periodFinish(), block.timestamp + 0.5 weeks);
        // THEN totalPotentialReward is 16 * 0.5 weeks
        assertEq(sponsorsManager.totalPotentialReward(), 16 ether * 0.5 weeks);
        // THEN gauge rewardRate in rewardToken is 6.25 / 0.5 weeks; 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 6.25 ether / uint256(0.5 weeks));
        // THEN gauge rewardRate in coinbase is 0.625 / 0.5 weeks; 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0.625 ether / uint256(0.5 weeks));
        // THEN gauge2 rewardRate in rewardToken is 43.75 / 0.5 weeks; 43.75 = (100 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(address(rewardToken)) / 10 ** 18, 43.75 ether / uint256(0.5 weeks));
        // THEN gauge2 rewardRate in coinbase is 4.375 / 0.5 weeks; 4.375 = (10 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 4.375 ether / uint256(0.5 weeks));

        // AND epoch finishes
        _skipAndStartNewEpoch();
        // THEN gauge rewardPerToken in rewardToken is 9.375 = 6.25 * 3 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(address(rewardToken)), 9.375 ether, 100);
        // THEN gauge rewardPerToken in coinbase is 0.9375 = 0.625 * 3 distributions / 2 allocations
        assertApproxEqAbs(gauge.rewardPerToken(UtilsLib._COINBASE_ADDRESS), 0.9375 ether, 100);
        // THEN gauge2 rewardPerToken in rewardToken is 9.375 = 43.75 * 3 distributions / 14 allocations
        assertApproxEqAbs(gauge2.rewardPerToken(address(rewardToken)), 9.375 ether, 100);
        // THEN gauge2 rewardPerToken in coinbase is 0.9375 = 4.375 * 3 distributions / 14 allocations
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
     * SCENARIO: governor sets same epoch duration with an offset to move the epoch date
     */
    function test_SameEpochDurationWithOffset() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a same epoch duration of 1 weeks adding an offset of 3 days
        vm.prank(governor);
        sponsorsManager.setEpochDuration(1 weeks, 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 1 week + 3 days
        assertEq(_epochDuration, 1 weeks + 3 days);
        // THEN epochs start time is now
        assertEq(_epochStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 1 week + 3 days
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1 weeks + 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 1 week
        assertEq(_epochDuration, 1 weeks);
        // THEN epochs start time is 1 week ago
        assertEq(_epochStart, block.timestamp - 1 weeks);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 1 week
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1 weeks);

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
     * SCENARIO: governor sets a longer epoch duration with an offset to move the epoch date
     */
    function test_LongerEpochDurationWithOffset() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a longer epoch duration of 1.5 weeks adding an offset of 3 days
        vm.prank(governor);
        sponsorsManager.setEpochDuration(1.5 weeks, 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 1.5 week + 3 days
        assertEq(_epochDuration, 1.5 weeks + 3 days);
        // THEN epochs start time is now
        assertEq(_epochStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 1.5 week + 3 days
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1.5 weeks + 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 1.5 week
        assertEq(_epochDuration, 1.5 weeks);
        // THEN epochs start time is 1.5 week ago
        assertEq(_epochStart, block.timestamp - 1.5 weeks);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 1.5 week
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 1.5 weeks);

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
     * SCENARIO: governor sets a shorter epoch duration with an offset to move the epoch date
     */
    function test_ShorterEpochDurationWithOffset() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a shorter epoch duration of 0.75 weeks adding an offset of 3 days
        vm.prank(governor);
        sponsorsManager.setEpochDuration(0.75 weeks, 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _epochStart, uint256 _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 0.75 week + 3 days
        assertEq(_epochDuration, 0.75 weeks + 3 days);
        // THEN epochs start time is now
        assertEq(_epochStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 0.75 week + 3 days
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 0.75 weeks + 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (_epochStart, _epochDuration) = sponsorsManager.getEpochStartAndDuration();
        // THEN epoch duration is 0.75 week
        assertEq(_epochDuration, 0.75 weeks);
        // THEN epochs start time is 0.75 week ago
        assertEq(_epochStart, block.timestamp - 0.75 weeks);
        // THEN distribution window ends in 1 hour
        assertEq(sponsorsManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next epoch is in 0.75 week
        assertEq(sponsorsManager.epochNext(block.timestamp), block.timestamp + 0.75 weeks);

        // AND epoch finishes
        _skipAndStartNewEpoch();

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
}
