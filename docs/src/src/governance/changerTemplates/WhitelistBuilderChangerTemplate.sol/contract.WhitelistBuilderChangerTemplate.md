# WhitelistBuilderChangerTemplate

[Git Source](https://github.com/rsksmart/collective-rewards-sc/blob/ae40e66d2b99b4caf83133f94d38374097b51ea3/src/governance/changerTemplates/WhitelistBuilderChangerTemplate.sol)

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
