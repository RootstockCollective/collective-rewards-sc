# UtilsLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/38b1618c77e8418aee572d46a56dd13f602978fe/src/libraries/UtilsLib.sol)

## State Variables

### PRECISION

```solidity
uint256 internal constant PRECISION = 10 ** 18;
```

## Functions

### unchecked_inc

```solidity
function unchecked_inc(uint256 i_) internal pure returns (uint256);
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
