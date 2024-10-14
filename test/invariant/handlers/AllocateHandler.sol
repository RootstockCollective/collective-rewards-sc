// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";
import { ERC20Mock } from "test/mock/ERC20Mock.sol";
import { Gauge } from "src/gauge/Gauge.sol";

contract AllocateHandler is BaseHandler {
    ERC20Mock public stakingToken;

    address[] public sponsors;
    mapping(address sponsor => bool exists) public sponsorExists;
    mapping(address sponsor => mapping(Gauge gauge => uint256 allocation)) public sponsorGaugeAllocation;
    uint256 public sponsorsLength;

    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) {
        stakingToken = baseTest_.stakingToken();
    }

    function allocate(uint256 gaugeIndex_, uint256 allocation_, uint256 timeToSkip_) external skipTime(timeToSkip_) {
        if (msg.sender.code.length != 0) return;
        (Gauge _gauge, uint256 _allocation) = _allocate(gaugeIndex_, allocation_);
        vm.prank(msg.sender);
        sponsorsManager.allocate(_gauge, _allocation);
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
        Gauge[] memory _gauges = new Gauge[](gaugesIndex_.length);
        uint256[] memory _allocations = new uint256[](allocations_.length);
        for (uint256 i = 0; i < gaugesIndex_.length; i++) {
            (Gauge _gauge, uint256 _allocation) = _allocate(gaugesIndex_[i], allocations_[i]);
            _gauges[i] = _gauge;
            _allocations[i] = _allocation;
        }

        vm.prank(msg.sender);
        sponsorsManager.allocateBatch(_gauges, _allocations);
    }

    function _allocate(uint256 gaugeIndex_, uint256 allocation_) internal returns (Gauge, uint256) {
        gaugeIndex_ = bound(gaugeIndex_, 0, baseTest.gaugesArrayLength() - 1);
        allocation_ = bound(allocation_, 0, type(uint64).max);

        Gauge _gauge = baseTest.gaugesArray(gaugeIndex_);
        uint256 _allocationBefore = sponsorGaugeAllocation[msg.sender][_gauge];
        sponsorGaugeAllocation[msg.sender][_gauge] = allocation_;

        if (!sponsorExists[msg.sender]) {
            sponsors.push(msg.sender);
            sponsorsLength = sponsors.length;
            sponsorExists[msg.sender] = true;
        }

        stakingToken.burn(msg.sender, _allocationBefore);
        stakingToken.mint(msg.sender, allocation_);
        return (_gauge, allocation_);
    }
}
