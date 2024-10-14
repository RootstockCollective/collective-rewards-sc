# UtilsLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/f31d9f8f5bef186e32eda9f657a30ca570e27d59/src/libraries/UtilsLib.sol)

## State Variables

### \_PRECISION

```solidity
uint256 internal constant _PRECISION = 10 ** 18;
```

### \_COINBASE_ADDRESS

```solidity
address internal constant _COINBASE_ADDRESS = address(uint160(uint256(keccak256("COINBASE_ADDRESS"))));
```

## Functions

### \_uncheckedInc

```solidity
function _uncheckedInc(uint256 i_) internal pure returns (uint256);
```

### \_divPrec

add precision and div two number

```solidity
function _divPrec(uint256 a_, uint256 b_) internal pure returns (uint256);
```

**Parameters**

| Name | Type      | Description |
| ---- | --------- | ----------- |
| `a_` | `uint256` | numerator   |
| `b_` | `uint256` | denominator |

**Returns**

| Name     | Type      | Description              |
| -------- | --------- | ------------------------ |
| `<none>` | `uint256` | `a_` \* PRECISION / `b_` |

### \_mulPrec

multiply two number and remove precision

```solidity
function _mulPrec(uint256 a_, uint256 b_) internal pure returns (uint256);
```

**Parameters**

| Name | Type      | Description |
| ---- | --------- | ----------- |
| `a_` | `uint256` | term 1      |
| `b_` | `uint256` | term 2      |

**Returns**

| Name     | Type      | Description              |
| -------- | --------- | ------------------------ |
| `<none>` | `uint256` | `a_` \* `b_` / PRECISION |

### \_calcEpochNext

calculates when an epoch ends or the next one starts based on given `epochDuration_` and a `timestamp_`

```solidity
function _calcEpochNext(
    uint256 epochStart_,
    uint256 epochDuration_,
    uint256 timestamp_
)
    internal
    pure
    returns (uint256);
```

**Parameters**

| Name             | Type      | Description            |
| ---------------- | --------- | ---------------------- |
| `epochStart_`    | `uint256` | epoch start timestamp  |
| `epochDuration_` | `uint256` | epoch time duration    |
| `timestamp_`     | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                                |
| -------- | --------- | ---------------------------------------------------------- |
| `<none>` | `uint256` | epochNext timestamp when the epoch ends or the next starts |

### \_calcTimeUntilNextEpoch

calculates the time left until the next epoch based on given `epochDuration_` and a `timestamp_`

```solidity
function _calcTimeUntilNextEpoch(
    uint256 epochStart_,
    uint256 epochDuration_,
    uint256 timestamp_
)
    internal
    pure
    returns (uint256);
```

**Parameters**

| Name             | Type      | Description            |
| ---------------- | --------- | ---------------------- |
| `epochStart_`    | `uint256` | epoch start timestamp  |
| `epochDuration_` | `uint256` | epoch time duration    |
| `timestamp_`     | `uint256` | timestamp to calculate |

**Returns**

| Name     | Type      | Description                                        |
| -------- | --------- | -------------------------------------------------- |
| `<none>` | `uint256` | timeUntilNextEpoch amount of time until next epoch |
