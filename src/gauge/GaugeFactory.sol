// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Gauge } from "./Gauge.sol";

contract GaugeFactory {
    /// @notice address of the token rewarded to builder and voters
    address public rewardToken;

    /**
     * @notice constructor
     * @param rewardToken_ address of the token rewarded to builder and voters
     */
    constructor(address rewardToken_) {
        rewardToken = rewardToken_;
    }

    function createGauge() external returns (Gauge gauge_) {
        gauge_ = new Gauge(rewardToken, msg.sender);
    }
}
