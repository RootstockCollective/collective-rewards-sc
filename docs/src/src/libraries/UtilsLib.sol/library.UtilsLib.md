# UtilsLib

<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/d568903015f871eedd363a6c648861169e985892/src/libraries/UtilsLib.sol)
=======
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/d2969cf48df5747a801872ec11a9e5369ab00a1a/src/libraries/UtilsLib.sol)
>>>>>>> 570d7f7 (feat: builderRegistry)
=======
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/570d7f7acfcf922ef9eb9a54cef5dc11cb1bbfe3/src/libraries/UtilsLib.sol)
>>>>>>> 6f201f9 (refactor: pr comments)
=======
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/41e1b3d4d859d865d50082fa3927f5126e4e5e81/src/libraries/UtilsLib.sol)
>>>>>>> 5ba4509 (refactor: pr comments)
=======
[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/5ba4509a7ff07edd73e6644dc1737b81eed14f7a/src/libraries/UtilsLib.sol)
>>>>>>> 5ef60f6 (refactor: pr comments)

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
