// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

interface IGaugeFactory {
    function createGauge(address _stakingToken, address _rewardToken) external returns (address);
}
