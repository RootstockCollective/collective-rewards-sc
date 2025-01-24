// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { BaseHandler, TimeManager } from "./BaseHandler.sol";
import { BaseTest } from "../../BaseTest.sol";

contract BuilderHandler is BaseHandler {
    constructor(BaseTest baseTest_, TimeManager timeManager_) BaseHandler(baseTest_, timeManager_) { }

    function revokeBuilder(uint256 builderIndex_, uint256 timeToSkip_) external skipTime(timeToSkip_) {
        builderIndex_ = bound(builderIndex_, 0, baseTest.buildersArrayLength() - 1);
        address _builder = baseTest.builders(builderIndex_);
        (, bool _kycApproved, bool _communityApproved,, bool _revoked,,) = builderRegistry.builderState(_builder);
        if (_kycApproved && _communityApproved && !_revoked) {
            vm.prank(_builder);
            builderRegistry.revokeBuilder();
        }
    }

    function permitBuilder(uint256 builderIndex_, uint256 timeToSkip_) external skipTime(timeToSkip_) {
        if (block.timestamp >= backersManager.periodFinish()) return;
        builderIndex_ = bound(builderIndex_, 0, baseTest.buildersArrayLength() - 1);
        address _builder = baseTest.builders(builderIndex_);
        (, bool _kycApproved, bool _communityApproved,, bool _revoked,,) = builderRegistry.builderState(_builder);
        if (_kycApproved && _communityApproved && _revoked) {
            vm.prank(_builder);
            builderRegistry.permitBuilder(0.4 ether);
        }
    }
}
