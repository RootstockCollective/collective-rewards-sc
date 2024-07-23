# EpochLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/9e5650b8576ed38cbee2c0a3ec521c14bf14f352/src/libraries/EpochLib.sol)

## State Variables

### WEEK

```solidity
uint256 internal constant WEEK = 7 days;
```

## Functions

### epochStart

gets when an epoch starts based on given `timestamp_`

```solidity
function epochStart(uint256 timestamp_) internal pure returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `uint256` | epochStart timestamp when the epoch starts |

### epochNext

gets when an epoch ends or the next one starts based on given `timestamp_`

```solidity
function epochNext(uint256 timestamp_) internal pure returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                |
| -------- | --------- | ---------------------------------------------------------- |
| `<none>` | `uint256` | epochNext timestamp when the epoch ends or the next starts |

### endDistributionWindow

gets when an epoch distribution ends based on given `timestamp_`

```solidity
function endDistributionWindow(uint256 timestamp_) internal pure returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                      |
| -------- | --------- | ---------------------------------------------------------------- |
| `<none>` | `uint256` | endDistributionWindow timestamp when the epoch distribution ends |
