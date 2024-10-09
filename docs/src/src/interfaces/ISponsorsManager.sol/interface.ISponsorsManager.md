# ISponsorsManager

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/4bde84b8672a43d13ec4c8489206c5b3941b2d60/src/interfaces/ISponsorsManager.sol)

## Functions

### periodFinish

returns timestamp end of current rewards period

```solidity
function periodFinish() external view returns (uint256 timestamp_);
```

### gaugeToBuilder

returns builder address for a given gauge

```solidity
function gaugeToBuilder(address gauge_) external view returns (address builder_);
```

### builderRewardReceiver

returns rewards receiver for a given builder

```solidity
function builderRewardReceiver(address builder_) external view returns (address rewardReceiver_);
```

### isBuilderOperational

return true if builder is operational

```solidity
function isBuilderOperational(address builder_) external view returns (bool isOperational_);
```

### isGaugeHalted

return true if gauge is halted

```solidity
function isGaugeHalted(address gauge_) external view returns (bool isHalted_);
```

### timeUntilNextEpoch

gets time left until the next epoch based on given `timestamp_`

```solidity
function timeUntilNextEpoch(uint256 timestamp_) external view returns (uint256 timeUntilNextEpoch_);
```
