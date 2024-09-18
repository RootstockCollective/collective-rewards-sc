# EpochLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/6aef6a8f9d7ab7f0c9567c171bff92d4308d9ae5/src/libraries/EpochLib.sol)

## State Variables

### \_WEEK

```solidity
uint256 internal constant _WEEK = 7 days;
```

## Functions

### \_epochStart

gets when an epoch starts based on given `timestamp_`

```solidity
function _epochStart(uint256 timestamp_) internal pure returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                |
| -------- | --------- | ------------------------------------------ |
| `<none>` | `uint256` | epochStart timestamp when the epoch starts |

### \_epochNext

gets when an epoch ends or the next one starts based on given `timestamp_`

```solidity
function _epochNext(uint256 timestamp_) internal pure returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                |
| -------- | --------- | ---------------------------------------------------------- |
| `<none>` | `uint256` | epochNext timestamp when the epoch ends or the next starts |

### \_endDistributionWindow

gets when an epoch distribution ends based on given `timestamp_`

```solidity
function _endDistributionWindow(uint256 timestamp_) internal pure returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                      |
| -------- | --------- | ---------------------------------------------------------------- |
| `<none>` | `uint256` | endDistributionWindow timestamp when the epoch distribution ends |
