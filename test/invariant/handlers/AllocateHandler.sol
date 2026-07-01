// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { StakingTokenMock } from "../../mock/StakingTokenMock.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";

contract AllocateHandler is BaseHandler {
    StakingTokenMock public stakingToken;
    // In invariant runs we intentionally hit blocked-window paths and track outcomes.
    uint256 public blockedWindowAllocateAttempts;
    uint256 public blockedWindowAllocateReverts;
    uint256 public blockedWindowAllocateBatchAttempts;
    uint256 public blockedWindowAllocateBatchReverts;

    address[] public backers;
    mapping(address backer => bool exists) public backerExists;
    mapping(address backer => mapping(GaugeRootstockCollective gauge => uint256 allocation)) public
        backerGaugeAllocation;
    uint256 public backersLength;

    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) {
        stakingToken = baseTest_.stakingToken();
    }

    function allocate(uint256 gaugeIndex_, uint256 allocation_, uint256 timeToSkip_) external skipTime(timeToSkip_) {
        if (msg.sender.code.length != 0) return;
        gaugeIndex_ = bound(gaugeIndex_, 0, baseTest.gaugesArrayLength() - 1);
        GaugeRootstockCollective _gauge = baseTest.gaugesArray(gaugeIndex_);
        if (
            block.timestamp >= backersManager.periodFinish()
                && block.timestamp < backersManager.endDistributionWindow(block.timestamp)
        ) {
            blockedWindowAllocateAttempts++;
            // Use low-level call so expected reverts are observed without aborting the handler step.
            vm.prank(msg.sender);
            (bool _success,) = address(backersManager)
                .call(abi.encodeCall(backersManager.allocate, (_gauge, backerGaugeAllocation[msg.sender][_gauge])));
            if (!_success) blockedWindowAllocateReverts++;
            return;
        }
        (, uint256 _allocation) = _allocate(gaugeIndex_, allocation_);
        vm.prank(msg.sender);
        backersManager.allocate(_gauge, _allocation);
    }

    function allocateBatch(
        uint256[] calldata gaugesIndex_,
        uint256[] calldata allocations_,
        uint256 timeToSkip_
    )
        external
        skipTime(timeToSkip_)
    {
        if (msg.sender.code.length != 0) return;
        uint256 _gaugeIndex = gaugesIndex_.length == 0 ? 0 : bound(gaugesIndex_[0], 0, baseTest.gaugesArrayLength() - 1);
        GaugeRootstockCollective _firstGauge = baseTest.gaugesArray(_gaugeIndex);
        if (
            block.timestamp >= backersManager.periodFinish()
                && block.timestamp < backersManager.endDistributionWindow(block.timestamp)
        ) {
            blockedWindowAllocateBatchAttempts++;
            // Keep payload minimal; invariant only needs to verify blocked-window batch calls cannot succeed.
            GaugeRootstockCollective[] memory _gaugesBlocked = new GaugeRootstockCollective[](1);
            _gaugesBlocked[0] = _firstGauge;
            uint256[] memory _allocationsBlocked = new uint256[](1);
            _allocationsBlocked[0] = backerGaugeAllocation[msg.sender][_firstGauge];

            // Same low-level pattern as allocate(): record revert/success without stopping sequence.
            vm.prank(msg.sender);
            (bool _success,) = address(backersManager)
                .call(abi.encodeCall(backersManager.allocateBatch, (_gaugesBlocked, _allocationsBlocked)));
            if (!_success) blockedWindowAllocateBatchReverts++;
            return;
        }
        if (gaugesIndex_.length != allocations_.length) allocations_ = gaugesIndex_;
        GaugeRootstockCollective[] memory _gauges = new GaugeRootstockCollective[](gaugesIndex_.length);
        uint256[] memory _allocations = new uint256[](allocations_.length);
        for (uint256 i = 0; i < gaugesIndex_.length; i++) {
            (GaugeRootstockCollective _gauge, uint256 _allocation) = _allocate(gaugesIndex_[i], allocations_[i]);
            _gauges[i] = _gauge;
            _allocations[i] = _allocation;
        }

        vm.prank(msg.sender);
        backersManager.allocateBatch(_gauges, _allocations);
    }

    function _allocate(uint256 gaugeIndex_, uint256 allocation_) internal returns (GaugeRootstockCollective, uint256) {
        gaugeIndex_ = bound(gaugeIndex_, 0, baseTest.gaugesArrayLength() - 1);
        allocation_ = bound(allocation_, 0, type(uint64).max);

        GaugeRootstockCollective _gauge = baseTest.gaugesArray(gaugeIndex_);
        uint256 _allocationBefore = backerGaugeAllocation[msg.sender][_gauge];
        if (builderRegistry.isGaugeHalted(address(_gauge))) {
            if (allocation_ > _allocationBefore) {
                allocation_ = _allocationBefore;
            }
        }

        backerGaugeAllocation[msg.sender][_gauge] = allocation_;

        if (!backerExists[msg.sender]) {
            backers.push(msg.sender);
            backersLength = backers.length;
            backerExists[msg.sender] = true;
        }

        stakingToken.burn(msg.sender, _allocationBefore);
        stakingToken.mint(msg.sender, allocation_);
        return (_gauge, allocation_);
    }
}
