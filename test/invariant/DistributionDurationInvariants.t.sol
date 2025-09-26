// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BaseInvariants, BaseTest } from "./BaseInvariants.sol";
import { DistributionDurationHandler } from "./handlers/DistributionDurationHandler.sol";

contract DistributionDurationInvariants is BaseInvariants {
    DistributionDurationHandler public ddHandler;

    function _setUp() internal override {
        super._setUp();
        ddHandler = new DistributionDurationHandler(BaseTest(payable(address(this))), timeManager);
        targetContract(address(ddHandler));
    }

    /**
     * SCENARIO: Cycle Duration should always be at least 2 times distribution duration
     * @dev: The test is allowed to revert, as we want setDistributionDuration to be as
     * un-restricted as possible
     */
    /// forge-config: default.invariant.fail-on-revert = false
    /// forge-config: ci.invariant.fail-on-revert = false
    /// forge-config: deep.invariant.fail-on-revert = false
    function invariant_DistributionDurationRatio() public useTime {
        (, uint256 _cycleDuration) = backersManager.getCycleStartAndDuration();
        uint32 _distributionDuration_ = backersManager.distributionDuration();
        assertGe(_cycleDuration, _distributionDuration_ * 2);
    }
}
