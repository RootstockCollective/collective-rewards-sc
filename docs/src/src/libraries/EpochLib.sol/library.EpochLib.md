# EpochLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/14cb3d6c0a3b4e9b40a07d5427da7713e285f5ef/src/libraries/EpochLib.sol)

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

### epochEnd

gets when an epoch ends based on given `timestamp_`

```solidity
function epochEnd(uint256 timestamp_) internal pure returns (uint256);
```

**Parameters**

| Name         | Type      | Description            |
| ------------ | --------- | ---------------------- |
| `timestamp_` | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                              |
| -------- | --------- | ---------------------------------------- |
| `<none>` | `uint256` | epochStart timestamp when the epoch ends |

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
