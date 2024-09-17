# ISponsorsManager

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/896eaad6107040ce85d11fd7c0fd8135c40bab74/src/interfaces/ISponsorsManager.sol)

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
