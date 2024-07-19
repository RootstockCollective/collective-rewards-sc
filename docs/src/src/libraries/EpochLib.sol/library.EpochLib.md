# EpochLib

<<<<<<< HEAD
<<<<<<< HEAD
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/d568903015f871eedd363a6c648861169e985892/src/libraries/EpochLib.sol)
=======
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/d2969cf48df5747a801872ec11a9e5369ab00a1a/src/libraries/EpochLib.sol)
>>>>>>> 570d7f7 (feat: builderRegistry)
=======
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/570d7f7acfcf922ef9eb9a54cef5dc11cb1bbfe3/src/libraries/EpochLib.sol)
>>>>>>> 6f201f9 (refactor: pr comments)

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
