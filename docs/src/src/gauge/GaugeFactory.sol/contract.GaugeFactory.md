# GaugeFactory

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/b66d083f8b28b436755b9a1020cbe3fd028cd794/src/gauge/GaugeFactory.sol)

## State Variables

### rewardToken

address of the token rewarded to builder and voters

```solidity
address public rewardToken;
```

## Functions

### constructor

constructor

```solidity
constructor(address rewardToken_);
```

**Parameters**

| Name           | Type      | Description                                         |
| -------------- | --------- | --------------------------------------------------- |
| `rewardToken_` | `address` | address of the token rewarded to builder and voters |

### createGauge

```solidity
function createGauge() external returns (Gauge gauge_);
```
