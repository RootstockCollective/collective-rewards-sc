# GaugeBeacon

[Git Source](https://github.com/rsksmart/collective-rewards-sc/blob/ae40e66d2b99b4caf83133f94d38374097b51ea3/src/gauge/GaugeBeacon.sol)

**Inherits:** UpgradeableBeacon

## State Variables

### governanceManager

```solidity
IGovernanceManager public governanceManager;
```

## Functions

### constructor

constructor

```solidity
constructor(
    IGovernanceManager governanceManager_,
    address gaugeImplementation_
)
    UpgradeableBeacon(gaugeImplementation_, governanceManager_.governor());
```

**Parameters**

| Name                   | Type                 | Description                                 |
| ---------------------- | -------------------- | ------------------------------------------- |
| `governanceManager_`   | `IGovernanceManager` | contract with permissioned roles            |
| `gaugeImplementation_` | `address`            | address of the Gauge initial implementation |

### \_checkOwner

The owner is the governor but we need more flexibility to allow changes. So, ownable protected functions can be executed
also by an authorized changer executed by the governor

_Due we cannot override UpgradeableBeacon.sol to remove the OnlyOwner modifier on upgradeTo function we need to override
this function to allow upgrade the beacon by a changer_

```solidity
function _checkOwner() internal view override;
```
