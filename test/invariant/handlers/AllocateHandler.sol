// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { StakingTokenMock } from "../../mock/StakingTokenMock.sol";
import { GaugeRootstockCollective } from "src/gauge/GaugeRootstockCollective.sol";

contract AllocateHandler is BaseHandler {
    StakingTokenMock public stakingToken;

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
        (GaugeRootstockCollective _gauge, uint256 _allocation) = _allocate(gaugeIndex_, allocation_);
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
