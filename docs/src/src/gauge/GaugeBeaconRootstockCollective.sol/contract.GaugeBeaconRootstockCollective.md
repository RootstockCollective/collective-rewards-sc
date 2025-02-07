# GaugeBeaconRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/99cb2d8ed5962fe0d1a12a5277c2e7b1068aeff8/src/gauge/GaugeBeaconRootstockCollective.sol)

**Inherits:**
UpgradeableBeacon


## State Variables
### governanceManager

```solidity
IGovernanceManagerRootstockCollective public governanceManager;
```


## Functions
### constructor

constructor


```solidity
constructor(
    IGovernanceManagerRootstockCollective governanceManager_,
    address gaugeImplementation_
)
    UpgradeableBeacon(gaugeImplementation_, governanceManager_.governor());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`governanceManager_`|`IGovernanceManagerRootstockCollective`|contract with permissioned roles|
|`gaugeImplementation_`|`address`|address of the Gauge initial implementation|


### _checkOwner

The owner is the governor but we need more flexibility to allow changes.

*We override _checkOwner so that OnlyOwner modifier uses governanceManager to authorize the caller*


```solidity
function _checkOwner() internal view override;
```

