# UtilsLib

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/26cede3bca1fa205726e5fbfc42ce638e32ad00b/src/libraries/UtilsLib.sol)

## State Variables

### PRECISION

```solidity
uint256 internal constant PRECISION = 10 ** 18;
```

### BPS_PRECISION

```solidity
uint256 internal constant BPS_PRECISION = 10_000;
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

### \_calculatePercentage

percentage using bps

```solidity
function _calculatePercentage(uint256 amount_, uint256 bps_) internal pure returns (uint256);
```

**Parameters**

| Name      | Type      | Description |
| --------- | --------- | ----------- |
| `amount_` | `uint256` | amount      |
| `bps_`    | `uint256` | bps         |

**Returns**

| Name     | Type      | Description                         |
| -------- | --------- | ----------------------------------- |
| `<none>` | `uint256` | `amount_` \* `bps_` / BPS_PRECISION |
