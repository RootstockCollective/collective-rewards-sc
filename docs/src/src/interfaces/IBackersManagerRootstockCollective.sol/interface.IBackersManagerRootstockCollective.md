# IBackersManagerRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/99cb2d8ed5962fe0d1a12a5277c2e7b1068aeff8/src/interfaces/IBackersManagerRootstockCollective.sol)


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

### builderRewardReceiver

returns rewards receiver for a given builder


```solidity
function builderRewardReceiver(address builder_) external view returns (address rewardReceiver_);
```

### hasBuilderRewardReceiverPendingApproval

returns true if the builder has an open request to replace his receiver address


```solidity
function hasBuilderRewardReceiverPendingApproval(address builder_) external view returns (bool);
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

