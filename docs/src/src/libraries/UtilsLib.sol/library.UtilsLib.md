# UtilsLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/41c5c643e00ea37977046df1020b30b6d7bc2d18/src/libraries/UtilsLib.sol)

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
