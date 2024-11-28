// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { BaseTest } from "./BaseTest.sol";
import { CycleTimeKeeperRootstockCollective } from "../src/CycleTimeKeeperRootstockCollective.sol";
import { UtilsLib } from "../src/libraries/UtilsLib.sol";

contract SetCycleDurationTest is BaseTest {
    // -----------------------------
    // ----------- Events ----------
    // -----------------------------
    event NewCycleDurationScheduled(uint256 newCycleDuration_, uint256 cooldownEndTime_);

    function _setUp() internal override {
        // mint some rewardTokens to this contract for reward distribution
        rewardToken.mint(address(this), 100_000 ether);
        rewardToken.approve(address(backersManager), 100_000 ether);
    }

    function _initialState() internal {
        // GIVEN alice allocates to builder and builder2
        vm.startPrank(alice);
        allocationsArray[0] = 2 ether;
        allocationsArray[1] = 6 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
        // AND bob allocates to builder2
        vm.startPrank(bob);
        allocationsArray[0] = 0 ether;
        allocationsArray[1] = 8 ether;
        backersManager.allocateBatch(gaugesArray, allocationsArray);
        vm.stopPrank();
    }

    /**
     * SCENARIO: Only valid changer or foundation can set a new cycle duration
     */
    function test_OnlyValidChangerOrFoundation() public {
        // GIVEN a backer alice
        //  WHEN alice calls setCycleDuration
        //   THEN tx reverts because caller is not the Governor

        vm.prank(alice);
        vm.expectRevert(CycleTimeKeeperRootstockCollective.NotValidChangerOrFoundation.selector);
        backersManager.setCycleDuration(3 weeks, 0 days);

        // GIVEN accounts with permissions to change the cycle duration
        //  WHEN authorized account calls setCycleDuration
        //   THEN NewCycleDurationScheduled event is emitted
        vm.prank(foundation);
        backersManager.setCycleDuration(3 weeks, 0 days);
        vm.prank(governor);
        backersManager.setCycleDuration(2 weeks, 0 days);
    }

    /**
     * SCENARIO: setCycleDuration reverts if the new duration is shorter than 2 times the distribution window
     */
    function test_RevertCycleDurationTooShort() public {
        // GIVEN a distribution window of 1 hour
        //  WHEN governor tries to set a cycle duration smaller than 2 times the distribution duration
        //   THEN tx reverts because is too short
        vm.prank(governor);
        vm.expectRevert(CycleTimeKeeperRootstockCollective.CycleDurationTooShort.selector);
        backersManager.setCycleDuration(distributionDuration, 0 days);
    }

    /**
     * SCENARIO: governor sets a new cycle duration
     */
    function test_SetCycleDuration() public {
        // GIVEN a governor
        //  WHEN calls setCycleDuration
        //   THEN NewCycleDurationScheduled event is emitted
        (uint32 _previousDuration, uint32 _nextDuration, uint64 _previousStart, uint64 _nextStart,) =
            backersManager.cycleData();
        uint256 _nextCycle = UtilsLib._calcCycleNext(_previousStart, 1 weeks, block.timestamp);
        vm.prank(governor);
        vm.expectEmit();
        emit NewCycleDurationScheduled(3 weeks, _nextCycle);
        backersManager.setCycleDuration(3 weeks, 0 days);

        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = backersManager.cycleData();
        // THEN previous cycle duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next cycle duration is 3 weeks
        assertEq(_nextDuration, 3 weeks);
        // THEN previous cycle starts is now
        assertEq(_previousStart, block.timestamp);
        // THEN next cycle starts in 1 weeks from now
        assertEq(_nextStart, block.timestamp + 1 weeks);

        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle start is now
        assertEq(_cycleStart, block.timestamp);
        // THEN cycle duration is 1 week
        assertEq(_cycleDuration, 1 weeks);
        // THEN cycle finishes in 1 week
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1 weeks);

        // AND cycle finishes
        _skipAndStartNewCycle();
        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = backersManager.cycleData();
        // THEN previous cycle duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next cycle duration is 3 weeks
        assertEq(_nextDuration, 3 weeks);
        // THEN previous cycle starts is 1 weeks ago
        assertEq(_previousStart, block.timestamp - 1 weeks);
        // THEN next cycle starts is now
        assertEq(_nextStart, block.timestamp);

        // AND governor sets a new cycle duration of 6 weeks
        vm.prank(governor);
        backersManager.setCycleDuration(6 weeks, 0 days);
        (_previousDuration, _nextDuration, _previousStart, _nextStart,) = backersManager.cycleData();
        // THEN previous cycle duration is 3 week
        assertEq(_previousDuration, 3 weeks);
        // THEN next cycle duration is 6 weeks
        assertEq(_nextDuration, 6 weeks);
        // THEN previous cycle starts is now
        assertEq(_previousStart, block.timestamp);
        // THEN next cycle starts in 3 weeks from now
        assertEq(_nextStart, block.timestamp + 3 weeks);

        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle start is now
        assertEq(_cycleStart, block.timestamp);
        // THEN cycle duration is 3 week
        assertEq(_cycleDuration, 3 weeks);
        // THEN cycle finishes in 3 week
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 3 weeks);
    }

    /**
     * SCENARIO: governor sets a new cycle duration with the same value
     */
    function test_SetCycleDurationSameValue() public {
        // GIVEN an cycle duration of 1 week
        //  WHEN calls setCycleDuration again with 1 week
        vm.prank(governor);
        backersManager.setCycleDuration(1 weeks, 0 days);

        (uint32 _previousDuration, uint32 _nextDuration,,,) = backersManager.cycleData();
        // THEN previous and next cycle durations are the same
        assertEq(_previousDuration, _nextDuration);
    }

    /**
     * SCENARIO: governor sets a new cycle duration again before the current cycle finishes and the second one is
     * applied
     */
    function test_SetCycleDurationTwiceBeforeCooldown() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND governor sets a new cycle duration of 3 weeks
        vm.prank(governor);
        backersManager.setCycleDuration(3 weeks, 0 days);

        (uint32 _previousDuration, uint32 _nextDuration,, uint64 _nextStart,) = backersManager.cycleData();
        // AND cycle didn't finish, 1 sec is remaining
        vm.warp(block.timestamp + 1 weeks - 1);

        // AND governor sets a new cycle duration of 4 weeks
        vm.prank(governor);
        backersManager.setCycleDuration(4 weeks, 0 days);
        (_previousDuration, _nextDuration,, _nextStart,) = backersManager.cycleData();
        // THEN previous cycle duration is 1 week
        assertEq(_previousDuration, 1 weeks);
        // THEN next cycle duration is 4 weeks
        assertEq(_nextDuration, 4 weeks);
        // THEN next cycle starts in 1 sec
        assertEq(_nextStart, block.timestamp + 1);

        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 1 week
        assertEq(_cycleDuration, 1 weeks);
        // THEN cycle started 1 week ago
        assertEq(_cycleStart, block.timestamp - 1 weeks + 1);

        // AND cycle finishes
        _skipAndStartNewCycle();

        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 4 weeks
        assertEq(_cycleDuration, 4 weeks);
        // THEN cycle starts now
        assertEq(_cycleStart, block.timestamp);
    }

    /**
     * SCENARIO: governor sets a new longer cycle duration
     */
    function test_SetCycleDurationLonger() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a new cycle duration of 3 weeks
        vm.prank(governor);
        backersManager.setCycleDuration(3 weeks, 0 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 3 weeks
        assertEq(_cycleDuration, 3 weeks);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN cycles start time is 3 weeks ago
        assertEq(_cycleStart, block.timestamp - 3 weeks);
        // THEN cycle starts now
        assertEq(backersManager.cycleStart(block.timestamp), block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 3 weeks
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 3 weeks);

        // THEN period finish in 3 weeks
        assertEq(backersManager.periodFinish(), block.timestamp + 3 weeks);
        // THEN totalPotentialReward is 16 * 3 weeks
        assertEq(backersManager.totalPotentialReward(), 16 ether * 3 weeks);
        // THEN gauge rewardRate in rewardToken is 6.25 / 3 weeks; 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 6.25 ether / uint256(3 weeks));
        // THEN gauge rewardRate in coinbase is 0.625 / 3 weeks; 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0.625 ether / uint256(3 weeks));
        // THEN gauge2 rewardRate in rewardToken is 43.75 / 3 weeks; 43.75 = (100 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(address(rewardToken)) / 10 ** 18, 43.75 ether / uint256(3 weeks));
        // THEN gauge2 rewardRate in coinbase is 4.375 / 3 weeks; 4.375 = (10 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 4.375 ether / uint256(3 weeks));

        // AND cycle finishes
        _skipAndStartNewCycle();
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
        gauge.claimBackerReward(alice);
        // THEN alice receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 18.75 ether, 100);
        // THEN alice receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1.875 ether, 100);
    }

    /**
     * SCENARIO: governor sets a new shorter cycle duration
     */
    function test_SetCycleDurationShorter() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a new cycle duration of 0.5 weeks
        vm.prank(governor);
        backersManager.setCycleDuration(0.5 weeks, 0 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // THEN cycle duration is 0.5 week
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        assertEq(_cycleDuration, 0.5 weeks);
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);

        // THEN cycles start time is 0.5 weeks ago
        assertEq(_cycleStart, block.timestamp - 0.5 weeks);
        // THEN cycle starts now
        assertEq(backersManager.cycleStart(block.timestamp), block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 0.5 weeks
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 0.5 weeks);

        // THEN period finish in 0.5 weeks
        assertEq(backersManager.periodFinish(), block.timestamp + 0.5 weeks);
        // THEN totalPotentialReward is 16 * 0.5 weeks
        assertEq(backersManager.totalPotentialReward(), 16 ether * 0.5 weeks);
        // THEN gauge rewardRate in rewardToken is 6.25 / 0.5 weeks; 6.25 = (100 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(address(rewardToken)) / 10 ** 18, 6.25 ether / uint256(0.5 weeks));
        // THEN gauge rewardRate in coinbase is 0.625 / 0.5 weeks; 0.625 = (10 * 2 / 16) * 0.5
        assertEq(gauge.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 0.625 ether / uint256(0.5 weeks));
        // THEN gauge2 rewardRate in rewardToken is 43.75 / 0.5 weeks; 43.75 = (100 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(address(rewardToken)) / 10 ** 18, 43.75 ether / uint256(0.5 weeks));
        // THEN gauge2 rewardRate in coinbase is 4.375 / 0.5 weeks; 4.375 = (10 * 14 / 16) * 0.5
        assertEq(gauge2.rewardRate(UtilsLib._COINBASE_ADDRESS) / 10 ** 18, 4.375 ether / uint256(0.5 weeks));

        // AND cycle finishes
        _skipAndStartNewCycle();
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
        gauge.claimBackerReward(alice);
        // THEN alice receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 18.75 ether, 100);
        // THEN alice receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1.875 ether, 100);
    }

    /**
     * SCENARIO: governor sets same cycle duration with an offset to move the cycle date
     */
    function test_SameCycleDurationWithOffset() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a same cycle duration of 1 weeks adding an offset of 3 days
        vm.prank(governor);
        backersManager.setCycleDuration(1 weeks, 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 1 week + 3 days
        assertEq(_cycleDuration, 1 weeks + 3 days);
        // THEN cycles start time is now
        assertEq(_cycleStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 1 week + 3 days
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1 weeks + 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 1 week
        assertEq(_cycleDuration, 1 weeks);
        // THEN cycles start time is 1 week ago
        assertEq(_cycleStart, block.timestamp - 1 weeks);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 1 week
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1 weeks);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertEq(_clearERC20Balance(builder), 18.75 ether);
        // THEN builder receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertEq(_clearCoinbaseBalance(builder), 1.875 ether);

        // WHEN alice claims the rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 18.75 ether, 100);
        // THEN alice receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1.875 ether, 100);
    }

    /**
     * SCENARIO: governor sets a longer cycle duration with an offset to move the cycle date
     */
    function test_LongerCycleDurationWithOffset() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a longer cycle duration of 1.5 weeks adding an offset of 3 days
        vm.prank(governor);
        backersManager.setCycleDuration(1.5 weeks, 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 1.5 week + 3 days
        assertEq(_cycleDuration, 1.5 weeks + 3 days);
        // THEN cycles start time is now
        assertEq(_cycleStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 1.5 week + 3 days
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1.5 weeks + 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 1.5 week
        assertEq(_cycleDuration, 1.5 weeks);
        // THEN cycles start time is 1.5 week ago
        assertEq(_cycleStart, block.timestamp - 1.5 weeks);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 1.5 week
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 1.5 weeks);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertEq(_clearERC20Balance(builder), 18.75 ether);
        // THEN builder receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertEq(_clearCoinbaseBalance(builder), 1.875 ether);

        // WHEN alice claims the rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 18.75 ether, 100);
        // THEN alice receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1.875 ether, 100);
    }

    /**
     * SCENARIO: governor sets a shorter cycle duration with an offset to move the cycle date
     */
    function test_ShorterCycleDurationWithOffset() public {
        // GIVEN alice and bob allocate to builder and builder2
        _initialState();
        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        // AND governor sets a shorter cycle duration of 0.75 weeks adding an offset of 3 days
        vm.prank(governor);
        backersManager.setCycleDuration(0.75 weeks, 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 0.75 week + 3 days
        assertEq(_cycleDuration, 0.75 weeks + 3 days);
        // THEN cycles start time is now
        assertEq(_cycleStart, block.timestamp);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 0.75 week + 3 days
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 0.75 weeks + 3 days);

        // AND 100 rewardToken and 10 coinbase are distributed
        _distribute(100 ether, 10 ether);
        (_cycleStart, _cycleDuration) = backersManager.getCycleStartAndDuration();
        // THEN cycle duration is 0.75 week
        assertEq(_cycleDuration, 0.75 weeks);
        // THEN cycles start time is 0.75 week ago
        assertEq(_cycleStart, block.timestamp - 0.75 weeks);
        // THEN distribution window ends in 1 hour
        assertEq(backersManager.endDistributionWindow(block.timestamp), block.timestamp + 1 hours);
        // THEN next cycle is in 0.75 week
        assertEq(backersManager.cycleNext(block.timestamp), block.timestamp + 0.75 weeks);

        // AND cycle finishes
        _skipAndStartNewCycle();

        // WHEN builder claim rewards
        _buildersClaim();
        // THEN builder receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertEq(_clearERC20Balance(builder), 18.75 ether);
        // THEN builder receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertEq(_clearCoinbaseBalance(builder), 1.875 ether);

        // WHEN alice claims the rewards
        vm.prank(alice);
        gauge.claimBackerReward(alice);
        // THEN alice receives 50% of rewardToken 18.75 = (300 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearERC20Balance(alice), 18.75 ether, 100);
        // THEN alice receives 50% of coinbase 1.875 = (30 * 2 / 16) * 0.5
        assertApproxEqAbs(_clearCoinbaseBalance(alice), 1.875 ether, 100);
    }

    function test_LongerDistributionDurationAfterCycleStart() public {
        uint32 _confCycleDuration = 1 weeks;
        uint24 _confCycleStartOffset = 1 weeks;
        vm.prank(governor);
        backersManager.setCycleDuration(_confCycleDuration, _confCycleStartOffset);

        _skipAndStartNewCycle();

        uint32 _newDistributionDuration = 1.5 weeks;
        vm.prank(foundation);
        vm.expectRevert(CycleTimeKeeperRootstockCollective.DistributionDurationTooLong.selector);
        backersManager.setDistributionDuration(_newDistributionDuration);

        //After the cycle starts the new duration and offset comes into place
        (, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        assertEq(_cycleDuration, _confCycleDuration + _confCycleStartOffset);
    }

    function test_LongerDistributionDurationBeforeCycleStart() public {
        uint32 _confCycleDuration = 1 weeks;
        uint24 _confCycleStartOffset = 1 weeks;

        (uint256 _previousCycleStart, uint256 _previousCycleDuration) = backersManager.getCycleStartAndDuration();

        vm.prank(governor);
        backersManager.setCycleDuration(_confCycleDuration, _confCycleStartOffset);

        (uint256 _cycleStart, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();

        //Since here we haven't started the cycle the new duration and offset are not applied
        assertEq(_previousCycleStart, _cycleStart);
        assertEq(_previousCycleDuration, _cycleDuration);

        uint32 _newDistributionDuration = 1.5 weeks;
        vm.prank(foundation);
        vm.expectRevert(CycleTimeKeeperRootstockCollective.DistributionDurationTooLong.selector);
        backersManager.setDistributionDuration(_newDistributionDuration);

        _skipAndStartNewCycle();

        //After the cycle starts the new duration and offset comes into place
        (, uint256 _newCycleDuration) = backersManager.getCycleStartAndDuration();
        assertEq(_newCycleDuration, _confCycleDuration + _confCycleStartOffset);
    }
}
