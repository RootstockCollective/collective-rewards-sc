# GaugeFactory

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/18fb4163e2334fa840a31f7eb0b1dcc3445e44ef/src/gauge/GaugeFactory.sol)

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
