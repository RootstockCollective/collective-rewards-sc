# EpochLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/5f35a21cd6c3981ceefbb9cb59cbab117642b659/src/libraries/EpochLib.sol)

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
