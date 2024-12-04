# CommunityApproveBuilderChangerTemplateRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/6d0eca4e2c61e833bcb70c54d8668e5644ba180e/src/governance/changerTemplates/CommunityApproveBuilderChangerTemplateRootstockCollective.sol)

**Inherits:**
[IChangeContractRootstockCollective](/src/interfaces/IChangeContractRootstockCollective.sol/interface.IChangeContractRootstockCollective.md)

ChangeContract used to community approve a builder and create its Gauger contract

## State Variables

### backersManager

BackersManagerRootstockCollective contract address

```solidity
BackersManagerRootstockCollective public immutable backersManager;
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
constructor(BackersManagerRootstockCollective backersManager_, address builder_);
```

**Parameters**

| Name              | Type                                | Description                           |
| ----------------- | ----------------------------------- | ------------------------------------- |
| `backersManager_` | `BackersManagerRootstockCollective` | Address of the BackersManger contract |
| `builder_`        | `address`                           | Address of the builder                |

### execute

Execute the changes.

_Should be called by the governor, but this contract does not check that explicitly because it is not its responsibility
in the current architecture_

```solidity
function execute() external;
```
