# SponsorsManager

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/14cb3d6c0a3b4e9b40a07d5427da7713e285f5ef/src/SponsorsManager.sol)

## State Variables

### rewardToken

```solidity
IERC20 public immutable rewardToken;
```

### gaugeFactory

```solidity
GaugeFactory public immutable gaugeFactory;
```

## Functions

### constructor

```solidity
constructor(address rewardToken_, address gaugeFactory_);
```

### createGauge

```solidity
function createGauge() external returns (address);
```
