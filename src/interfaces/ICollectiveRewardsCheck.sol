// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/**
 * @title ICollectiveRewardsCheck
 *   @notice Used by stakingToken to validate if the staker can transfer its tokens
 */
interface ICollectiveRewardsCheck {
    function canWithdraw(address targetAddress_, uint256 value_) external view returns (bool);
}
