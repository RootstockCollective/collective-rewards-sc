# WhitelistBuilderChangerTemplate

[Git Source](https://github.com/rsksmart/builder-incentives-sc/blob/fe856b39980e775913dd2a8ffaa77a3ad156e2b5/src/governance/changerTemplates/WhitelistBuilderChangerTemplate.sol)

**Inherits:** [IChangeContract](/src/interfaces/IChangeContract.sol/interface.IChangeContract.md)

ChangeContract used to whitelist a builder and create their BuilderGauge contract

## State Variables

### supportHub

SupportHub contract address

```solidity
SupportHub public immutable supportHub;
```

### builder

builder address to be whitelisted

```solidity
address public immutable builder;
```

### newBuilderGauge

new BuilderGauge created;

```solidity
BuilderGauge public newBuilderGauge;
```

## Functions

### constructor

Constructor

```solidity
constructor(SupportHub supportHub_, address builder_);
```

**Parameters**

| Name          | Type         | Description                            |
| ------------- | ------------ | -------------------------------------- |
| `supportHub_` | `SupportHub` | Address of the SponsorsManger contract |
| `builder_`    | `address`    | Address of the builder                 |

### execute

Execute the changes.

_Should be called by the governor, but this contract does not check that explicitly because it is not its responsibility
in the current architecture_

```solidity
function execute() external;
```
