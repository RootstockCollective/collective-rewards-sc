# GaugeFactoryRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/0c4368dc418c200f21d2a798619d1dd68234c5c1/src/gauge/GaugeFactoryRootstockCollective.sol)

## State Variables

### beacon

address of beacon contract who stores gauge implementation address which is where gauge proxies will delegate all
function calls

```solidity
address public immutable beacon;
```

### rewardToken

address of the token rewarded to builder and voters

```solidity
address public immutable rewardToken;
```

## Functions

### constructor

constructor

```solidity
constructor(address beacon_, address rewardToken_);
```

**Parameters**

| Name           | Type      | Description                                         |
| -------------- | --------- | --------------------------------------------------- |
| `beacon_`      | `address` | address of the beacon                               |
| `rewardToken_` | `address` | address of the token rewarded to builder and voters |

### createGauge

```solidity
function createGauge() external returns (GaugeRootstockCollective gauge_);
```