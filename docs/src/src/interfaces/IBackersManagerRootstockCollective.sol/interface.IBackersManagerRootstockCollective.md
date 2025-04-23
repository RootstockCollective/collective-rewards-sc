# IBackersManagerRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/d3eba7c5de1f4bd94fc8d9063bc035b452fb6c5d/src/interfaces/IBackersManagerRootstockCollective.sol)


## Functions
### periodFinish

returns timestamp end of current rewards period


```solidity
function periodFinish() external view returns (uint256 timestamp_);
```

### gaugeToBuilder

returns builder address for a given gauge


```solidity
function gaugeToBuilder(GaugeRootstockCollective gauge_) external view returns (address builder_);
```

### rewardReceiver

returns rewards receiver for a given builder


```solidity
function rewardReceiver(address builder_) external view returns (address rewardReceiver_);
```

### isRewardReceiverUpdatePending

returns true if the builder has an open request to update his receiver address


```solidity
function isRewardReceiverUpdatePending(address builder_) external view returns (bool);
```

### isBuilderPaused

return true if builder is paused


```solidity
function isBuilderPaused(address builder_) external view returns (bool isPaused_);
```

### isGaugeHalted

return true if gauge is halted


```solidity
function isGaugeHalted(address gauge_) external view returns (bool isHalted_);
```

### timeUntilNextCycle

gets time left until the next cycle based on given `timestamp_`


```solidity
function timeUntilNextCycle(uint256 timestamp_) external view returns (uint256 timeUntilNextCycle_);
```

