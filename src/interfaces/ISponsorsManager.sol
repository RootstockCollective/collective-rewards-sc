// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/**
 * @title ISponsorsManager
 */
interface ISponsorsManager {
    /**
     * @notice returns timestamp end of current rewards period
     */
    function periodFinish() external view returns (uint256 timestamp_);

    /**
     * @notice returns builder address for a given gauge
     */
    function gaugeToBuilder(address gauge_) external view returns (address builder_);

    /**
     * @notice returns rewards receiver for a given builder
     */
    function builderRewardReceiver(address builder_) external view returns (address rewardReceiver_);

    /**
     * @notice return true if builder is operational
     */
    function isBuilderOperational(address builder_) external view returns (bool isOperational_);

    /**
     * @notice return true if gauge is halted
     */
    function isGaugeHalted(address gauge_) external view returns (bool isHalted_);

    /**
     * @notice gets time left until the next epoch based on given `timestamp_`
     */
    function timeUntilNextEpoch(uint256 timestamp_) external view returns (uint256 timeUntilNextEpoch_);
}
