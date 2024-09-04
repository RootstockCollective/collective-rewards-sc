# ISponsorsManager

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/ec30259df8f8351920ffc4dcdd060e5148bf247b/src/interfaces/ISponsorsManager.sol)

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
