# WhitelistBuilderChangerTemplate

[Git Source](https://github.com/RootstockCollective/collective-rewards-sc/blob/14b7e2ea53e1a8ed6cfeed541bfbce82f4af7661/src/governance/changerTemplates/WhitelistBuilderChangerTemplate.sol)

**Inherits:**
[IChangeContractRootstockCollective](/src/interfaces/IChangeContractRootstockCollective.sol/interface.IChangeContractRootstockCollective.md)

ChangeContract used to whitelist a builder and create its Gauger contract

## State Variables

### sponsorsManager

SponsorsManager contract address

```solidity
SponsorsManager public immutable sponsorsManager;
```

### builder

builder address to be whitelisted

```solidity
address public immutable builder;
```

### newGauge

new Gauge created;

```solidity
Gauge public newGauge;
```

## Functions

### constructor

Constructor

```solidity
constructor(SponsorsManager sponsorsManager_, address builder_);
```

**Parameters**

| Name               | Type              | Description                            |
| ------------------ | ----------------- | -------------------------------------- |
| `sponsorsManager_` | `SponsorsManager` | Address of the SponsorsManger contract |
| `builder_`         | `address`         | Address of the builder                 |

### execute

Execute the changes.

_Should be called by the governor, but this contract does not check that explicitly because it is not its responsibility
in the current architecture_

```solidity
function execute() external;
```
