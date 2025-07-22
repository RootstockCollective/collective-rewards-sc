# GaugeFactoryRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/b0132a87539388dafe86f79d095cab28f13e5989/src/gauge/GaugeFactoryRootstockCollective.sol)


## State Variables
### beacon
address of beacon contract who stores gauge implementation address which is where gauge proxies will
delegate all function calls


```solidity
address public immutable beacon;
```


### rifToken
address of the token rewarded to builder and voters


```solidity
address public immutable rifToken;
```


### usdrifToken
address of the token rewarded to builder and voters


```solidity
address public immutable usdrifToken;
```


## Functions
### constructor

constructor


```solidity
constructor(address beacon_, address rifToken_, address usdrifToken_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacon_`|`address`|address of the beacon|
|`rifToken_`|`address`|address of the token rewarded to builder and voters|
|`usdrifToken_`|`address`|address of the token rewarded to builder and voters|


### createGauge


```solidity
function createGauge() external returns (GaugeRootstockCollective gauge_);
```

