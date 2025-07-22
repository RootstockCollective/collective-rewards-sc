# CommunityApproveBuilderChangerTemplateRootstockCollective
[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/f946f53322702b68bdb68a4c01ed6360683360e6/src/governance/changerTemplates/CommunityApproveBuilderChangerTemplateRootstockCollective.sol)

**Inherits:**
[IChangeContractRootstockCollective](/src/interfaces/IChangeContractRootstockCollective.sol/interface.IChangeContractRootstockCollective.md)

ChangeContract used to community approve a builder and create its Gauger contract


## State Variables
### builderRegistry
BuilderRegistryRootstockCollective contract address


```solidity
BuilderRegistryRootstockCollective public immutable builderRegistry;
```


### builder
builder address to be community approved


```solidity
address public immutable builder;
```


### newGauge
new Gauge created;


```solidity
GaugeRootstockCollective public newGauge;
```


## Functions
### constructor

Constructor


```solidity
constructor(BuilderRegistryRootstockCollective builderRegistry_, address builder_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`builderRegistry_`|`BuilderRegistryRootstockCollective`|Address of the BackersManger contract|
|`builder_`|`address`|Address of the builder|


### execute

Execute the changes.

*Should be called by the governor, but this contract does not check that explicitly
because it is not its responsibility in the current architecture*


```solidity
function execute() external;
```

