# UtilsLib
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/b0132a87539388dafe86f79d095cab28f13e5989/src/libraries/UtilsLib.sol)


## State Variables
### _PRECISION

```solidity
uint256 internal constant _PRECISION = 10 ** 18;
```


### _NATIVE_ADDRESS

```solidity
address internal constant _NATIVE_ADDRESS = address(uint160(uint256(keccak256("NATIVE_ADDRESS"))));
```


### MIN_AMOUNT_INCENTIVES

```solidity
uint256 public constant MIN_AMOUNT_INCENTIVES = 100;
```


## Functions
### _uncheckedInc


```solidity
function _uncheckedInc(uint256 i_) internal pure returns (uint256);
```

### _divPrec

add precision and div two number


```solidity
function _divPrec(uint256 a_, uint256 b_) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a_`|`uint256`|numerator|
|`b_`|`uint256`|denominator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|`a_` * PRECISION / `b_`|


### _mulPrec

multiply two number and remove precision


```solidity
function _mulPrec(uint256 a_, uint256 b_) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a_`|`uint256`|term 1|
|`b_`|`uint256`|term 2|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|`a_` * `b_` / PRECISION|


### _calcCycleNext

calculates when an cycle ends or the next one starts based on given `cycleDuration_` and a `timestamp_`


```solidity
function _calcCycleNext(
    uint256 cycleStart_,
    uint256 cycleDuration_,
    uint256 timestamp_
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cycleStart_`|`uint256`|Collective Rewards cycle start timestamp|
|`cycleDuration_`|`uint256`|Collective Rewards cycle time duration|
|`timestamp_`|`uint256`|timestamp to calculate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|cycleNext timestamp when the cycle ends or the next starts|


### _calcTimeUntilNextCycle

calculates the time left until the next cycle based on given `cycleDuration_` and a `timestamp_`


```solidity
function _calcTimeUntilNextCycle(
    uint256 cycleStart_,
    uint256 cycleDuration_,
    uint256 timestamp_
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cycleStart_`|`uint256`|Collective Rewards cycle start timestamp|
|`cycleDuration_`|`uint256`|Collective Rewards cycle time duration|
|`timestamp_`|`uint256`|timestamp to calculate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|timeUntilNextCycle amount of time until next cycle|


