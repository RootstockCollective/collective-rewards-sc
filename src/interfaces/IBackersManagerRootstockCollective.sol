// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { GaugeRootstockCollective } from "../gauge/GaugeRootstockCollective.sol";

/**
 * @title IBackersManagerRootstockCollective
 */
interface IBackersManagerRootstockCollective {
    /**
     * @notice returns timestamp end of current rewards period
     */
    function periodFinish() external view returns (uint256 timestamp_);

    /**
     * @notice returns builder address for a given gauge
     */
    function gaugeToBuilder(GaugeRootstockCollective gauge_) external view returns (address builder_);

    /**
     * @notice returns rewards receiver for a given builder
     */
    function rewardReceiver(address builder_) external view returns (address rewardReceiver_);

    /**
     * @notice returns true if the builder has an open request to update his receiver address
     */
    function isRewardReceiverUpdatePending(address builder_) external view returns (bool);

    /**
     * @notice return true if builder is paused
     */
    function isBuilderPaused(address builder_) external view returns (bool isPaused_);

    /**
     * @notice return true if gauge is halted
     */
    function isGaugeHalted(address gauge_) external view returns (bool isHalted_);

    /**
     * @notice gets time left until the next cycle based on given `timestamp_`
     */
    function timeUntilNextCycle(uint256 timestamp_) external view returns (uint256 timeUntilNextCycle_);
}
