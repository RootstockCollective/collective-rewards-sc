# WhitelistBuilderChangerTemplate

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/9daff6e1b77404f7de5d95940913866696480758/src/governance/changerTemplates/WhitelistBuilderChangerTemplate.sol)

**Inherits:** [IChangeContract](/src/interfaces/IChangeContract.sol/interface.IChangeContract.md)

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
