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
}
