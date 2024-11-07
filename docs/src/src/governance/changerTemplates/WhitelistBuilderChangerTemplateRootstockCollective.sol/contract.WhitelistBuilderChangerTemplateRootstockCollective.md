# WhitelistBuilderChangerTemplateRootstockCollective

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/0c4368dc418c200f21d2a798619d1dd68234c5c1/src/governance/changerTemplates/WhitelistBuilderChangerTemplateRootstockCollective.sol)

**Inherits:**
[IChangeContractRootstockCollective](/src/interfaces/IChangeContractRootstockCollective.sol/interface.IChangeContractRootstockCollective.md)

ChangeContract used to whitelist a builder and create its Gauger contract

## State Variables

### backersManager

BackersManagerRootstockCollective contract address

```solidity
BackersManagerRootstockCollective public immutable backersManager;
```

### builder

builder address to be whitelisted

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
